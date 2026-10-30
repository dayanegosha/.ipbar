import Foundation

public enum AddressFamily: String, CaseIterable, Sendable {
    case ipv4, ipv6

    public var label: String { self == .ipv4 ? "IPv4" : "IPv6" }
    public var emptyTitle: String { self == .ipv4 ? "No IP" : "No IPv6" }

    public func address(for interface: NetworkInterface?) -> String? {
        guard let interface, interface.isUp else { return nil }
        return self == .ipv4 ? interface.primaryAddress?.address : interface.primaryIPv6
    }
}

extension NetworkInterface {
    public var primaryIPv6: String? {
        let addresses = ipv6.filter { $0 != "::" && $0 != "::1" && !$0.lowercased().hasPrefix("ff") }
        return addresses.first { !Self.isLinkLocalIPv6($0) && !$0.lowercased().hasPrefix("fc") && !$0.lowercased().hasPrefix("fd") }
            ?? addresses.first { !Self.isLinkLocalIPv6($0) }
            ?? addresses.first
    }

    private static func isLinkLocalIPv6(_ address: String) -> Bool {
        ["fe8", "fe9", "fea", "feb"].contains { address.lowercased().hasPrefix($0) }
    }
}
