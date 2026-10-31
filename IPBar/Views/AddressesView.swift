import SwiftUI
import IPBarCore

struct AddressesView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var settings: SettingsStore
    @State private var page = 0
    @State private var copied = false
    private let pageSize = 5

    private var entries: [(String, String)] {
        guard let interface = monitor.snapshot.selected(InterfaceSelection(rawValue: settings.selection), family: settings.addressFamily) else { return [] }
        var values: [(String, String)] = []
        for address in interface.ipv4 {
            values.append(("IPv4", address.address))
            if let mask = address.mask { values.append(("Mask", mask)) }
        }
        values += interface.dns.map { ("DNS", $0) }
        if settings.showIPv6 || settings.addressFamily == .ipv6 { values += interface.ipv6.map { ("IPv6", $0) } }
        return values
    }
    private var pages: Int { max(1, (entries.count + pageSize - 1) / pageSize) }
    private var currentPage: Int { min(page, pages - 1) }

    var body: some View {
        VStack(spacing: 20) {
            if entries.isEmpty {
                Text("No addresses available").foregroundStyle(.secondary)
            } else {
                ForEach(Array(entries.dropFirst(currentPage * pageSize).prefix(pageSize).enumerated()), id: \.offset) { _, entry in
                    CopyValueRow(label: entry.0, value: entry.1) { value in
                        copied = ClipboardManager.copy(value)
                    }
                    Divider()
                }
            }
            if copied { Text("Copied").font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button { page = max(0, currentPage - 1); copied = false } label: {
                    Label("Previous", systemImage: "chevron.left")
                }.disabled(currentPage == 0)
                Spacer()
                Text("\(currentPage + 1) / \(pages)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { page = min(pages - 1, currentPage + 1); copied = false } label: {
                    Label("Next", systemImage: "chevron.right")
                }.disabled(currentPage + 1 == pages)
            }.buttonStyle(.plain).font(.callout)
        }.padding(20)
    }
}
