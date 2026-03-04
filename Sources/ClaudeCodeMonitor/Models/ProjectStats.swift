import Foundation

struct ProjectStats: Identifiable, Sendable {
    let projectPath: String
    let projectName: String
    var messageCount: Int
    var sessionIds: Set<String>

    var id: String { projectPath }
    var sessionCount: Int { sessionIds.count }
}
