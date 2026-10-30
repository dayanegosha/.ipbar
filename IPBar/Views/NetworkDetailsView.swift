import SwiftUI
import IPBarCore

struct NetworkDetailsView: View {
    let interface: NetworkInterface
    let heroFamily: AddressFamily
    let showIPv6: Bool
    let copy: (String) -> Void
    let openAddresses: () -> Void

    private var extraCount: Int {
        max(0, interface.ipv4.count - 1) + ((showIPv6 || heroFamily == .ipv6) ? max(0, interface.ipv6.count - 1) : 0) + max(0, interface.dns.count - 1)
    }

    var body: some View {
        VStack(spacing: 11) {
            HStack {
                Text("Interface").foregroundStyle(.secondary)
                Spacer()
                Label("\(interface.kind.rawValue) (\(interface.name))", systemImage: interface.kind.symbol)
                    .lineLimit(1)
            }.font(.callout)
            if interface.isUp {
                if heroFamily == .ipv6 {
                    CopyValueRow(label: "IPv4", value: interface.primaryAddress?.address, copy: copy)
                }
                CopyValueRow(label: "Subnet mask", value: interface.primaryAddress?.mask, copy: copy)
                CopyValueRow(label: heroFamily == .ipv6 ? "IPv4 gateway" : "Gateway", value: interface.gateway, copy: copy)
                CopyValueRow(label: "DNS", value: interface.dns.first, copy: copy)
                    .help(interface.dnsScope == "System default" ? "System default DNS servers" : "Interface DNS servers")
            }
            CopyValueRow(label: "MAC address", value: interface.mac, copy: copy)
            if showIPv6, heroFamily != .ipv6, interface.isUp {
                CopyValueRow(label: "IPv6", value: interface.primaryIPv6, copy: copy)
            }
            if interface.kind == .wifi, interface.isUp {
                CopyValueRow(label: "Wi-Fi network", value: interface.ssid, copy: copy)
                    .help("macOS may hide the network name without Location Services permission. IP addresses do not need it.")
            }
            if extraCount > 0 {
                Button(action: openAddresses) {
                    HStack {
                        Text("All addresses")
                        Spacer()
                        Text("+\(extraCount)").foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption2)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).font(.callout)
            }
        }
    }
}

struct CopyValueRow: View {
    let label: String?
    let value: String?
    let copy: (String) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let label {
                Text(label).foregroundStyle(.secondary).frame(width: 86, alignment: .leading)
            }
            Spacer(minLength: 0)
            if let value {
                Button { copy(value) } label: {
                    Text(value).monospacedDigit().multilineTextAlignment(.trailing)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .trailing).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .help("Copy \(label ?? "address")")
                    .accessibilityLabel("Copy \(label ?? "address"): \(value)")
            } else {
                Text("Unavailable").foregroundStyle(.tertiary)
            }
        }.font(.callout)
    }
}
