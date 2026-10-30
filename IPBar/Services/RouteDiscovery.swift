import Foundation
import Darwin

public struct IPv4Route: Equatable, Sendable {
    public var interfaceName: String
    public var destination: String
    public var mask: String
    public var gateway: String?
    public var scoped: Bool

    public init(interfaceName: String, destination: String, mask: String, gateway: String? = nil, scoped: Bool = false) {
        self.interfaceName = interfaceName
        self.destination = destination
        self.mask = mask
        self.gateway = gateway
        self.scoped = scoped
    }

    public var isDefault: Bool { destination == "0.0.0.0" && mask == "0.0.0.0" }
}

public enum RouteDiscovery {
    public static func primaryRoute(in routes: [IPv4Route], primaryHint: String?) -> IPv4Route? {
        let unscoped = routes.filter { !$0.scoped }
        // VPN может заменить default двумя более специфичными маршрутами /1.
        if let lower = unscoped.first(where: { route in
            route.destination == "0.0.0.0" && route.mask == "128.0.0.0"
                && unscoped.contains { $0.interfaceName == route.interfaceName
                    && $0.destination == "128.0.0.0" && $0.mask == "128.0.0.0" }
        }) { return lower }
        let defaults = unscoped.filter(\.isDefault)
        return defaults.first { $0.interfaceName == primaryHint } ?? defaults.first
    }

    public static func read() throws -> [IPv4Route] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_DUMP2, 0]
        // Размер таблицы может измениться между двумя sysctl; повтор ограничен.
        for _ in 0..<3 {
            var size = 0
            guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            guard size > 0, size < 32 * 1024 * 1024 else { return [] }
            var data = Data(count: size)
            let result = data.withUnsafeMutableBytes { bytes in
                sysctl(&mib, u_int(mib.count), bytes.baseAddress, &size, nil, 0)
            }
            if result == 0 { return parse(data.prefix(size)) }
            if errno != ENOMEM { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        }
        throw POSIXError(.ENOMEM)
    }

    static func parse(_ data: Data) -> [IPv4Route] {
        data.withUnsafeBytes { bytes -> [IPv4Route] in
            var routes: [IPv4Route] = []
            var offset = 0
            let headerSize = MemoryLayout<rt_msghdr2>.size
            while offset + headerSize <= bytes.count {
                let header = bytes.loadUnaligned(fromByteOffset: offset, as: rt_msghdr2.self)
                let length = Int(header.rtm_msglen)
                guard length >= headerSize, offset + length <= bytes.count else { break }
                defer { offset += length }
                guard header.rtm_version == RTM_VERSION, header.rtm_flags & RTF_UP != 0,
                      header.rtm_flags & (RTF_REJECT | RTF_BLACKHOLE) == 0 else { continue }
                var addresses: [Int: [UInt8]] = [:]
                var position = offset + headerSize
                var valid = true
                for index in 0..<Int(RTAX_MAX) where header.rtm_addrs & (1 << index) != 0 {
                    guard position + 2 <= offset + length else { valid = false; break }
                    let addressLength = Int(bytes[position])
                    let stride = addressLength == 0 ? 4 : (addressLength + 3) & ~3
                    guard position + stride <= offset + length else { valid = false; break }
                    addresses[index] = Array(bytes[position..<(position + addressLength)])
                    position += stride
                }
                guard valid, let destination = ipv4(addresses[Int(RTAX_DST)], requireFamily: true) else { continue }
                let mask = ipv4(addresses[Int(RTAX_NETMASK)], requireFamily: false) ?? "0.0.0.0"
                var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                guard if_indextoname(UInt32(header.rtm_index), &name) != nil else { continue }
                routes.append(IPv4Route(interfaceName: String(cString: name), destination: destination,
                                        mask: mask, gateway: ipv4(addresses[Int(RTAX_GATEWAY)], requireFamily: true),
                                        scoped: header.rtm_flags & RTF_IFSCOPE != 0))
            }
            return routes
        }
    }

    private static func ipv4(_ bytes: [UInt8]?, requireFamily: Bool) -> String? {
        guard let bytes else { return nil }
        if requireFamily { guard bytes.count >= 8, bytes[1] == UInt8(AF_INET) else { return nil } }
        return (4..<8).map { String($0 < bytes.count ? bytes[$0] : 0) }.joined(separator: ".")
    }
}
