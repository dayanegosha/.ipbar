import AppKit
import IPBarCore

@main
struct IPBarApp {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--diagnostics") {
            let snapshot = NetworkInfoProvider().snapshot()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(snapshot), let output = String(data: data, encoding: .utf8) {
                print(output)
            }
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
