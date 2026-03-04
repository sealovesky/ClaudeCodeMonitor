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
    @State private var selectedTab: MonitorTab = .dashboard
    @State private var showSettings = false

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
                    showSettings.toggle()
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(store)
        }
    }
}
