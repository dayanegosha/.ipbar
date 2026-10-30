import SwiftUI
import IPBarCore

struct NetworkDetailsView: View {
    let interface: NetworkInterface
    let showIPv6: Bool
    let copy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 5) {
                Text("PRIMARY INTERFACE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Label("\(interface.kind.rawValue) (\(interface.name))", systemImage: interface.kind.symbol)
                    .font(.body.weight(.medium))
                if interface.displayName != interface.name && interface.displayName != interface.kind.rawValue {
                    Text(interface.displayName).font(.caption).foregroundStyle(.secondary)
                }
            }
            if !interface.isUp {
                Text("This interface is disconnected.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(interface.ipv4, id: \.address) { address in
                    if address.address != interface.primaryAddress?.address {
                        CopyValueRow(label: "Additional IPv4", value: address.address, copy: copy)
                    }
                    CopyValueRow(label: interface.ipv4.count > 1 ? "Subnet mask · \(address.address)" : "Subnet mask",
                                 value: address.mask, copy: copy)
                }
                CopyValueRow(label: "Default gateway", value: interface.gateway, copy: copy)
                VStack(alignment: .leading, spacing: 5) {
                    if interface.dns.isEmpty {
                        CopyValueRow(label: "DNS servers", value: nil, copy: copy)
                    } else {
                        ForEach(Array(interface.dns.enumerated()), id: \.offset) { index, server in
                            CopyValueRow(label: index == 0 ? (interface.dnsScope == "System default" ? "DNS servers · system default" : "DNS servers") : nil, value: server, copy: copy)
                        }
                    }
                }
            }
            CopyValueRow(label: "MAC address", value: interface.mac, copy: copy)
            if showIPv6, interface.isUp {
                if interface.ipv6.isEmpty {
                    CopyValueRow(label: "IPv6", value: nil, copy: copy)
                } else {
                    ForEach(Array(interface.ipv6.enumerated()), id: \.offset) { index, address in
                        CopyValueRow(label: index == 0 ? "IPv6" : nil, value: address, copy: copy)
                    }
                }
            }
            if interface.kind == .wifi, interface.isUp {
                CopyValueRow(label: "Wi-Fi network", value: interface.ssid, copy: copy)
                if interface.ssid == nil {
                    Text("macOS may hide the network name without Location Services permission. IP addresses do not need it.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct CopyValueRow: View {
    let label: String?
    let value: String?
    let copy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label { Text(label).font(.caption).foregroundStyle(.secondary) }
            if let value {
                Button { copy(value) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(value).font(.system(.callout, design: .monospaced)).multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Image(systemName: "doc.on.doc").font(.caption).foregroundStyle(.tertiary)
                    }.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Copy \(label ?? "address")")
                .accessibilityLabel("Copy \(label ?? "address"): \(value)")
            } else {
                Text("Unavailable").font(.callout).foregroundStyle(.tertiary)
            }
        }
    }
}
