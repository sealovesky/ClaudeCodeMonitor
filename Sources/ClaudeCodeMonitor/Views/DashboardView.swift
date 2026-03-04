import SwiftUI
import Charts

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct DashboardView: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Usage Quota
            UsageSection(usage: store.usageData, loading: store.usageLoading) {
                store.loadUsage()
            }

            Divider()

            // 2x2 Card Grid
            Text(store.latestActivityLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                StatCard(
                    title: "Messages",
                    value: TokenFormatter.formatNumber(store.latestActivity?.messageCount ?? 0),
                    icon: "message",
                    color: .blue
                )
                StatCard(
                    title: "Sessions",
                    value: "\(store.latestActivity?.sessionCount ?? 0)",
                    icon: "rectangle.stack",
                    color: .green
                )
                StatCard(
                    title: "Tool Calls",
                    value: TokenFormatter.formatNumber(store.latestActivity?.toolCallCount ?? 0),
                    icon: "wrench.and.screwdriver",
                    color: .orange
                )
                StatCard(
                    title: "Active",
                    value: "\(store.activeSessionCount)",
                    icon: "bolt.circle",
                    color: .purple
                )
            }

            // 7-Day Bar Chart
            Text("Last 7 Days")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Chart(store.cachedLast7Days) { day in
                BarMark(
                    x: .value("Date", day.shortDate),
                    y: .value("Messages", day.messageCount)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(TokenFormatter.format(intValue))
                                .font(.system(size: 9))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let str = value.as(String.self) {
                            Text(str)
                                .font(.system(size: 9))
                        }
                    }
                }
            }
            .frame(height: 120)
            .drawingGroup()

            // Cumulative Stats
            Divider()
            HStack {
                cumulativeStat("Sessions", "\(store.totalUniqueSessionCount)")
                Spacer()
                cumulativeStat("Messages", TokenFormatter.formatNumber(store.statsCache?.totalMessages ?? 0))
                Spacer()
                cumulativeStat("Days", "\(store.totalDays)")
            }
            .padding(.vertical, 4)
        }
    }

    private func cumulativeStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

extension DailyActivity {
    var shortDate: String {
        guard let date = parsedDate else { return self.date }
        return DateFormatters.shortDate.string(from: date)
    }
}
