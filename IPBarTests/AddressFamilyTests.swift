import XCTest
@testable import IPBarCore

final class AddressFamilyTests: XCTestCase {
    func testGlobalIPv6IsPreferredOverLocalAddresses() {
        let interface = NetworkInterface(name: "en8", ipv6: ["fe80::1%en8", "fd00::5", "2001:db8::7"])
        XCTAssertEqual(interface.primaryIPv6, "2001:db8::7")
    }

    func testLinkLocalIPv6KeepsItsInterfaceScope() {
        let interface = NetworkInterface(name: "en8", ipv6: ["fe80::1%en8"])
        XCTAssertEqual(MenuDisplay.interface.title(for: interface, family: .ipv6), "fe80::1%en8 · en8")
    }

    func testMissingIPv6DoesNotSilentlyDisplayIPv4() {
        let interface = NetworkInterface(name: "en8", ipv4: [IPv4Address("192.168.1.8")])
        XCTAssertEqual(MenuDisplay.address.title(for: interface, family: .ipv6), "No IPv6")
        XCTAssertEqual(MenuDisplay.address.title(for: interface), "192.168.1.8")
    }

    func testIPv6AutomaticSelectionUsesItsOwnPrimaryInterface() {
        let wifi = NetworkInterface(name: "en8", kind: .wifi, ipv4: [IPv4Address("192.168.1.8")], ipv6: ["2001:db8::8"])
        let tunnel = NetworkInterface(name: "utun7", kind: .vpn, ipv4: [IPv4Address("10.8.0.1")], ipv6: ["fd00::1"])
        let snapshot = NetworkSnapshot(interfaces: [wifi, tunnel], primaryName: "utun7", primaryIPv6Name: "en8")
        XCTAssertEqual(snapshot.selected(.automatic, family: .ipv6)?.name, "en8")
        XCTAssertEqual(snapshot.selected(.automatic)?.name, "utun7")
        XCTAssertEqual(snapshot.selected(.named("utun7"), family: .ipv6)?.name, "utun7")
    }
}
