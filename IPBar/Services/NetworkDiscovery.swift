import Foundation
import SystemConfiguration
import Darwin

struct InterfaceMetadata {
    var displayName: String
    var kind: InterfaceKind
    var serviceIDs: [String]
}

public enum NetworkDiscovery {
    static func metadata(store: SCDynamicStore?) -> [String: InterfaceMetadata] {
        guard let preferences = SCPreferencesCreate(nil, "IP Bar" as CFString, nil),
              let services = SCNetworkServiceCopyAll(preferences) as? [SCNetworkService] else { return [:] }
        var result: [String: InterfaceMetadata] = [:]
        for service in services where SCNetworkServiceGetEnabled(service) {
            guard let interface = SCNetworkServiceGetInterface(service) else { continue }
            guard let serviceID = SCNetworkServiceGetServiceID(service) else { continue }
            let id = serviceID as String
            let state = dictionary(store, "State:/Network/Service/\(id)/IPv4")
            let state6 = dictionary(store, "State:/Network/Service/\(id)/IPv6")
            let name = (state["InterfaceName"] as? String) ?? (state6["InterfaceName"] as? String)
                ?? (SCNetworkInterfaceGetBSDName(interface) as String?)
            guard let name else { continue }
            let type = SCNetworkInterfaceGetInterfaceType(interface).map { $0 as String } ?? ""
            let kind: InterfaceKind
            if type == kSCNetworkInterfaceTypeIEEE80211 as String {
                kind = .wifi
            } else if type == kSCNetworkInterfaceTypeEthernet as String {
                kind = .ethernet
            } else if type == kSCNetworkInterfaceTypePPP as String || type == kSCNetworkInterfaceTypeIPSec as String {
                kind = .vpn
            } else {
                kind = .other
            }
            if result[name] != nil {
                result[name]?.serviceIDs.append(id)
            } else {
                result[name] = InterfaceMetadata(displayName: SCNetworkServiceGetName(service) as String? ?? name,
                                                 kind: kind, serviceIDs: [id])
            }
        }
        return result
    }

    static func dictionary(_ store: SCDynamicStore?, _ key: String) -> [String: Any] {
        guard let store else { return [:] }
        return SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any] ?? [:]
    }

    static func interfaces(metadata: [String: InterfaceMetadata], store: SCDynamicStore?) throws -> [NetworkInterface] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { if let head { freeifaddrs(head) } }
        var interfaces: [String: NetworkInterface] = [:]
        var cursor = head
        while let pointer = cursor {
            let entry = pointer.pointee
            cursor = entry.ifa_next
            guard entry.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }
            let name = String(cString: entry.ifa_name)
            let fallback = fallbackKind(name: name, flags: entry.ifa_flags)
            let kind = fallback == .vpn ? .vpn : (metadata[name]?.kind ?? fallback)
            let link = dictionary(store, "State:/Network/Interface/\(name)/Link")
            let up = entry.ifa_flags & UInt32(IFF_UP) != 0 && (link["Active"] as? Bool != false)
            var interface = interfaces[name] ?? NetworkInterface(name: name, displayName: metadata[name]?.displayName,
                                                                  kind: kind, isUp: up)
            guard let address = entry.ifa_addr else { interfaces[name] = interface; continue }
            switch Int32(address.pointee.sa_family) {
            case AF_INET:
                if let ip = numericAddress(address), ip != "0.0.0.0", !ip.hasPrefix("127.") {
                    let mask = entry.ifa_netmask.flatMap { numericAddress($0) }
                    let value = IPv4Address(ip, mask: mask)
                    if !interface.ipv4.contains(value) { interface.ipv4.append(value) }
                }
            case AF_INET6:
                if let ip = numericAddress(address), ip != "::", ip != "::1", !interface.ipv6.contains(ip) {
                    interface.ipv6.append(ip)
                }
            case AF_LINK:
                let bytes = UnsafeRawPointer(address).assumingMemoryBound(to: UInt8.self)
                let length = Int(bytes[0])
                if length >= 8 {
                    let start = 8 + Int(bytes[5])
                    let count = Int(bytes[6])
                    if count == 6, start + count <= length {
                        let macBytes = Array(UnsafeBufferPointer(start: bytes + start, count: count))
                        if macBytes.contains(where: { $0 != 0 }) {
                            interface.mac = macBytes.map { String(format: "%02X", $0) }.joined(separator: ":")
                        }
                    }
                }
            default: break
            }
            interfaces[name] = interface
        }
        return interfaces.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func fallbackKind(name: String, flags: UInt32) -> InterfaceKind {
        if flags & UInt32(IFF_POINTOPOINT) != 0 || name.hasPrefix("utun") || name.hasPrefix("ipsec") { return .vpn }
        return .other
    }

    private static func numericAddress(_ address: UnsafePointer<sockaddr>) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(address, socklen_t(address.pointee.sa_len), &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
        return String(cString: buffer)
    }
}
