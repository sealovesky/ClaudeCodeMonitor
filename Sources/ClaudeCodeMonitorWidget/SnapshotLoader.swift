// Widget 端：HTTP GET 拉 App 投递的 WidgetSnapshot
//
// 不走 App Group / UserDefaults — macOS Sonoma+ TCC 标 widget 为
// SystemPolicyAppData，禁读其他进程产出文件且不弹同意框。
// loopback HTTP 绕开 TCC（不管网络）。

import Foundation

enum SnapshotLoader {
    /// Sendable 包装 — Swift 6 严格并发不允许 @Sendable closure 捕获 var
    private final class Box: @unchecked Sendable {
        var value: WidgetSnapshot?
    }

    /// Widget 同步阻塞 fetch。短任务、本机 loopback、最多 1s 超时。
    static func loadLatest() -> WidgetSnapshot? {
        var req = URLRequest(url: SnapshotLoopback.url)
        req.timeoutInterval = 0.5
        req.cachePolicy = .reloadIgnoringLocalCacheData

        let sem = DispatchSemaphore(value: 0)
        let box = Box()
        URLSession.shared.dataTask(with: req) { data, _, err in
            defer { sem.signal() }
            if let err = err {
                NSLog("[CCM Load] http fail: %@", err.localizedDescription)
                return
            }
            guard let data = data, !data.isEmpty else {
                NSLog("[CCM Load] empty body")
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                box.value = try decoder.decode(WidgetSnapshot.self, from: data)
            } catch {
                NSLog("[CCM Load] decode fail: %@", error.localizedDescription)
            }
        }.resume()
        _ = sem.wait(timeout: .now() + 1.0)
        return box.value
    }
}
