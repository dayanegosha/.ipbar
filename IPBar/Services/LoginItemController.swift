import AppKit
import Combine
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var message: String?
    @Published private(set) var needsApproval = false

    init() { refresh() }

    func refresh() {
        let status = SMAppService.mainApp.status
        enabled = status == .enabled || status == .requiresApproval
        needsApproval = status == .requiresApproval
        if needsApproval { message = "Allow .ipbar in System Settings → General → Login Items." }
    }

    func enableOnFirstLaunch(settings: SettingsStore) {
        guard !settings.didAttemptDefaultLogin else { return }
        settings.didAttemptDefaultLogin = true
        setEnabled(true)
    }

    func setEnabled(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            message = nil
        } catch {
            message = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
