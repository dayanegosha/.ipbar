import Foundation

public enum InterfaceKind: String, Codable, CaseIterable, Sendable {
    case wifi = "Wi-Fi", ethernet = "Ethernet", vpn = "VPN", other = "Other"

    public var symbol: String {
        switch self {
        case .wifi: return "wifi"
        case .ethernet: return "network"
        case .vpn: return "lock.shield"
        case .other: return "point.3.connected.trianglepath.dotted"
        }
    }
}

public struct IPv4Address: Equatable, Codable, Sendable {
    public var address: String
    public var mask: String?
    public var isSelfAssigned: Bool { address.hasPrefix("169.254.") }

    public init(_ address: String, mask: String? = nil) {
        self.address = address
        self.mask = mask
    }
}

public struct NetworkInterface: Identifiable, Equatable, Codable, Sendable {
    public var id: String { name }
    public var name: String
    public var displayName: String
    public var kind: InterfaceKind
    public var isUp: Bool
    public var ipv4: [IPv4Address]
    public var ipv6: [String]
    public var mac: String?
    public var gateway: String?
    public var dns: [String]
    public var dnsScope = "Interface"
    public var ssid: String?
    public var primaryAddress: IPv4Address? {
        ipv4.first(where: { !$0.isSelfAssigned }) ?? ipv4.first
    }

    public init(name: String, displayName: String? = nil, kind: InterfaceKind = .other,
                isUp: Bool = true, ipv4: [IPv4Address] = [], ipv6: [String] = [],
                mac: String? = nil, gateway: String? = nil, dns: [String] = [], ssid: String? = nil) {
        self.name = name
        self.displayName = displayName ?? name
        self.kind = kind
        self.isUp = isUp
        self.ipv4 = ipv4
        self.ipv6 = ipv6
        self.mac = mac
        self.gateway = gateway
        self.dns = dns
        self.ssid = ssid
    }
}
