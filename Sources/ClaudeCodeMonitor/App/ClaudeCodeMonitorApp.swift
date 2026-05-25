import SwiftUI

@main
struct ClaudeCodeMonitorApp: App {
    @State private var store = MonitorStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// 用户偏好：是否在菜单栏显示图标。关掉后只剩 widget。
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = true

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra(isInserted: menuBarBinding) {
            MenuBarView()
                .environment(store)
        } label: {
            Image(systemName: "brain")
        }
        .menuBarExtraStyle(.window)

        // Settings 用独立 Window，不嵌在 MenuBarExtra(.window) 的 popover 里
        // 原因：popover 在任何 outside event（OS dialog / destructive button / 焦点切换）下都会关闭，
        // 导致 Settings sheet 内的 button action 触发不了。独立 Window 不受影响。
        Window("ClaudeCodeMonitor Settings", id: "ccm-settings") {
            SettingsView()
                .environment(store)
        }
        .windowResizability(.contentSize)
    }

    /// MenuBarExtra 的 isInserted 需要 Binding，把 setting 和 store 的临时强显合并
    private var menuBarBinding: Binding<Bool> {
        Binding(
            get: { showInMenuBar || store.temporaryMenuBarShow },
            set: { showInMenuBar = $0 }
        )
    }
}
