import Foundation

final class FileMonitor: Sendable {
    private let sources: LockedBox<[DispatchSourceFileSystemObject]>
    private let queue = DispatchQueue(label: "com.claudecodemonitor.filemonitor", qos: .utility)

    init() {
        self.sources = LockedBox([])
    }

    func startMonitoring(paths: [URL], onChange: @escaping @Sendable () -> Void) {
        stopMonitoring()

        var newSources: [DispatchSourceFileSystemObject] = []
        for path in paths {
            let fd = open(path.path, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: queue
            )
            source.setEventHandler {
                onChange()
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            newSources.append(source)
        }
        sources.value = newSources
    }

    func stopMonitoring() {
        let current = sources.value
        for source in current {
            source.cancel()
        }
        sources.value = []
    }
}

// Thread-safe box for Sendable compliance
private final class LockedBox<T>: @unchecked Sendable {
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
