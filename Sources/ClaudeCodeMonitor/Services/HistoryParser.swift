import Foundation

enum HistoryParser {
    static func parse() -> [HistoryEntry] {
        let url = Constants.historyPath
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8)
        else { return [] }

        let decoder = JSONDecoder()
        var entries: [HistoryEntry] = []
        entries.reserveCapacity(8000)

        for line in content.split(separator: "\n") where !line.isEmpty {
            if let lineData = line.data(using: .utf8),
               let entry = try? decoder.decode(HistoryEntry.self, from: lineData)
            {
                entries.append(entry)
            }
        }
        return entries
    }

    struct HistorySummary: Sendable {
        let projects: [ProjectStats]
        let uniqueSessionCount: Int
        let uniqueDayCount: Int
    }

    static func aggregate(from entries: [HistoryEntry]) -> HistorySummary {
        var projectMap: [String: ProjectStats] = [:]
        var allSessionIds: Set<String> = []
        var allDates: Set<String> = []

        let dateFormatter = DateFormatters.dateOnly

        for entry in entries {
            // Collect unique sessions and dates
            if let sid = entry.sessionId {
                allSessionIds.insert(sid)
            }
            allDates.insert(dateFormatter.string(from: entry.date))

            // Aggregate projects
            guard let project = entry.project else { continue }
            let name = entry.projectName
            if projectMap[project] != nil {
                projectMap[project]!.messageCount += 1
                if let sid = entry.sessionId {
                    projectMap[project]!.sessionIds.insert(sid)
                }
            } else {
                var sessionIds: Set<String> = []
                if let sid = entry.sessionId {
                    sessionIds.insert(sid)
                }
                projectMap[project] = ProjectStats(
                    projectPath: project,
                    projectName: name,
                    messageCount: 1,
                    sessionIds: sessionIds
                )
            }
        }

        return HistorySummary(
            projects: projectMap.values.sorted { $0.messageCount > $1.messageCount },
            uniqueSessionCount: allSessionIds.count,
            uniqueDayCount: allDates.count
        )
    }

    static func aggregateProjects(from entries: [HistoryEntry]) -> [ProjectStats] {
        var map: [String: ProjectStats] = [:]
        for entry in entries {
            guard let project = entry.project else { continue }
            let name = entry.projectName
            if map[project] != nil {
                map[project]!.messageCount += 1
                if let sid = entry.sessionId {
                    map[project]!.sessionIds.insert(sid)
                }
            } else {
                var sessionIds: Set<String> = []
                if let sid = entry.sessionId {
                    sessionIds.insert(sid)
                }
                map[project] = ProjectStats(
                    projectPath: project,
                    projectName: name,
                    messageCount: 1,
                    sessionIds: sessionIds
                )
            }
        }
        return map.values.sorted { $0.messageCount > $1.messageCount }
    }
}
