import Foundation
import ServiceManagement

enum LaunchAtLogin {
    @MainActor
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @MainActor
    static func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("LaunchAtLogin toggle failed: \(error)")
        }
    }
}
