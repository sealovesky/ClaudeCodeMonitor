// App ↔ Widget 共享的快照模型
// App 端 SnapshotHTTPServer encode → Widget 端 SnapshotLoader decode

import Foundation

struct WidgetSnapshot: Codable, Sendable {
    let generatedAt: Date
    let usage: UsageSnapshot?
    let activity: ActivitySnapshot?
    let rateLimited: Bool
}

struct UsageSnapshot: Codable, Sendable {
    /// 5h session 配额百分比 (0..100)
    let fiveHourPct: Double
    let fiveHourResetsAt: Date?
    /// 7d 全模型配额
    let sevenDayPct: Double
    let sevenDayResetsAt: Date?
    /// 7d Sonnet 单独配额
    let sevenDaySonnetPct: Double
    let sevenDaySonnetResetsAt: Date?
}

struct ActivitySnapshot: Codable, Sendable {
    let todayMessages: Int
    let todaySessions: Int
    let activeSessionCount: Int
    let last7Days: [DailyBar]
}

struct DailyBar: Codable, Sendable, Identifiable {
    let date: String      // "M/d"
    let messageCount: Int

    var id: String { date }
}

// MARK: - Loopback 配置

enum SnapshotLoopback {
    /// TeamMonitor 占用 53127，本项目用 53128 避免冲突
    static let port: UInt16 = 53128
    static let url: URL = URL(string: "http://127.0.0.1:53128/")!
}

// MARK: - Common usage thresholds

enum UsageThreshold {
    static let warning: Double = 80
    static let danger: Double = 95
}
