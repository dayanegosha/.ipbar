import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var login: LoginItemController

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable().frame(width: 60, height: 60).accessibilityHidden(true)
            Text("Your address.\nAlways in view.")
                .font(.system(size: 26, weight: .medium)).fixedSize(horizontal: false, vertical: true)
            Text("Keep the address in place of the system Wi-Fi icon. Connection controls are one click away.")
                .font(.body).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                Label("Hide the extra Wi-Fi icon", systemImage: "menubar.rectangle")
                    .font(.body.weight(.medium))
                Text(SystemSettings.menuBarInstructions)
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Open menu bar settings…") { SystemSettings.open(.menuBar) }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Launch at login", isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
                    .toggleStyle(.switch).controlSize(.small)
                if let message = login.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                if login.needsApproval { Button("Open Login Items…") { login.openSystemSettings() } }
            }
            Spacer(minLength: 0)
            Button { settings.onboardingComplete = true } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.large)
        }.padding(26)
    }
}
