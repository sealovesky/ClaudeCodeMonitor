import SwiftUI

@main
struct ClaudeCodeMonitorApp: App {
    @State private var store = MonitorStore()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(store)
        } label: {
            Image(systemName: "brain")
        }
        .menuBarExtraStyle(.window)
    }
}
