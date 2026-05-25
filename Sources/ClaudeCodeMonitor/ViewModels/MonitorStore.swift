import Foundation
import SwiftUI
import WidgetKit
import Combine

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
    var usageRateLimited: Bool = false
    var statsLoading: Bool = false

    // MARK: - Widget loopback
    private let httpServer = SnapshotHTTPServer()
    private var refreshTimer: Timer?
    /// 后台刷新频率 30 分钟 — 同时刷 OAuth 配额 + SessionParser 活动统计
    /// 隐藏 menubar icon 后这是 widget 数据更新的唯一来源（没有菜单栏 onAppear 兜底）
    private let refreshInterval: TimeInterval = 30 * 60
    /// 节流：60 秒内 loadUsage 只真实调一次 API
    /// 防止频繁开关菜单栏打爆 OAuth rate limit（429）
    private let usageMinInterval: TimeInterval = 60
    private var lastUsageFetchAt: Date?

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

    /// 菜单栏图标临时强显（reopen 后 60 秒，让用户能再次看到 icon 进 Settings）
    var temporaryMenuBarShow: Bool = false

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Private

    // MARK: - Computed (cheap)

    var todayMessages: Int { latestActivity?.messageCount ?? 0 }

    var menuBarColor: Color {
        let msgs = todayMessages
        if msgs < greenThreshold { return .green }
        if msgs < yellowThreshold { return .yellow }
        return .red
    }

    var totalDays: Int { totalUniqueDayCount }

    // MARK: - Init / Bootstrap

    init() {
        // App 启动即起 HTTP server + 首次加载数据 + 定时刷 OAuth 配额
        // 不依赖菜单栏打开（widget 必须能在 App 启动后立刻拿到数据）
        httpServer.start()
        loadAll()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.loadAll() }
        }
        // 监听双击 .app 触发的 reopen — 临时强显菜单栏 60 秒，让用户能找回 Settings
        NotificationCenter.default.publisher(for: .ccmReopenRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleReopen()
            }
            .store(in: &cancellables)
    }

    private func handleReopen() {
        // reopen 只强显 icon 60 秒，不自动弹 Settings
        // user 看到 icon 自己决定点开看 dashboard 还是齿轮进 Settings
        temporaryMenuBarShow = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.temporaryMenuBarShow = false
        }
    }

    // MARK: - Actions

    func loadAll() {
        loadStats()
        loadProjects()
        countActiveSessions()
        loadUsage()
    }

    func loadUsage() {
        // 节流：60 秒内不重复调（首次调用 lastUsageFetchAt 为 nil，放行）
        if let last = lastUsageFetchAt,
           Date().timeIntervalSince(last) < usageMinInterval {
            return
        }
        lastUsageFetchAt = Date()
        usageLoading = true
        usageRateLimited = false
        Task {
            let result = await UsageAPI.fetch()
            switch result {
            case .success(let data):
                self.usageData = data
                self.usageRateLimited = false
            case .rateLimited:
                self.usageRateLimited = true
                // 保留旧数据不清空
            case .failure:
                if self.usageData == nil {
                    self.usageRateLimited = false
                }
                // 有旧数据则保留，无旧数据则保持 nil
            }
            self.usageLoading = false
            self.publishToWidget()
        }
    }

    func loadStats() {
        statsLoading = true
        Task {
            let cache = await Task.detached { SessionParser.parse() }.value
            self.statsCache = cache
            self.rebuildCachedData()
            self.statsLoading = false
            self.publishToWidget()
        }
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

    // MARK: - Helpers

    private func simplifyModelName(_ name: String) -> String {
        if name.contains("opus") { return "Opus" }
        if name.contains("sonnet") { return "Sonnet" }
        if name.contains("haiku") { return "Haiku" }
        if name.contains("glm") { return "GLM" }
        return name
    }

    // MARK: - Widget loopback publish

    /// 把当前状态打包成 WidgetSnapshot 推给 HTTP server，并通知 WidgetKit 刷 timeline
    private func publishToWidget() {
        let snapshot = buildWidgetSnapshot()
        httpServer.update(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func buildWidgetSnapshot() -> WidgetSnapshot {
        let usage = usageData.map { data in
            UsageSnapshot(
                fiveHourPct: data.session?.utilization ?? 0,
                fiveHourResetsAt: data.session.flatMap { Self.parseISO($0.resetsAt) },
                sevenDayPct: data.weekAll?.utilization ?? 0,
                sevenDayResetsAt: data.weekAll.flatMap { Self.parseISO($0.resetsAt) },
                sevenDaySonnetPct: data.weekSonnet?.utilization ?? 0,
                sevenDaySonnetResetsAt: data.weekSonnet.flatMap { Self.parseISO($0.resetsAt) }
            )
        }
        let last7 = cachedLast7Days.map { DailyBar(date: $0.shortDate, messageCount: $0.messageCount) }
        let activity = ActivitySnapshot(
            todayMessages: latestActivity?.messageCount ?? 0,
            todaySessions: latestActivity?.sessionCount ?? 0,
            activeSessionCount: activeSessionCount,
            last7Days: last7
        )
        return WidgetSnapshot(
            generatedAt: Date(),
            usage: usage,
            activity: activity,
            rateLimited: usageRateLimited
        )
    }

    private static func parseISO(_ s: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }
}
