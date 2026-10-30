import Foundation

public enum InterfaceSelection: Equatable, Sendable {
    case automatic
    case kind(InterfaceKind)
    case named(String)

    public init(rawValue: String) {
        if rawValue.hasPrefix("interface:") {
            self = .named(String(rawValue.dropFirst(10)))
        } else if let kind = InterfaceKind(rawValue: rawValue) {
            self = .kind(kind)
        } else {
            self = .automatic
        }
    }

    public var rawValue: String {
        switch self {
        case .automatic: return "automatic"
        case .kind(let kind): return kind.rawValue
        case .named(let name): return "interface:" + name
        }
    }
}

public enum ConnectionStatus: String, Codable, Sendable {
    case connected = "Connected"
    case localOnly = "Local network only"
    case selfAssigned = "Self-assigned address"
    case ipv6Only = "IPv6 only"
    case offline = "Offline"
    case unavailable = "Unavailable"
}

public struct NetworkSnapshot: Equatable, Codable, Sendable {
    public var interfaces: [NetworkInterface]
    public var primaryName: String?
    public var primaryIPv6Name: String?
    public var routeDescription: String
    public var warnings: [String]
    public var collectedAt: Date

    public init(interfaces: [NetworkInterface] = [], primaryName: String? = nil, primaryIPv6Name: String? = nil,
                routeDescription: String = "No default route", warnings: [String] = [], collectedAt: Date = Date()) {
        self.interfaces = interfaces
        self.primaryName = primaryName
        self.primaryIPv6Name = primaryIPv6Name
        self.routeDescription = routeDescription
        self.warnings = warnings
        self.collectedAt = collectedAt
    }

    public func selected(_ selection: InterfaceSelection, family: AddressFamily = .ipv4) -> NetworkInterface? {
        let preferredName = family == .ipv6 ? (primaryIPv6Name ?? primaryName) : primaryName
        let active = interfaces.filter(\.isUp)
        switch selection {
        case .named(let name): return interfaces.first { $0.name == name }
        case .kind(let kind):
            let candidates = active.filter { $0.kind == kind }
            return candidates.first { $0.name == preferredName }
                ?? candidates.first { family.address(for: $0) != nil }
                ?? candidates.first { !$0.ipv6.isEmpty }
        case .automatic:
            // Не подменяем IPv6-only основной интерфейс адресом случайного адаптера.
            if let primary = active.first(where: { $0.name == preferredName }) { return primary }
            return active.first { family.address(for: $0) != nil && $0.kind != .other }
                ?? active.first { family.address(for: $0) != nil }
                ?? active.first { !$0.ipv6.isEmpty }
        }
    }

    public func status(for interface: NetworkInterface?) -> ConnectionStatus {
        guard let interface, interface.isUp else { return .offline }
        if let address = interface.primaryAddress {
            if address.isSelfAssigned { return .selfAssigned }
            return interface.name == primaryName || interface.gateway != nil ? .connected : .localOnly
        }
        return interface.ipv6.isEmpty ? .offline : .ipv6Only
    }
}

public enum MenuDisplay: String, CaseIterable, Sendable {
    case address, interface, prefixed

    public func title(for interface: NetworkInterface?, family: AddressFamily = .ipv4) -> String {
        guard let interface, let address = family.address(for: interface) else { return family.emptyTitle }
        switch self {
        case .address: return address
        case .interface: return "\(address) · \(interface.name)"
        case .prefixed: return "\(family == .ipv4 ? "IP" : "IPv6"): \(address)"
        }
    }
}
