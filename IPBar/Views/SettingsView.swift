import SwiftUI
import IPBarCore

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var login: LoginItemController

    private var interfaceNames: [String] { monitor.snapshot.interfaces.map(\.name) }

    var body: some View {
        Form {
            Section("Menu bar") {
                Picker("Address", selection: $settings.addressFamily) {
                    Text("IPv4").tag(AddressFamily.ipv4)
                    Text("IPv6").tag(AddressFamily.ipv6)
                }
                Picker("Display", selection: $settings.display) {
                    Text("Address only").tag(MenuDisplay.address)
                    Text("Address + interface").tag(MenuDisplay.interface)
                    Text("With IP prefix").tag(MenuDisplay.prefixed)
                }
                Toggle("Show IPv6 in details", isOn: $settings.showIPv6)
            }
            Section {
                Picker("Interface", selection: $settings.selection) {
                    Text("Automatic").tag("automatic")
                    ForEach([InterfaceKind.wifi, .ethernet, .vpn], id: \.rawValue) { kind in
                        Text(kind.rawValue).tag(kind.rawValue)
                    }
                    Divider()
                    ForEach(monitor.snapshot.interfaces) { interface in
                        Text("\(interface.name) — \(interface.kind.rawValue)\(interface.isUp ? "" : " (disconnected)")")
                            .tag("interface:" + interface.name)
                    }
                    if case .named(let name) = InterfaceSelection(rawValue: settings.selection), !interfaceNames.contains(name) {
                        Text("\(name) (unavailable)").tag(settings.selection)
                    }
                }
                Text("Automatic follows the default IPv4 route or the system’s primary IPv6 interface. Split-tunnel VPNs can be selected manually.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("Network") }
            Section("Updates") {
                Toggle("Automatically refresh", isOn: $settings.automaticRefresh)
                Picker("Fallback interval", selection: $settings.interval) {
                    ForEach(SettingsStore.intervals, id: \.self) { Text($0 == 1 ? "1 second" : "\($0) seconds").tag($0) }
                }.disabled(!settings.automaticRefresh)
                Text("Network changes always update immediately. The interval is an additional check; turning it off keeps system notifications active.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Replace the Wi-Fi icon") {
                Text(SystemSettings.menuBarInstructions).font(.caption).foregroundStyle(.secondary)
                Button("Open menu bar settings…") { SystemSettings.open(.menuBar) }
                Button("Wi-Fi settings…") { SystemSettings.open(.wifi) }
                Button("Network settings…") { SystemSettings.open(.network) }
                Text("Choose networks, enter passwords, and use Personal Hotspot in the macOS Wi-Fi settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
                if let message = login.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                if login.needsApproval { Button("Open Login Items…") { login.openSystemSettings() } }
                Text("No accounts, analytics, or external IP services. Network information stays on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { login.refresh() }
    }
}
