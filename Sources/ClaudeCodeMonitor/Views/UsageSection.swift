import SwiftUI

struct UsageSection: View {
    let usage: UsageData?
    let loading: Bool
    let rateLimited: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Usage")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                if rateLimited {
                    Text("Rate limited, retrying later")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
                Spacer()
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(loading ? 360 : 0))
                        .animation(loading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: loading)
                }
                .buttonStyle(.plain)
                .disabled(loading)
            }

            if loading && usage == nil {
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let usage {
                VStack(spacing: 6) {
                    if let session = usage.session {
                        UsageBar(
                            title: "Session",
                            percent: session.percentUsed,
                            resets: session.resetsAtFormatted,
                            color: barColor(session.percentUsed)
                        )
                    }
                    if let week = usage.weekAll {
                        UsageBar(
                            title: "Weekly",
                            percent: week.percentUsed,
                            resets: week.resetsAtFormatted,
                            color: barColor(week.percentUsed)
                        )
                    }
                    if let sonnet = usage.weekSonnet {
                        UsageBar(
                            title: "Sonnet",
                            percent: sonnet.percentUsed,
                            resets: sonnet.resetsAtFormatted,
                            color: barColor(sonnet.percentUsed)
                        )
                    }
                }
            } else {
                Text("Unable to load usage data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func barColor(_ percent: Int) -> Color {
        if percent < 50 { return .green }
        if percent < 80 { return .yellow }
        return .red
    }
}

struct UsageBar: View {
    let title: String
    let percent: Int
    let resets: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * min(CGFloat(percent) / 100.0, 1.0))
                }
            }
            .frame(height: 6)

            Text("Resets \(resets)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }
}
