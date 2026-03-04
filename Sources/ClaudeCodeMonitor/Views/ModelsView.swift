import SwiftUI
import Charts

struct ModelsView: View {
    @Environment(MonitorStore.self) private var store

    private var modelColors: [String: Color] {
        [
            "Opus": .purple,
            "Sonnet": .blue,
            "Haiku": .cyan,
            "GLM": .green
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Donut Chart
            Text("Model Usage")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            if !store.cachedModelBreakdown.isEmpty {
                Chart(store.cachedModelBreakdown, id: \.name) { model in
                    SectorMark(
                        angle: .value("Tokens", model.tokens),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(modelColors[model.name] ?? .gray)
                    .cornerRadius(4)
                }
                .frame(height: 150)
                .drawingGroup()

                // Legend
                HStack(spacing: 12) {
                    ForEach(store.cachedModelBreakdown, id: \.name) { model in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(modelColors[model.name] ?? .gray)
                                .frame(width: 8, height: 8)
                            Text(model.name)
                                .font(.system(size: 10))
                            Text(TokenFormatter.format(model.tokens))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                // Token Detail Table
                Text("Token Breakdown")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    ForEach(modelUsageList, id: \.name) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(modelColors[item.name] ?? .gray)
                                    .frame(width: 6, height: 6)
                                Text(item.name)
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text(TokenFormatter.format(item.usage.totalTokens))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            HStack(spacing: 8) {
                                tokenLabel("In", item.usage.inputTokens)
                                tokenLabel("Out", item.usage.outputTokens)
                                tokenLabel("Cache", item.usage.cacheReadInputTokens)
                            }
                        }
                        .padding(8)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            } else {
                Text("No model data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }

    private var modelUsageList: [(name: String, usage: ModelUsage)] {
        guard let usage = store.statsCache?.modelUsage else { return [] }
        var merged: [String: ModelUsage] = [:]
        for (key, value) in usage {
            let name = simplifyName(key)
            if let existing = merged[name] {
                merged[name] = ModelUsage(
                    inputTokens: existing.inputTokens + value.inputTokens,
                    outputTokens: existing.outputTokens + value.outputTokens,
                    cacheReadInputTokens: existing.cacheReadInputTokens + value.cacheReadInputTokens,
                    cacheCreationInputTokens: existing.cacheCreationInputTokens + value.cacheCreationInputTokens,
                    webSearchRequests: existing.webSearchRequests + value.webSearchRequests,
                    costUSD: existing.costUSD + value.costUSD,
                    contextWindow: max(existing.contextWindow, value.contextWindow),
                    maxOutputTokens: max(existing.maxOutputTokens, value.maxOutputTokens)
                )
            } else {
                merged[name] = value
            }
        }
        return merged.map { (name: $0.key, usage: $0.value) }
            .sorted { $0.usage.totalTokens > $1.usage.totalTokens }
    }

    private func simplifyName(_ name: String) -> String {
        if name.contains("opus") { return "Opus" }
        if name.contains("sonnet") { return "Sonnet" }
        if name.contains("haiku") { return "Haiku" }
        if name.contains("glm") { return "GLM" }
        return name
    }

    private func tokenLabel(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(TokenFormatter.format(value))
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
