import Foundation
import ServiceManagement

final class LaunchAtLoginManager {
    func currentStatus() -> SMAppService.Status {
        SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard currentStatus() != .enabled else {
                return
            }
            try SMAppService.mainApp.register()
        } else {
            guard currentStatus() != .notRegistered else {
                return
            }
            try SMAppService.mainApp.unregister()
        }
    }

    func menuStatusMessage(for status: SMAppService.Status) -> String? {
        switch status {
        case .enabled:
            return nil
        case .notRegistered:
            return nil
        case .requiresApproval:
            return "Launch at Login requires approval in System Settings."
        case .notFound:
            return "Launch at Login is unavailable for this build."
        @unknown default:
            return "Launch at Login status is unknown."
        }
    }
}
