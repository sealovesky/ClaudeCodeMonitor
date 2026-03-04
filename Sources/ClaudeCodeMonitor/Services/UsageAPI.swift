import Foundation
import Security

struct UsageLimitInfo: Sendable {
    let utilization: Double
    let resetsAt: String

    var percentUsed: Int { Int(utilization) }

    var resetsAtFormatted: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: resetsAt) else {
            // 尝试不带微秒的格式
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            guard let date2 = f2.date(from: resetsAt) else { return resetsAt }
            return formatResetDate(date2)
        }
        return formatResetDate(date)
    }

    private func formatResetDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US")
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            df.dateFormat = "'today' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            df.dateFormat = "'tomorrow' h:mm a"
        } else {
            df.dateFormat = "MMM d, h:mm a"
        }
        return df.string(from: date)
    }
}

struct UsageData: Sendable {
    let session: UsageLimitInfo?      // five_hour
    let weekAll: UsageLimitInfo?      // seven_day
    let weekSonnet: UsageLimitInfo?   // seven_day_sonnet
}

enum UsageAPI {
    private static let apiURL = "https://api.anthropic.com/api/oauth/usage"

    static func fetch() async -> UsageData? {
        guard let token = readAccessToken() else { return nil }

        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/2.1.63", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return UsageData(
            session: parseLimitInfo(json["five_hour"]),
            weekAll: parseLimitInfo(json["seven_day"]),
            weekSonnet: parseLimitInfo(json["seven_day_sonnet"])
        )
    }

    private static func parseLimitInfo(_ obj: Any?) -> UsageLimitInfo? {
        guard let dict = obj as? [String: Any],
              let utilization = dict["utilization"] as? Double,
              let resetsAt = dict["resets_at"] as? String
        else { return nil }
        return UsageLimitInfo(utilization: utilization, resetsAt: resetsAt)
    }

    // MARK: - Keychain

    private static func readAccessToken() -> String? {
        // 1. 环境变量
        if let envToken = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"] {
            return envToken
        }

        // 2. macOS Keychain
        if let keychainToken = readFromKeychain() {
            return keychainToken
        }

        // 3. 文件回退
        return readFromCredentialsFile()
    }

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecAttrAccount as String: NSUserName(),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }

        // Keychain 存储的是 hex 编码的 JSON
        guard let hexString = String(data: data, encoding: .utf8) else { return nil }
        guard let jsonData = hexToData(hexString) else {
            // 可能不是 hex，直接尝试 JSON
            return extractToken(from: data)
        }
        return extractToken(from: jsonData)
    }

    private static func readFromCredentialsFile() -> String? {
        let path = Constants.claudeDir.appendingPathComponent(".credentials.json")
        guard let data = try? Data(contentsOf: path) else { return nil }
        return extractToken(from: data)
    }

    private static func extractToken(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { return nil }
        return token
    }

    private static func hexToData(_ hex: String) -> Data? {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count % 2 == 0 else { return nil }
        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}
