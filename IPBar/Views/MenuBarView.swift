import SwiftUI
import IPBarCore

struct MenuBarView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var settings: SettingsStore
    let openSettings: () -> Void
    let quit: () -> Void
    @State private var copyMessage: String?
    @State private var feedbackTask: Task<Void, Never>?

    private var interface: NetworkInterface? { monitor.snapshot.selected(InterfaceSelection(rawValue: settings.selection)) }
    private var status: ConnectionStatus { monitor.snapshot.status(for: interface) }
    private var address: String? { interface?.isUp == true ? interface?.primaryAddress?.address : nil }
    private var statusColor: Color {
        switch status {
        case .connected: return .green
        case .selfAssigned, .localOnly, .ipv6Only: return .orange
        default: return .secondary
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("IP Bar").font(.headline)
                Spacer()
                if let copyMessage { Text(copyMessage).font(.caption).foregroundStyle(.secondary) }
                else { Image(systemName: "network").foregroundStyle(.secondary) }
            }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 6) {
                            Circle().fill(monitor.isChecking ? .secondary : statusColor).frame(width: 6, height: 6)
                            Text(monitor.isChecking ? "Checking network…" : status.rawValue).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        }
                        Button { if let address { copy(address) } } label: {
                            HStack(spacing: 10) {
                                Text(address ?? "No IP").font(.system(size: 27, weight: .medium, design: .monospaced))
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Spacer(minLength: 0)
                                if address != nil { Image(systemName: "doc.on.doc").font(.callout).foregroundStyle(.secondary) }
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(address == nil)
                            .accessibilityLabel(address.map { "Copy IPv4: \($0)" } ?? "No IPv4 address")
                            .help("Copy IPv4 address")
                        if status == .selfAssigned {
                            Text("No DHCP lease. This link-local address only works on the local segment.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    if let interface {
                        NetworkDetailsView(interface: interface, showIPv6: settings.showIPv6, copy: copy)
                    } else if !monitor.isChecking {
                        Text(settings.selection == "automatic" ? "No active network interface was found." : "The selected interface is not available. Choose another interface in Settings.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(monitor.snapshot.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.secondary)
                    }
                    if let warning = monitor.monitoringWarning {
                        Text(warning).font(.caption).foregroundStyle(.secondary)
                    }
                    if !monitor.isChecking {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(settings.selection == "automatic" ? monitor.snapshot.routeDescription : "Selected in Settings")
                            Text("Updated \(monitor.snapshot.collectedAt.formatted(date: .omitted, time: .standard))")
                        }.font(.caption2).foregroundStyle(.tertiary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 18)
            }.frame(maxHeight: 440)
            Divider()
            HStack(spacing: 10) {
                Button { copy(NetworkReport.text(snapshot: monitor.snapshot,
                    selection: InterfaceSelection(rawValue: settings.selection), includeIPv6: settings.showIPv6)) } label: {
                    Label("Copy All", systemImage: "doc.on.doc")
                }.disabled(monitor.isChecking)
                Spacer()
                Button { monitor.refresh() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }.disabled(monitor.isRefreshing).keyboardShortcut("r", modifiers: .command)
            }.controlSize(.small).padding(.horizontal, 20).padding(.vertical, 12)
            HStack {
                Button("Settings…", action: openSettings).keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button("Quit IP Bar", action: quit).keyboardShortcut("q", modifiers: .command)
            }.buttonStyle(.plain).font(.callout).foregroundStyle(.secondary)
                .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .frame(width: 380)
        .onDisappear { feedbackTask?.cancel(); copyMessage = nil }
    }

    private func copy(_ value: String) {
        copyMessage = ClipboardManager.copy(value) ? "Copied" : "Could not copy"
        feedbackTask?.cancel()
        feedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            copyMessage = nil
        }
    }
}
