import Foundation

public enum NetworkReport {
    public static func text(snapshot: NetworkSnapshot, selection: InterfaceSelection, includeIPv6: Bool) -> String {
        let interface = snapshot.selected(selection)
        var lines = ["IP Bar", "Status: \(snapshot.status(for: interface).rawValue)"]
        guard let interface else { return (lines + ["IPv4: No IP"]).joined(separator: "\n") }
        lines += ["Interface: \(interface.name)", "Type: \(interface.kind.rawValue)", "Service: \(interface.displayName)"]
        if interface.ipv4.isEmpty { lines.append("IPv4: No IP") }
        for address in interface.ipv4 {
            lines.append("IPv4: \(address.address)")
            lines.append("Subnet mask: \(address.mask ?? "Unavailable")")
        }
        lines.append("Gateway: \(interface.gateway ?? "Unavailable")")
        lines.append("DNS: \(interface.dns.isEmpty ? "Unavailable" : interface.dns.joined(separator: ", "))")
        lines.append("MAC: \(interface.mac ?? "Unavailable")")
        if includeIPv6 { for address in interface.ipv6 { lines.append("IPv6: \(address)") } }
        if interface.kind == .wifi { lines.append("SSID: \(interface.ssid ?? "Unavailable (may require Location Services)")") }
        lines.append("Selection: \(snapshot.routeDescription)")
        lines.append("Updated: \(ISO8601DateFormatter().string(from: snapshot.collectedAt))")
        return lines.joined(separator: "\n")
    }
}
