import SwiftUI
import Charts

struct ActivityView: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 30-Day Line Chart
            Text("Last 30 Days")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Chart(store.cachedLast30Days) { day in
                AreaMark(
                    x: .value("Date", day.parsedDate ?? Date()),
                    y: .value("Messages", day.messageCount)
                )
                .foregroundStyle(.blue.opacity(0.1))

                LineMark(
                    x: .value("Date", day.parsedDate ?? Date()),
                    y: .value("Messages", day.messageCount)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
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
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 9))
                        }
                    }
                }
            }
            .frame(height: 160)
            .drawingGroup()

            // 24-Hour Heatmap
            Text("Hourly Distribution")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            HeatmapGrid(hourData: store.cachedHourlyDistribution)
        }
    }
}

struct HeatmapGrid: View {
    let hourData: [(hour: Int, count: Int)]

    private let columns = 6
    private let rows = 4

    private var maxCount: Int {
        hourData.map(\.count).max() ?? 1
    }

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<columns, id: \.self) { col in
                        let hour = row * columns + col
                        let count = hourData.first { $0.hour == hour }?.count ?? 0
                        let intensity = maxCount > 0 ? Double(count) / Double(maxCount) : 0

                        VStack(spacing: 1) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(heatColor(intensity))
                                .frame(height: 24)
                                .overlay {
                                    Text("\(count)")
                                        .font(.system(size: 8))
                                        .foregroundStyle(intensity > 0.5 ? .white : .secondary)
                                }
                            Text("\(hour):00")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private func heatColor(_ intensity: Double) -> Color {
        if intensity == 0 { return Color.gray.opacity(0.15) }
        return Color.blue.opacity(0.2 + intensity * 0.8)
    }
}
