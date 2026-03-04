import Foundation

struct HistoryEntry: Codable, Sendable {
    let display: String
    let pastedContents: [String: String]?
    let timestamp: Double
    let project: String?
    let sessionId: String?

    var date: Date {
        Date(timeIntervalSince1970: timestamp / 1000.0)
    }

    var projectName: String {
        guard let project else { return "Unknown" }
        return (project as NSString).lastPathComponent
    }
}
