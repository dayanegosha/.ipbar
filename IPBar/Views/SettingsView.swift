import SwiftUI
import IPBarCore

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var login: LoginItemController
    @State private var section = 0

    private var interfaceNames: [String] { monitor.snapshot.interfaces.map(\.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Settings section", selection: $section) {
                Text("Display").tag(0)
                Text("Network").tag(1)
                Text("General").tag(2)
            }.pickerStyle(.segmented).labelsHidden()
            if section == 0 {
                GroupBox("Menu bar") {
                    VStack(alignment: .leading, spacing: 16) {
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
                    }.padding(8)
                }
                Text("IPv6 prefers a global address, then a local one. A link-local address includes its interface scope.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if section == 1 {
                GroupBox("Interface") {
                    VStack(alignment: .leading, spacing: 12) {
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
                        }.labelsHidden()
                        Text("Automatic follows the default IPv4 route or the system’s primary IPv6 interface.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
                GroupBox("Updates") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Fallback interval", selection: $settings.interval) {
                            ForEach(SettingsStore.intervals, id: \.self) { Text($0 == 1 ? "1 second" : "\($0) seconds").tag($0) }
                        }
                        Text("Network changes always update automatically. The interval is an additional check.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
            } else {
                GroupBox("Startup") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Launch at login", isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
                        if login.needsApproval {
                            Button("Approve in System Settings…") { login.openSystemSettings() }
                        } else if let message = login.message {
                            Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2).help(message)
                        }
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Replace the Wi-Fi icon") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(SystemSettings.menuBarInstructions).font(.caption).foregroundStyle(.secondary)
                        Button("Open menu bar settings…") { SystemSettings.open(.menuBar) }
                        Button("Wi-Fi settings…") { SystemSettings.open(.wifi) }
                        Button("Network settings…") { SystemSettings.open(.network) }
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Network information stays on this Mac. Connect to networks and Personal Hotspot in the macOS Wi-Fi settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(20)
            .onAppear { login.refresh() }
    }
}
