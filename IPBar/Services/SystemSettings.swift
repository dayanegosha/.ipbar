import AppKit

@MainActor
enum SystemSettings {
    enum Pane: String {
        case wifi = "com.apple.wifi-settings-extension"
        case network = "com.apple.Network-Settings.extension"
        case menuBar = "com.apple.ControlCenter-Settings.extension"
    }

    static var menuBarInstructions: String {
        if #available(macOS 26, *) {
            return "In System Settings → Menu Bar, turn off Wi-Fi. This only hides the icon; your connection stays on."
        }
        return "In System Settings → Control Center → Wi-Fi, choose Don’t Show in Menu Bar. Your connection stays on."
    }

    static func open(_ pane: Pane) {
        let url = URL(string: "x-apple.systempreferences:\(pane.rawValue)")!
        if !NSWorkspace.shared.open(url),
           let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
            NSWorkspace.shared.open(app)
        }
    }
}
