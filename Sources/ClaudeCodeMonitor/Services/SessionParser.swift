import Foundation

enum SessionParser {
    /// 扫描所有 session JSONL 文件，生成 StatsCache
    /// 应在后台线程调用
    static func parse() -> StatsCache {
        let fm = FileManager.default
        let projectsPath = Constants.projectsDir.path

        // 收集所有 JSONL 文件（跳过 subagents 子目录）
        let jsonlFiles = collectJSONLFiles(at: projectsPath, fileManager: fm)

        // 聚合累加器
        var dayMap: [String: DayAccumulator] = [:]
        var modelTokens: [String: TokenAccumulator] = [:]
        var hourCounts: [Int: Int] = [:]
        var totalMessages = 0
        var sessionIds: Set<String> = []
        var firstDate: String?

        // 按 requestId 去重 assistant（只保留 stop_reason != null 的最终条目）
        // 由于逐文件处理，每个文件内部去重即可
        for fileURL in jsonlFiles {
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            guard let content = String(data: data, encoding: .utf8) else { continue }

            // 暂存：requestId -> 最终 assistant 行（有 stop_reason 的）
            var finalAssistants: [String: AssistantEntry] = [:]
            var userLines: [UserEntry] = []

            content.enumerateLines { line, _ in
                // 快速预过滤
                guard line.contains("\"user\"") || line.contains("\"assistant\"") else { return }
                guard line.contains("\"message\"") else { return }

                // 跳过 sidechain
                if line.contains("\"isSidechain\":true") { return }

                guard let lineData = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
                else { return }

                guard let type = json["type"] as? String else { return }
                guard let timestamp = json["timestamp"] as? String else { return }
                guard let sessionId = json["sessionId"] as? String else { return }

                let (dateStr, hour) = extractLocalDateAndHour(from: timestamp)

                if type == "user" {
                    // 跳过 tool_result（工具返回结果，content 是数组且首元素 type=tool_result）
                    if let message = json["message"] as? [String: Any],
                       let content = message["content"] as? [[String: Any]],
                       content.first?["type"] as? String == "tool_result" {
                        return
                    }
                    userLines.append(UserEntry(
                        sessionId: sessionId,
                        date: dateStr,
                        hour: hour
                    ))
                } else if type == "assistant" {
                    guard let message = json["message"] as? [String: Any] else { return }
                    guard let requestId = json["requestId"] as? String else { return }

                    let model = message["model"] as? String ?? "unknown"
                    let stopReason = message["stop_reason"] as? String
                    let usage = message["usage"] as? [String: Any]

                    let inputTokens = usage?["input_tokens"] as? Int ?? 0
                    let outputTokens = usage?["output_tokens"] as? Int ?? 0
                    let cacheRead = usage?["cache_read_input_tokens"] as? Int ?? 0
                    let cacheCreation = usage?["cache_creation_input_tokens"] as? Int ?? 0

                    // 统计 tool_use
                    var toolCallCount = 0
                    if let content = message["content"] as? [[String: Any]] {
                        for block in content {
                            if block["type"] as? String == "tool_use" {
                                toolCallCount += 1
                            }
                        }
                    }

                    let entry = AssistantEntry(
                        requestId: requestId,
                        sessionId: sessionId,
                        date: dateStr,
                        hour: hour,
                        model: model,
                        stopReason: stopReason,
                        inputTokens: inputTokens,
                        outputTokens: outputTokens,
                        cacheRead: cacheRead,
                        cacheCreation: cacheCreation,
                        toolCallCount: toolCallCount
                    )

                    // 只保留有 stop_reason 的最终条目，或首次出现的条目
                    if stopReason != nil {
                        finalAssistants[requestId] = entry
                    } else if finalAssistants[requestId] == nil {
                        finalAssistants[requestId] = entry
                    }
                }
            }

            // 处理 user 条目
            for user in userLines {
                totalMessages += 1
                sessionIds.insert(user.sessionId)
                dayMap[user.date, default: DayAccumulator()].messageCount += 1
                dayMap[user.date, default: DayAccumulator()].sessionIds.insert(user.sessionId)
                hourCounts[user.hour, default: 0] += 1

                if firstDate == nil || user.date < (firstDate ?? "") {
                    firstDate = user.date
                }
            }

            // 处理去重后的 assistant 条目
            for (_, entry) in finalAssistants {
                sessionIds.insert(entry.sessionId)
                dayMap[entry.date, default: DayAccumulator()].toolCallCount += entry.toolCallCount
                dayMap[entry.date, default: DayAccumulator()].sessionIds.insert(entry.sessionId)

                // 模型 token 累加
                modelTokens[entry.model, default: TokenAccumulator()].inputTokens += entry.inputTokens
                modelTokens[entry.model, default: TokenAccumulator()].outputTokens += entry.outputTokens
                modelTokens[entry.model, default: TokenAccumulator()].cacheRead += entry.cacheRead
                modelTokens[entry.model, default: TokenAccumulator()].cacheCreation += entry.cacheCreation

                if firstDate == nil || entry.date < (firstDate ?? "") {
                    firstDate = entry.date
                }
            }
        }

        // 构造 StatsCache
        let dailyActivity = dayMap.keys.sorted().map { date -> DailyActivity in
            let acc = dayMap[date]!
            return DailyActivity(
                date: date,
                messageCount: acc.messageCount,
                sessionCount: acc.sessionIds.count,
                toolCallCount: acc.toolCallCount
            )
        }

        let modelUsage = modelTokens.reduce(into: [String: ModelUsage]()) { result, kv in
            result[kv.key] = ModelUsage(
                inputTokens: kv.value.inputTokens,
                outputTokens: kv.value.outputTokens,
                cacheReadInputTokens: kv.value.cacheRead,
                cacheCreationInputTokens: kv.value.cacheCreation,
                webSearchRequests: 0,
                costUSD: 0,
                contextWindow: 0,
                maxOutputTokens: 0
            )
        }

        let hourCountsDict = hourCounts.reduce(into: [String: Int]()) { result, kv in
            result[String(kv.key)] = kv.value
        }

        return StatsCache(
            version: 1,
            lastComputedDate: DateFormatters.dateOnly.string(from: Date()),
            dailyActivity: dailyActivity,
            dailyModelTokens: [],
            modelUsage: modelUsage,
            totalSessions: sessionIds.count,
            totalMessages: totalMessages,
            longestSession: nil,
            firstSessionDate: firstDate,
            hourCounts: hourCountsDict,
            totalSpeculationTimeSavedMs: nil
        )
    }

    // MARK: - Private

    /// 递归收集 JSONL 文件，跳过 subagents 子目录
    private static func collectJSONLFiles(at path: String, fileManager fm: FileManager) -> [URL] {
        var result: [URL] = []
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return result }

        for case let fileURL as URL in enumerator {
            // 跳过 subagents 目录
            if fileURL.path.contains("/subagents/") {
                continue
            }
            if fileURL.pathExtension == "jsonl" {
                result.append(fileURL)
            }
        }
        return result
    }

    /// 本地时区偏移（秒），启动时计算一次
    private static let localUTCOffsetSeconds = TimeZone.current.secondsFromGMT()

    /// 从 ISO8601 UTC 时间戳提取本地日期和小时
    /// "2026-03-12T16:30:00.000Z" 在 UTC+8 → date="2026-03-13", hour=0
    private static func extractLocalDateAndHour(from timestamp: String) -> (date: String, hour: Int) {
        guard timestamp.count >= 19 else { return (String(timestamp.prefix(10)), 0) }

        // 快速解析 UTC 时间各分量
        let y = Int(timestamp[timestamp.startIndex..<timestamp.index(timestamp.startIndex, offsetBy: 4)]) ?? 2026
        let moStart = timestamp.index(timestamp.startIndex, offsetBy: 5)
        let mo = Int(timestamp[moStart..<timestamp.index(moStart, offsetBy: 2)]) ?? 1
        let dStart = timestamp.index(timestamp.startIndex, offsetBy: 8)
        let d = Int(timestamp[dStart..<timestamp.index(dStart, offsetBy: 2)]) ?? 1
        let hStart = timestamp.index(timestamp.startIndex, offsetBy: 11)
        let h = Int(timestamp[hStart..<timestamp.index(hStart, offsetBy: 2)]) ?? 0
        let mStart = timestamp.index(timestamp.startIndex, offsetBy: 14)
        let m = Int(timestamp[mStart..<timestamp.index(mStart, offsetBy: 2)]) ?? 0

        // UTC 总分钟 → 加本地偏移
        let offsetMinutes = localUTCOffsetSeconds / 60
        var localMinute = m + offsetMinutes % 60
        var localHour = h + offsetMinutes / 60
        if localMinute >= 60 { localMinute -= 60; localHour += 1 }
        if localMinute < 0 { localMinute += 60; localHour -= 1 }

        var localDay = d
        var localMonth = mo
        var localYear = y
        if localHour >= 24 {
            localHour -= 24
            localDay += 1
            let daysInMonth = Self.daysIn(month: localMonth, year: localYear)
            if localDay > daysInMonth { localDay = 1; localMonth += 1 }
            if localMonth > 12 { localMonth = 1; localYear += 1 }
        } else if localHour < 0 {
            localHour += 24
            localDay -= 1
            if localDay < 1 {
                localMonth -= 1
                if localMonth < 1 { localMonth = 12; localYear -= 1 }
                localDay = Self.daysIn(month: localMonth, year: localYear)
            }
        }

        let dateStr = String(format: "%04d-%02d-%02d", localYear, localMonth, localDay)
        return (dateStr, localHour)
    }

    private static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28
        default: return 30
        }
    }
}

// MARK: - Internal Types

private struct UserEntry {
    let sessionId: String
    let date: String
    let hour: Int
}

private struct AssistantEntry {
    let requestId: String
    let sessionId: String
    let date: String
    let hour: Int
    let model: String
    let stopReason: String?
    let inputTokens: Int
    let outputTokens: Int
    let cacheRead: Int
    let cacheCreation: Int
    let toolCallCount: Int
}

private struct DayAccumulator {
    var messageCount: Int = 0
    var sessionIds: Set<String> = []
    var toolCallCount: Int = 0
}

private struct TokenAccumulator {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheRead: Int = 0
    var cacheCreation: Int = 0
}
