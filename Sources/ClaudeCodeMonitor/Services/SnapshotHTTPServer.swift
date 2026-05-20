// App 端 loopback HTTP server，给 widget 拉数据用
//
// 走网络是因为 macOS Sonoma+ widget extension 被 TCC 标 SystemPolicyAppData，
// 禁读其他进程产出文件（即使同 App Group 容器）。TCC 不管 loopback 网络。
// 详细背景见 ~/Project/ClaudeTeamMonitor/CLAUDE.md「macOS 致命陷阱」段落。

import Foundation
import Network

final class SnapshotHTTPServer: @unchecked Sendable {
    private var listener: NWListener?
    private let lock = NSLock()
    private var current: WidgetSnapshot?
    private let queue = DispatchQueue(label: "ccm.snapshot.http")

    func update(_ snapshot: WidgetSnapshot) {
        lock.lock(); defer { lock.unlock() }
        current = snapshot
    }

    private var snapshot: WidgetSnapshot? {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: .ipv4(.loopback),
                port: NWEndpoint.Port(rawValue: SnapshotLoopback.port)!
            )
            let l = try NWListener(using: params)
            l.newConnectionHandler = { [weak self] conn in
                self?.handle(conn)
            }
            l.start(queue: queue)
            self.listener = l
            NSLog("[CCM HTTP] listening on 127.0.0.1:%d", SnapshotLoopback.port)
        } catch {
            NSLog("[CCM HTTP] listen fail: %@", error.localizedDescription)
        }
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] _, _, _, _ in
            guard let self = self else { conn.cancel(); return }
            let body: Data
            if let snap = self.snapshot {
                let enc = JSONEncoder()
                enc.dateEncodingStrategy = .iso8601
                body = (try? enc.encode(snap)) ?? Data("{}".utf8)
            } else {
                body = Data("{}".utf8)
            }
            let header = "HTTP/1.0 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
            var resp = Data(header.utf8)
            resp.append(body)
            conn.send(content: resp, completion: .contentProcessed { _ in
                conn.cancel()
            })
        }
    }
}
