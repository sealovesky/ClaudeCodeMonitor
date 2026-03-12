import Foundation

/// 使用 FSEventStream 监控 ~/.claude/projects/ 整个目录树
/// 任何 JSONL 文件写入都会触发回调
final class ProjectsMonitor: Sendable {
    private let streamRef: LockedBoxPM<FSEventStreamRef?>
    private let queue = DispatchQueue(label: "com.claudecodemonitor.projectsmonitor", qos: .utility)

    init() {
        self.streamRef = LockedBoxPM(nil)
    }

    func startMonitoring(path: String, onChange: @escaping @Sendable () -> Void) {
        stopMonitoring()

        var context = FSEventStreamContext()
        // 将 closure 包装为 Unmanaged 指针传入 context.info
        let callbackBox = CallbackBox(onChange)
        context.info = Unmanaged.passRetained(callbackBox).toOpaque()

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, eventFlags, _ in
            guard let info = info else { return }
            let box = Unmanaged<CallbackBox>.fromOpaque(info).takeUnretainedValue()

            // 检查是否有 JSONL 相关的变化
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
            for i in 0..<numEvents {
                let path = paths[i]
                // 只在涉及 jsonl 文件或其所在目录时触发
                if path.hasSuffix(".jsonl") || !path.contains(".") {
                    box.callback()
                    return
                }
            }
        }

        let pathsToWatch = [path] as CFArray
        let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,  // 1 秒延迟合并事件
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        guard let stream = stream else { return }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        streamRef.value = stream
    }

    func stopMonitoring() {
        if let stream = streamRef.value {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)

            FSEventStreamRelease(stream)
            streamRef.value = nil
        }
    }
}

/// 持有回调闭包的引用类型，用于传入 FSEventStream context
private final class CallbackBox: @unchecked Sendable {
    let callback: @Sendable () -> Void

    init(_ callback: @escaping @Sendable () -> Void) {
        self.callback = callback
    }
}

/// Thread-safe box for Sendable compliance (避免与 FileMonitor 中的 LockedBox 命名冲突)
private final class LockedBoxPM<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) {
        self._value = value
    }

    var value: T {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}
