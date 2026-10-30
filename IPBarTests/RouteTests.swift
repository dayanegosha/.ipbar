import XCTest
import Darwin
@testable import IPBarCore

final class RouteTests: XCTestCase {
    func testUnscopedDefaultWinsOverScopedWiFi() {
        let scoped = IPv4Route(interfaceName: "en4", destination: "0.0.0.0", mask: "0.0.0.0", scoped: true)
        let primary = IPv4Route(interfaceName: "en8", destination: "0.0.0.0", mask: "0.0.0.0")
        XCTAssertEqual(RouteDiscovery.primaryRoute(in: [scoped, primary], primaryHint: "en4"), primary)
    }

    func testVPNDefaultAndSplitDefault() {
        let physical = IPv4Route(interfaceName: "en8", destination: "0.0.0.0", mask: "0.0.0.0")
        let lower = IPv4Route(interfaceName: "utun7", destination: "0.0.0.0", mask: "128.0.0.0")
        let upper = IPv4Route(interfaceName: "utun7", destination: "128.0.0.0", mask: "128.0.0.0")
        XCTAssertEqual(RouteDiscovery.primaryRoute(in: [physical, lower, upper], primaryHint: "en8"), lower)
        XCTAssertEqual(RouteDiscovery.primaryRoute(in: [physical, lower], primaryHint: "en8"), physical)
    }

    func testSplitTunnelDoesNotReplaceDefault() {
        let specific = IPv4Route(interfaceName: "utun1", destination: "10.0.0.0", mask: "255.0.0.0")
        let physical = IPv4Route(interfaceName: "en9", destination: "0.0.0.0", mask: "0.0.0.0")
        XCTAssertEqual(RouteDiscovery.primaryRoute(in: [specific, physical], primaryHint: nil), physical)
    }

    func testRouteParserRejectsTruncatedAndMalformedData() {
        XCTAssertTrue(RouteDiscovery.parse(Data([0, 1, 2])).isEmpty)
        var header = rt_msghdr2()
        header.rtm_msglen = 1
        XCTAssertTrue(RouteDiscovery.parse(withUnsafeBytes(of: &header) { Data($0) }).isEmpty)
        header.rtm_msglen = UInt16(MemoryLayout<rt_msghdr2>.size + 4)
        header.rtm_version = UInt8(RTM_VERSION)
        header.rtm_flags = RTF_UP
        header.rtm_addrs = 1 << RTAX_DST
        var data = withUnsafeBytes(of: &header) { Data($0) }
        data.append(contentsOf: [255, 2, 0, 0])
        XCTAssertTrue(RouteDiscovery.parse(data).isEmpty)
    }

    func testParsesCompactNetmaskAndIPv4Gateway() {
        var header = rt_msghdr2()
        header.rtm_msglen = UInt16(MemoryLayout<rt_msghdr2>.size + 40)
        header.rtm_version = UInt8(RTM_VERSION)
        header.rtm_flags = RTF_UP | RTF_GATEWAY
        header.rtm_index = UInt16(if_nametoindex("lo0"))
        header.rtm_addrs = (1 << RTAX_DST) | (1 << RTAX_GATEWAY) | (1 << RTAX_NETMASK)
        var data = withUnsafeBytes(of: &header) { Data($0) }
        data.append(contentsOf: [16, UInt8(AF_INET), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        data.append(contentsOf: [16, UInt8(AF_INET), 0, 0, 192, 168, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0])
        data.append(contentsOf: [8, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(RouteDiscovery.parse(data), [IPv4Route(interfaceName: "lo0", destination: "0.0.0.0", mask: "0.0.0.0", gateway: "192.168.1.1")])
    }

    func testAddressChangesAndDisconnectReplaceSnapshot() {
        let before = NetworkSnapshot(interfaces: [NetworkInterface(name: "en3", ipv4: [IPv4Address("10.1.0.2")])], primaryName: "en3")
        let after = NetworkSnapshot(interfaces: [NetworkInterface(name: "en3", ipv4: [IPv4Address("10.1.0.9")])], primaryName: "en3")
        XCTAssertNotEqual(before.selected(.automatic)?.primaryAddress, after.selected(.automatic)?.primaryAddress)
        XCTAssertEqual(MenuDisplay.address.title(for: NetworkSnapshot().selected(.automatic)), "No IP")
    }
}
