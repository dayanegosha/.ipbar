import AppKit

@MainActor
enum ClipboardManager {
    @discardableResult static func copy(_ text: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }
}
