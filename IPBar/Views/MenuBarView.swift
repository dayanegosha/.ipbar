import SwiftUI
import IPBarCore

struct MenuBarView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var settings: SettingsStore
    @ObservedObject var wifi: WiFiController
    let openSettings: () -> Void
    let quit: () -> Void
    @State private var copyMessage: String?
    @State private var feedbackTask: Task<Void, Never>?

    private var interface: NetworkInterface? { monitor.snapshot.selected(InterfaceSelection(rawValue: settings.selection), family: settings.addressFamily) }
    private var status: ConnectionStatus { monitor.snapshot.status(for: interface) }
    private var address: String? { settings.addressFamily.address(for: interface) }
    private var showsInitialLoading: Bool { monitor.isChecking && monitor.snapshot.interfaces.isEmpty }
    private var statusColor: Color {
        switch status {
        case .connected: return .green
        case .selfAssigned, .localOnly, .ipv6Only: return .orange
        default: return .secondary
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 6) {
                            Circle().fill(showsInitialLoading ? .secondary : statusColor).frame(width: 6, height: 6)
                            Text(showsInitialLoading ? "Checking network…" : status.rawValue).font(.callout).foregroundStyle(.secondary)
                            Spacer()
                            if let copyMessage { Text(copyMessage).font(.caption).foregroundStyle(.secondary) }
                        }
                        Button { if let address { copy(address) } } label: {
                            HStack(spacing: 10) {
                                Text(address ?? settings.addressFamily.emptyTitle).font(.system(size: settings.addressFamily == .ipv6 ? 19 : 23, weight: .medium)).monospacedDigit()
                                    .lineLimit(settings.addressFamily == .ipv6 ? 2 : 1).minimumScaleFactor(0.85).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                if address != nil { Image(systemName: "doc.on.doc").font(.callout).foregroundStyle(.secondary) }
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(address == nil)
                            .accessibilityLabel(address.map { "Copy \(settings.addressFamily.label): \($0)" } ?? "No \(settings.addressFamily.label) address")
                            .help("Copy \(settings.addressFamily.label) address")
                        if status == .selfAssigned {
                            Text("No DHCP lease. This link-local address only works on the local segment.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    WiFiControlsView(wifi: wifi)
                    Divider()
                    if let interface {
                        NetworkDetailsView(interface: interface, heroFamily: settings.addressFamily, showIPv6: settings.showIPv6, copy: copy)
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
                            Text(settings.selection == "automatic" ? (settings.addressFamily == .ipv6 ? "System IPv6 interface" : monitor.snapshot.routeDescription) : "Selected in Settings")
                            Text("Updated \(monitor.snapshot.collectedAt.formatted(date: .omitted, time: .standard))")
                        }.font(.caption2).foregroundStyle(.tertiary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 18)
            }.frame(maxHeight: .infinity)
            Divider()
            HStack(spacing: 10) {
                Button { copy(NetworkReport.text(snapshot: monitor.snapshot,
                    selection: InterfaceSelection(rawValue: settings.selection), includeIPv6: settings.showIPv6 || settings.addressFamily == .ipv6, family: settings.addressFamily)) } label: {
                    Label("Copy All", systemImage: "doc.on.doc")
                }.disabled(monitor.isChecking)
                Spacer()
                Button { monitor.refresh() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }.disabled(monitor.isRefreshing).keyboardShortcut("r", modifiers: .command)
            }.controlSize(.small).padding(.horizontal, 20).padding(.vertical, 12)
            HStack {
                Button("Settings", action: openSettings).keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button("Quit", action: quit).keyboardShortcut("q", modifiers: .command)
            }.buttonStyle(.plain).font(.callout).foregroundStyle(.secondary)
                .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .frame(width: 380).frame(maxHeight: .infinity, alignment: .top)
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
