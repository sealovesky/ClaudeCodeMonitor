import Foundation

enum Constants {
    static let claudeDir = FileManager.default.homeDirectoryForCurrentUser
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
