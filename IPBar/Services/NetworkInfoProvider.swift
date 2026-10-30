import Foundation
import SystemConfiguration
import CoreWLAN

public final class NetworkInfoProvider: @unchecked Sendable {
    // Вызывается последовательно на очереди монитора, не на MainActor.
    public init() {}

    public func snapshot() -> NetworkSnapshot {
        let store = SCDynamicStoreCreate(nil, "IP Bar snapshot" as CFString, nil, nil)
        var warnings: [String] = []
        if store == nil { warnings.append("SystemConfiguration is unavailable. Some details may be missing.") }
        let metadata = NetworkDiscovery.metadata(store: store)
        let global4 = NetworkDiscovery.dictionary(store, "State:/Network/Global/IPv4")
        let global6 = NetworkDiscovery.dictionary(store, "State:/Network/Global/IPv6")
        let hint = global4["PrimaryInterface"] as? String
        let routes: [IPv4Route]
        do { routes = try RouteDiscovery.read() }
        catch { routes = []; warnings.append("Routing table is unavailable; using the system primary interface.") }
        let primaryRoute = RouteDiscovery.primaryRoute(in: routes, primaryHint: hint)
        let primaryName = primaryRoute?.interfaceName ?? hint ?? (global6["PrimaryInterface"] as? String)
        let globalDNS = NetworkDiscovery.dictionary(store, "State:/Network/Global/DNS")["ServerAddresses"] as? [String] ?? []
        var interfaces: [NetworkInterface]
        do { interfaces = try NetworkDiscovery.interfaces(metadata: metadata, store: store) }
        catch {
            return NetworkSnapshot(warnings: ["Could not read network interfaces: \(error.localizedDescription)"])
        }
        for index in interfaces.indices {
            let name = interfaces[index].name
            let services = metadata[name]?.serviceIDs ?? []
            var dns: [String] = []
            var router: String?
            for service in services {
                let state4 = NetworkDiscovery.dictionary(store, "State:/Network/Service/\(service)/IPv4")
                if router == nil { router = state4["Router"] as? String }
                let serviceDNS = NetworkDiscovery.dictionary(store, "State:/Network/Service/\(service)/DNS")
                dns += serviceDNS["ServerAddresses"] as? [String] ?? []
                let stateAddresses = state4["Addresses"] as? [String] ?? []
                // Системный порядок адресов важен, когда у интерфейса несколько IPv4.
                interfaces[index].ipv4.sort {
                    (stateAddresses.firstIndex(of: $0.address) ?? Int.max) < (stateAddresses.firstIndex(of: $1.address) ?? Int.max)
                }
            }
            interfaces[index].gateway = routes.first { $0.interfaceName == name && $0.isDefault }?.gateway ?? router
            if name == primaryName {
                interfaces[index].gateway = primaryRoute?.gateway ?? interfaces[index].gateway
                if dns.isEmpty {
                    dns = globalDNS
                    interfaces[index].dnsScope = "System default"
                }
                if interfaces[index].gateway == nil, name == hint { interfaces[index].gateway = global4["Router"] as? String }
            }
            interfaces[index].dns = dns.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
            if interfaces[index].kind == .wifi, interfaces[index].isUp {
                // CoreWLAN может вернуть nil без разрешения Location Services; запросов разрешения нет.
                interfaces[index].ssid = CWWiFiClient.shared().interface(withName: name)?.ssid()
            }
            if !interfaces[index].isUp {
                interfaces[index].ipv4 = []
                interfaces[index].ipv6 = []
                interfaces[index].gateway = nil
                interfaces[index].dns = []
                interfaces[index].ssid = nil
            }
        }
        let description: String
        if let route = primaryRoute {
            description = route.isDefault ? "Default IPv4 route" : "Full-tunnel IPv4 routes (/1 + /1)"
        } else if primaryName != nil {
            description = "System primary interface"
        } else {
            description = "No default route"
        }
        return NetworkSnapshot(interfaces: interfaces, primaryName: primaryName,
                               routeDescription: description, warnings: warnings)
    }
}
