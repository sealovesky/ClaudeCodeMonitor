import Foundation
import SwiftUI

@Observable
@MainActor
final class MonitorStore {
    // MARK: - Published State
    var statsCache: StatsCache?
    var projectStats: [ProjectStats] = []
    var activeSessionCount: Int = 0
    var totalUniqueSessionCount: Int = 0
    var totalUniqueDayCount: Int = 0
    var usageData: UsageData?
    var usageLoading: Bool = false

    // MARK: - Cached computed data (updated only on data reload)
    var latestActivity: DailyActivity?
    var latestActivityLabel: String = "Today"
    var cachedLast7Days: [DailyActivity] = []
    var cachedLast30Days: [DailyActivity] = []
    var cachedHourlyDistribution: [(hour: Int, count: Int)] = []
    var cachedModelBreakdown: [(name: String, tokens: Int)] = []

    // MARK: - Settings
    var greenThreshold: Int = Constants.greenThreshold
    var yellowThreshold: Int = Constants.yellowThreshold

    // MARK: - Private
    private let fileMonitor = FileMonitor()
    private var debounceTask: Task<Void, Never>?

    // MARK: - Computed (cheap)

    var todayMessages: Int { latestActivity?.messageCount ?? 0 }

    var menuBarColor: Color {
        let msgs = todayMessages
        if msgs < greenThreshold { return .green }
        if msgs < yellowThreshold { return .yellow }
        return .red
    }

    var totalDays: Int { totalUniqueDayCount }

    // MARK: - Actions

    func loadAll() {
        loadStats()
        loadProjects()
        countActiveSessions()
        loadUsage()
        startFileMonitoring()
    }

    func loadUsage() {
        usageLoading = true
        Task {
            let data = await UsageAPI.fetch()
            self.usageData = data
            self.usageLoading = false
        }
    }

    func loadStats() {
        statsCache = StatsParser.parse()
        rebuildCachedData()
    }

    func loadProjects() {
        Task {
            let summary = await Task.detached {
                let entries = HistoryParser.parse()
                return HistoryParser.aggregate(from: entries)
            }.value
            self.projectStats = summary.projects
            self.totalUniqueSessionCount = summary.uniqueSessionCount
            self.totalUniqueDayCount = summary.uniqueDayCount
        }
    }

    func countActiveSessions() {
        let dir = Constants.sessionEnvDir
        let fm = FileManager.default
        let count = (try? fm.contentsOfDirectory(atPath: dir.path))?.count ?? 0
        activeSessionCount = count
    }

    // MARK: - Cache Rebuild

    private func rebuildCachedData() {
        let todayStr = DateFormatters.dateOnly.string(from: Date())
        if let todayData = statsCache?.dailyActivity.first(where: { $0.date == todayStr }) {
            latestActivity = todayData
            latestActivityLabel = "Today"
        } else if let last = statsCache?.dailyActivity.last {
            latestActivity = last
            latestActivityLabel = last.shortDate
        } else {
            latestActivity = nil
            latestActivityLabel = "Today"
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        // Last 7 days
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: todayStart),
           let activities = statsCache?.dailyActivity {
            cachedLast7Days = activities.filter { activity in
                guard let date = activity.parsedDate else { return false }
                let day = calendar.startOfDay(for: date)
                return day >= weekAgo && day <= todayStart
            }
        } else {
            cachedLast7Days = []
        }

        // Last 30 days
        if let monthAgo = calendar.date(byAdding: .day, value: -29, to: todayStart),
           let activities = statsCache?.dailyActivity {
            cachedLast30Days = activities.filter { activity in
                guard let date = activity.parsedDate else { return false }
                let day = calendar.startOfDay(for: date)
                return day >= monthAgo && day <= todayStart
            }
        } else {
            cachedLast30Days = []
        }

        // Hourly distribution
        if let hourCounts = statsCache?.hourCounts {
            cachedHourlyDistribution = (0..<24).map { hour in
                (hour: hour, count: hourCounts[String(hour)] ?? 0)
            }
        } else {
            cachedHourlyDistribution = []
        }

        // Model breakdown (合并同名模型)
        if let usage = statsCache?.modelUsage {
            var merged: [String: Int] = [:]
            for (key, value) in usage {
                let name = simplifyModelName(key)
                merged[name, default: 0] += value.totalTokens
            }
            cachedModelBreakdown = merged
                .map { (name: $0.key, tokens: $0.value) }
                .sorted { $0.tokens > $1.tokens }
        } else {
            cachedModelBreakdown = []
        }
    }

    // MARK: - File Monitoring

    private func startFileMonitoring() {
        fileMonitor.startMonitoring(
            paths: [Constants.statsCachePath, Constants.historyPath]
        ) { [weak self] in
            Task { @MainActor [weak self] in
                self?.debouncedReload()
            }
        }
    }

    private func debouncedReload() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.loadStats()
            self?.loadProjects()
            self?.countActiveSessions()
        }
    }

    // MARK: - Helpers

    private func simplifyModelName(_ name: String) -> String {
        if name.contains("opus") { return "Opus" }
        if name.contains("sonnet") { return "Sonnet" }
        if name.contains("haiku") { return "Haiku" }
        if name.contains("glm") { return "GLM" }
        return name
    }
}
