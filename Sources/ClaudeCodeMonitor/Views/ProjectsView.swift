import SwiftUI

struct ProjectsView: View {
    @Environment(MonitorStore.self) private var store

    private var maxMessages: Int {
        store.projectStats.first?.messageCount ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Projects (\(store.projectStats.count))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            if store.projectStats.isEmpty {
                Text("No project data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(store.projectStats) { project in
                    ProjectRow(
                        project: project,
                        maxMessages: maxMessages
                    )
                }
            }
        }
    }
}

struct ProjectRow: View {
    let project: ProjectStats
    let maxMessages: Int

    private var progress: Double {
        guard maxMessages > 0 else { return 0 }
        return Double(project.messageCount) / Double(maxMessages)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
                Text(project.projectName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(TokenFormatter.formatNumber(project.messageCount))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue.gradient)
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 4)

                Text("\(project.sessionCount) sessions")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }
        }
        .padding(.vertical, 4)
    }
}
