// Widget 实现 — Apple Activity Ring 风格双环 + 暗色渐变
// 视觉灵感来自 ~/Project/ClaudeTeamMonitor 的 ClaudeTeamMonitorWidget

import SwiftUI
import WidgetKit
import Charts

@main
struct ClaudeCodeMonitorWidget: Widget {
    let kind: String = "ClaudeCodeMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.09, green: 0.10, blue: 0.14),
                                 Color(red: 0.04, green: 0.05, blue: 0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Claude Code Monitor")
        .description("Your Claude Code usage at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: SnapshotLoader.loadLatest()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now
        let entry = SnapshotEntry(date: now, snapshot: SnapshotLoader.loadLatest())
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - 色调 / 阈值

enum Tone {
    case ok, warn, danger
    static func from(_ pct: Double) -> Tone {
        if pct >= UsageThreshold.danger { return .danger }
        if pct >= UsageThreshold.warning { return .warn }
        return .ok
    }
    var gradient: LinearGradient {
        switch self {
        case .ok:
            return LinearGradient(colors: [Color(red: 0.36, green: 0.82, blue: 0.98),
                                           Color(red: 0.32, green: 0.55, blue: 0.95)],
                                  startPoint: .leading, endPoint: .trailing)
        case .warn:
            return LinearGradient(colors: [Color(red: 1.00, green: 0.78, blue: 0.36),
                                           Color(red: 1.00, green: 0.55, blue: 0.20)],
                                  startPoint: .leading, endPoint: .trailing)
        case .danger:
            return LinearGradient(colors: [Color(red: 1.00, green: 0.45, blue: 0.45),
                                           Color(red: 0.95, green: 0.20, blue: 0.40)],
                                  startPoint: .leading, endPoint: .trailing)
        }
    }
    var solid: Color {
        switch self {
        case .ok: return Color(red: 0.36, green: 0.65, blue: 0.97)
        case .warn: return Color(red: 1.00, green: 0.66, blue: 0.28)
        case .danger: return Color(red: 0.97, green: 0.32, blue: 0.42)
        }
    }
}

/// 7d 固定粉色，跟 5h 的阈值色区分（参考 Apple Health Move 环固定色）
private let sevenDayGradient = LinearGradient(
    colors: [Color(red: 1.00, green: 0.40, blue: 0.65),
             Color(red: 0.86, green: 0.25, blue: 0.78)],
    startPoint: .leading, endPoint: .trailing
)
private let sevenDaySolid = Color(red: 1.00, green: 0.45, blue: 0.70)

// MARK: - Reset time formatter

enum ResetTimeFormatter {
    /// "in 2h 15m" / "in 45m" / "in 6d 3h" / "soon" / "—"
    static func short(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let interval = date.timeIntervalSinceNow
        if interval < 60 { return "soon" }
        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return "in \(days)d \(hours)h" }
        if hours > 0 { return "in \(hours)h \(minutes)m" }
        return "in \(minutes)m"
    }
}

// MARK: - Reusable bits

struct StatusDot: View {
    let tone: Tone
    var body: some View {
        Circle().fill(tone.solid).frame(width: 6, height: 6)
            .shadow(color: tone.solid.opacity(0.6), radius: 3)
    }
}

/// 胶囊渐变进度条
struct CapsuleGauge: View {
    let value: Double   // 0..1
    let tone: Tone
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(tone.gradient)
                    .frame(width: max(2, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// 双环 — Apple Activity Ring 风格，外 5h 内 7d
struct BigRingGauge: View {
    let fiveHour: Double    // 0..100
    let sevenDay: Double    // 0..100
    var size: CGFloat = 96
    var outerLine: CGFloat = 8
    var innerLine: CGFloat = 6
    var gap: CGFloat = 4

    var body: some View {
        let tone5 = Tone.from(fiveHour)
        let innerSize = size - (outerLine * 2) - gap * 2
        // 中心字号随 size 缩放（96 时 26pt，80 时 22pt）
        let bigDigit = size * 0.27
        let pctSign = size * 0.125
        let label = size * 0.095
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: outerLine)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fiveHour / 100)))
                .stroke(tone5.gradient,
                        style: StrokeStyle(lineWidth: outerLine, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: innerLine)
                .frame(width: innerSize, height: innerSize)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, sevenDay / 100)))
                .stroke(sevenDayGradient,
                        style: StrokeStyle(lineWidth: innerLine, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: innerSize, height: innerSize)

            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int(fiveHour))")
                        .font(.system(size: bigDigit, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                    Text("%")
                        .font(.system(size: pctSign, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                Text("5h")
                    .font(.system(size: label, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
    }
}

struct WidgetHeader: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        let tone5 = Tone.from(snapshot.usage?.fiveHourPct ?? 0)
        HStack(spacing: 6) {
            StatusDot(tone: tone5)
            Text("CLAUDE CODE")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.55))
            if snapshot.rateLimited {
                Text("· rate-limited")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundColor(.orange.opacity(0.8))
            }
            Spacer()
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
            Text(snapshot.generatedAt.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.45))
        }
    }
}

// MARK: - Entry dispatch

struct WidgetEntryView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(snapshot: entry.snapshot)
        case .systemMedium: MediumWidgetView(snapshot: entry.snapshot)
        case .systemLarge:  LargeWidgetView(snapshot: entry.snapshot)
        default:            MediumWidgetView(snapshot: entry.snapshot)
        }
    }
}

struct EmptyState: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.title2).foregroundColor(.white.opacity(0.3))
            Text("App not running?")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Small

struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        if let snap = snapshot, let usage = snap.usage {
            let tone5 = Tone.from(usage.fiveHourPct)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    StatusDot(tone: tone5)
                    Text("CLAUDE CODE")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                }
                Spacer(minLength: 0)
                BigRingGauge(fiveHour: usage.fiveHourPct, sevenDay: usage.sevenDayPct)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                HStack {
                    legendDot(color: tone5.solid, label: "5h", value: Int(usage.fiveHourPct))
                    Spacer()
                    legendDot(color: sevenDaySolid, label: "7d", value: Int(usage.sevenDayPct))
                }
            }
        } else {
            EmptyState()
        }
    }

    @ViewBuilder
    private func legendDot(color: Color, label: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
            Text("\(value)%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
        }
    }
}

// MARK: - Medium
//
// 左：双环视觉焦点 / 右：三档配额 + reset 时间表 / 底：今日活动一行小字
// 减少信息密度，用空间分组让眼睛知道往哪看

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        if let snap = snapshot {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(snapshot: snap)
                HStack(alignment: .center, spacing: 0) {
                    if let u = snap.usage {
                        BigRingGauge(fiveHour: u.fiveHourPct, sevenDay: u.sevenDayPct,
                                     size: 76, outerLine: 7, innerLine: 5)
                        Spacer()
                        quotaList(usage: u)
                            .frame(width: 175, alignment: .leading)
                    }
                }
                .frame(maxHeight: .infinity)
                if let a = snap.activity {
                    activityFooter(activity: a)
                }
            }
        } else {
            EmptyState()
        }
    }

    @ViewBuilder
    private func quotaList(usage: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            quotaLine(label: "5h", pct: usage.fiveHourPct,
                      color: Tone.from(usage.fiveHourPct).solid,
                      reset: usage.fiveHourResetsAt)
            quotaLine(label: "7d", pct: usage.sevenDayPct,
                      color: sevenDaySolid,
                      reset: usage.sevenDayResetsAt)
            quotaLine(label: "Sonnet", pct: usage.sevenDaySonnetPct,
                      color: Tone.from(usage.sevenDaySonnetPct).solid,
                      reset: usage.sevenDaySonnetResetsAt)
        }
    }

    @ViewBuilder
    private func quotaLine(label: String, pct: Double, color: Color, reset: Date?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 50, alignment: .leading)
                .lineLimit(1)
            Text("\(Int(pct))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
                .frame(width: 38, alignment: .trailing)
            Text(ResetTimeFormatter.short(reset))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.4))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func activityFooter(activity: ActivitySnapshot) -> some View {
        HStack(spacing: 6) {
            footerItem(icon: "message.fill", value: activity.todayMessages, label: "msg")
            divider
            footerItem(icon: "rectangle.stack.fill", value: activity.todaySessions, label: "sess")
            divider
            footerItem(icon: "bolt.fill", value: activity.activeSessionCount, label: "active")
            Spacer()
        }
    }

    @ViewBuilder
    private func footerItem(icon: String, value: Int, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.4))
            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.85))
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var divider: some View {
        Text("·").foregroundColor(.white.opacity(0.25))
    }
}

/// 用任意 LinearGradient 的胶囊条（CapsuleGauge 只接 Tone）
struct GaugeBar: View {
    let value: Double
    let gradient: LinearGradient
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(gradient)
                    .frame(width: max(2, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Large
//
// 顶：双环 + 三档配额详情（带 reset）/ 中：7 日柱状图 / 底：三项 summary
// 视觉密度比 Medium 高，但仍按上中下分组

struct LargeWidgetView: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        if let snap = snapshot {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(snapshot: snap)
                if let u = snap.usage {
                    topSection(usage: u)
                }
                Spacer(minLength: 0)
                if let a = snap.activity, !a.last7Days.isEmpty {
                    chartSection(activity: a)
                }
                Spacer(minLength: 0)
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                if let a = snap.activity {
                    summaryRow(activity: a)
                }
            }
        } else {
            EmptyState()
        }
    }

    @ViewBuilder
    private func topSection(usage: UsageSnapshot) -> some View {
        HStack(alignment: .center, spacing: 16) {
            BigRingGauge(fiveHour: usage.fiveHourPct, sevenDay: usage.sevenDayPct)
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 6) {
                quotaRow(label: "5h", pct: usage.fiveHourPct,
                         color: Tone.from(usage.fiveHourPct).solid,
                         reset: usage.fiveHourResetsAt)
                quotaRow(label: "7d", pct: usage.sevenDayPct,
                         color: sevenDaySolid,
                         reset: usage.sevenDayResetsAt)
                quotaRow(label: "Sonnet", pct: usage.sevenDaySonnetPct,
                         color: Tone.from(usage.sevenDaySonnetPct).solid,
                         reset: usage.sevenDaySonnetResetsAt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func quotaRow(label: String, pct: Double, color: Color, reset: Date?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 44, alignment: .leading)
            Text("\(Int(pct))%")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
                .frame(width: 44, alignment: .trailing)
            Text(ResetTimeFormatter.short(reset))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.45))
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func chartSection(activity: ActivitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("LAST 7 DAYS")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(.white.opacity(0.45))
                Spacer()
                Text("\(activity.last7Days.reduce(0) { $0 + $1.messageCount }) msg total")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.45))
            }
            Chart(activity.last7Days) { day in
                BarMark(
                    x: .value("Date", day.date),
                    y: .value("Messages", day.messageCount)
                )
                .foregroundStyle(LinearGradient(colors: [Tone.ok.solid, Tone.ok.solid.opacity(0.6)],
                                                startPoint: .top, endPoint: .bottom))
                .cornerRadius(2)
                .annotation(position: .top, spacing: 1) {
                    Text("\(day.messageCount)")
                        .font(.system(size: 7, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let str = value.as(String.self) {
                            Text(str)
                                .font(.system(size: 8, design: .rounded))
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 70)
        }
    }

    @ViewBuilder
    private func summaryRow(activity: ActivitySnapshot) -> some View {
        HStack(spacing: 8) {
            summaryItem(value: "\(activity.todayMessages)", label: "TODAY MSG", color: Tone.ok.solid)
            summaryItem(value: "\(activity.todaySessions)", label: "SESSIONS", color: .white.opacity(0.9))
            summaryItem(value: "\(activity.activeSessionCount)", label: "ACTIVE", color: sevenDaySolid)
        }
    }

    @ViewBuilder
    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .tracking(0.5)
                .foregroundColor(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
