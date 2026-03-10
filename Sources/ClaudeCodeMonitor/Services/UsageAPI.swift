import Foundation

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

enum UsageFetchResult: Sendable {
    case success(UsageData)
    case rateLimited
    case failure
}

enum UsageAPI {
    private static let apiURL = "https://api.anthropic.com/api/oauth/usage"

    static func fetch() async -> UsageFetchResult {
        // 第一次尝试（用缓存的 token）
        let result = await doFetch()
        if case .success = result { return result }
        if case .rateLimited = result { return result }

        // 其他失败，可能 token 过期，清除缓存重试一次（会重新读 Keychain）
        invalidateTokenCache()
        return await doFetch()
    }

    private static func doFetch() async -> UsageFetchResult {
        guard let token = readAccessToken() else { return .failure }

        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/2.1.63", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse
        else { return .failure }

        if httpResponse.statusCode == 429 { return .rateLimited }
        guard httpResponse.statusCode == 200 else { return .failure }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .failure }

        return .success(UsageData(
            session: parseLimitInfo(json["five_hour"]),
            weekAll: parseLimitInfo(json["seven_day"]),
            weekSonnet: parseLimitInfo(json["seven_day_sonnet"])
        ))
    }

    private static func parseLimitInfo(_ obj: Any?) -> UsageLimitInfo? {
        guard let dict = obj as? [String: Any],
              let utilization = dict["utilization"] as? Double,
              let resetsAt = dict["resets_at"] as? String
        else { return nil }
        return UsageLimitInfo(utilization: utilization, resetsAt: resetsAt)
    }

    // MARK: - Keychain

    private static let cachedTokenKey = "cachedOAuthToken"

    /// 清除缓存的 token（API 调用失败时调用，下次会重新从 Keychain 读取）
    static func invalidateTokenCache() {
        UserDefaults.standard.removeObject(forKey: cachedTokenKey)
    }

    private static func readAccessToken() -> String? {
        // 1. 环境变量
        if let envToken = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"] {
            return envToken
        }

        // 2. 文件优先（不会触发系统授权弹窗）
        if let fileToken = readFromCredentialsFile() {
            return fileToken
        }

        // 3. 缓存（之前从 Keychain 读取后缓存的 token，永久有效直到 API 失败）
        if let cached = UserDefaults.standard.string(forKey: cachedTokenKey) {
            return cached
        }

        // 4. security CLI 读 Keychain（仅首次或缓存被清除时触发，成功后永久缓存）
        if let keychainToken = readFromKeychain() {
            UserDefaults.standard.set(keychainToken, forKey: cachedTokenKey)
            return keychainToken
        }

        return nil
    }

    private static func readFromKeychain() -> String? {
        // 使用 security CLI 读取 Keychain，避免 SecItemCopyMatching 触发系统授权弹窗
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "find-generic-password",
            "-s", "Claude Code-credentials",
            "-a", NSUserName(),
            "-w"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonString = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !jsonString.isEmpty
        else { return nil }

        // security -w 直接返回明文 JSON
        return extractToken(from: Data(jsonString.utf8))
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
}
