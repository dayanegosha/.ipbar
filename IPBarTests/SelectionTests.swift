import XCTest
@testable import IPBarCore

final class SelectionTests: XCTestCase {
    private let wifi = NetworkInterface(name: "en7", kind: .wifi, ipv4: [IPv4Address("192.168.4.8")])
    private let ethernet = NetworkInterface(name: "en12", kind: .ethernet, ipv4: [IPv4Address("10.0.0.8")])

    func testAutomaticFollowsPrimaryRatherThanInterfaceName() {
        let snapshot = NetworkSnapshot(interfaces: [wifi, ethernet], primaryName: "en12")
        XCTAssertEqual(snapshot.selected(.automatic)?.name, "en12")
        XCTAssertEqual(snapshot.selected(.kind(.wifi))?.name, "en7")
    }

    func testDisconnectedManualSelectionDoesNotFallBack() {
        let snapshot = NetworkSnapshot(interfaces: [wifi], primaryName: "en7")
        XCTAssertNil(snapshot.selected(.named("en12")))
        XCTAssertEqual(MenuDisplay.address.title(for: snapshot.selected(.named("en12"))), "No IP")
    }

    func testIPv6PrimaryDoesNotBorrowAnotherInterfacesIPv4() {
        let vpn = NetworkInterface(name: "utun9", kind: .vpn, ipv6: ["fd00::1"])
        let snapshot = NetworkSnapshot(interfaces: [wifi, vpn], primaryName: "utun9")
        XCTAssertEqual(snapshot.status(for: snapshot.selected(.automatic)), .ipv6Only)
        XCTAssertEqual(MenuDisplay.address.title(for: snapshot.selected(.automatic)), "No IP")
    }

    func testNoConnectionAndDownInterface() {
        XCTAssertNil(NetworkSnapshot().selected(.automatic))
        var down = wifi
        down.isUp = false
        XCTAssertEqual(MenuDisplay.address.title(for: down), "No IP")
        XCTAssertEqual(NetworkSnapshot().status(for: down), .offline)
    }

    func testSelfAssignedAndPreferredNonLinkLocalAddress() {
        var interface = wifi
        interface.ipv4 = [IPv4Address("169.254.1.2")]
        XCTAssertEqual(NetworkSnapshot().status(for: interface), .selfAssigned)
        interface.ipv4.append(IPv4Address("192.168.4.9"))
        XCTAssertEqual(interface.primaryAddress?.address, "192.168.4.9")
    }

    func testDisplayModesAndSelectionRoundTrip() {
        XCTAssertEqual(MenuDisplay.interface.title(for: wifi), "192.168.4.8 · en7")
        XCTAssertEqual(MenuDisplay.prefixed.title(for: wifi), "IP: 192.168.4.8")
        for selection in [InterfaceSelection.automatic, .kind(.vpn), .named("en17")] {
            XCTAssertEqual(InterfaceSelection(rawValue: selection.rawValue), selection)
        }
    }
}
