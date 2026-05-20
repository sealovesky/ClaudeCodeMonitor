import Foundation

enum Constants {
    /// 沙盒下 FileManager.homeDirectoryForCurrentUser 和 NSHomeDirectoryForUser
    /// 都返回 container home。直接拼 /Users/<username>/ 绕开
    private static let realHome: URL = {
        URL(fileURLWithPath: "/Users/\(NSUserName())")
    }()

    static let claudeDir = realHome
        .appendingPathComponent(".claude")

    static let statsCachePath = claudeDir
        .appendingPathComponent("stats-cache.json")

    static let historyPath = claudeDir
        .appendingPathComponent("history.jsonl")

    static let projectsDir = claudeDir
        .appendingPathComponent("projects")

    static let sessionEnvDir = claudeDir
        .appendingPathComponent("session-env")

    // 菜单栏图标颜色阈值
    static let greenThreshold = 500
    static let yellowThreshold = 2000

    // Popover 尺寸
    static let popoverWidth: CGFloat = 380
    static let popoverHeight: CGFloat = 520
}
