import SwiftUI

enum MonitorTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case activity = "Activity"
    case models = "Models"
    case projects = "Projects"

    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .activity: "chart.xyaxis.line"
        case .models: "cpu"
        case .projects: "folder"
        }
    }
}

struct MenuBarView: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTab: MonitorTab = .dashboard

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain")
                    .foregroundStyle(.white)
                Text("Claude Code Monitor")
                    .font(.headline)
                Spacer()
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Tab bar
            HStack(spacing: 2) {
                ForEach(MonitorTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            Text(tab.rawValue)
                                .font(.system(size: 10))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            selectedTab == tab
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .contentShape(Rectangle())
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Content
            ScrollView {
                Group {
                    switch selectedTab {
                    case .dashboard: DashboardView()
                    case .activity: ActivityView()
                    case .models: ModelsView()
                    case .projects: ProjectsView()
                    }
                }
                .padding(12)
            }
            .animation(nil, value: selectedTab)
        }
        .frame(width: Constants.popoverWidth, height: Constants.popoverHeight)
        .onAppear {
            store.loadAll()
        }
    }

    private func openSettings() {
        // LSUIElement App 在 .accessory 模式下 NSApp.activate 不生效。
        // 之前尝试临时切 .regular，但 policy 切换会重置 NSApp 内部 state，
        // 让 MenuBarExtra 的 isInserted binding 失灵（hide 操作不生效）。
        // 改用 NSWindow.level = .floating —— 不动 activation policy，只让窗口浮顶。
        openWindow(id: "ccm-settings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            for win in NSApp.windows where win.title.contains("ClaudeCodeMonitor Settings") {
                win.level = .floating
                win.makeKeyAndOrderFront(nil)
                win.orderFrontRegardless()
            }
        }
    }
}
