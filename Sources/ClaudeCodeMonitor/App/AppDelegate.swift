// AppDelegate — 处理「双击 .app 而 App 已经在跑」时的恢复路径
//
// 用户在 Settings 关掉菜单栏图标后，唯一的恢复入口就是 Spotlight 搜
// ClaudeCodeMonitor 双击启动。NSApplication 在已运行实例的情况下会触发
// applicationShouldHandleReopen，我们借此发 notification 让 SwiftUI 层
// 临时强制显示菜单栏 + 弹 Settings。

import AppKit

extension Notification.Name {
    /// 请求显示 Settings 并临时强制亮起菜单栏图标
    static let ccmReopenRequested = Notification.Name("CCMReopenRequested")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .ccmReopenRequested, object: nil)
        return true
    }

    /// 关闭最后一个窗口（Settings）时不要退出 App — 我们是 LSUIElement 菜单栏 agent，
    /// HTTP server 还要给 widget 提供数据
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
