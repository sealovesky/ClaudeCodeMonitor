import Foundation

struct StatsCache: Codable, Sendable {
    let version: Int
    let lastComputedDate: String
    let dailyActivity: [DailyActivity]
    let dailyModelTokens: [DailyModelTokens]
    let modelUsage: [String: ModelUsage]
    let totalSessions: Int
    let totalMessages: Int
    let longestSession: LongestSession?
    let firstSessionDate: String?
    let hourCounts: [String: Int]
    let totalSpeculationTimeSavedMs: Int?
}

struct DailyActivity: Codable, Sendable, Identifiable {
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int

    var id: String { date }

    var parsedDate: Date? {
        DateFormatters.dateOnly.date(from: date)
    }
}

struct DailyModelTokens: Codable, Sendable {
    let date: String
    let tokensByModel: [String: Int]
}

struct ModelUsage: Codable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadInputTokens: Int
    let cacheCreationInputTokens: Int
    let webSearchRequests: Int
    let costUSD: Double
    let contextWindow: Int
    let maxOutputTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheReadInputTokens + cacheCreationInputTokens
    }
}

struct LongestSession: Codable, Sendable {
    let sessionId: String
    let duration: Int
    let messageCount: Int
    let timestamp: String
}

// MARK: - Cached DateFormatters
enum DateFormatters {
    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()
}
