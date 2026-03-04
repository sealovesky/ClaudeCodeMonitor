import Foundation

enum StatsParser {
    static func parse() -> StatsCache? {
        let url = Constants.statsCachePath
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(StatsCache.self, from: data)
    }
}
