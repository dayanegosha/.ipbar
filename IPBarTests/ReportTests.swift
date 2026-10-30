import XCTest
@testable import IPBarCore

final class ReportTests: XCTestCase {
    func testCopyAllIncludesAddressesWithoutInventingMissingValues() {
        let interface = NetworkInterface(name: "utun7", kind: .vpn,
            ipv4: [IPv4Address("10.8.0.2", mask: "255.255.255.0")], ipv6: ["fd00::2"], dns: ["10.8.0.1"])
        let snapshot = NetworkSnapshot(interfaces: [interface], primaryName: "utun7")
        let report = NetworkReport.text(snapshot: snapshot, selection: .automatic, includeIPv6: true)
        XCTAssertTrue(report.contains("IPv4: 10.8.0.2"))
        XCTAssertTrue(report.contains("Subnet mask: 255.255.255.0"))
        XCTAssertTrue(report.contains("DNS: 10.8.0.1"))
        XCTAssertTrue(report.contains("MAC: Unavailable"))
        XCTAssertTrue(report.contains("IPv6: fd00::2"))
        XCTAssertFalse(NetworkReport.text(snapshot: snapshot, selection: .automatic, includeIPv6: false).contains("fd00::2"))
    }

    func testOfflineReportNeverReusesPreviousData() {
        XCTAssertEqual(NetworkReport.text(snapshot: NetworkSnapshot(), selection: .automatic, includeIPv6: true),
                       "IP Bar\nStatus: Offline\nIPv4: No IP")
    }

    func testEthernetDisconnectFallsBackToCurrentWiFiSnapshot() {
        let ethernet = NetworkInterface(name: "en12", kind: .ethernet, ipv4: [IPv4Address("10.0.0.10")])
        let wifi = NetworkInterface(name: "en6", kind: .wifi, ipv4: [IPv4Address("192.168.5.20")])
        var snapshot = NetworkSnapshot(interfaces: [ethernet, wifi], primaryName: "en12")
        XCTAssertEqual(MenuDisplay.address.title(for: snapshot.selected(.automatic)), "10.0.0.10")
        snapshot = NetworkSnapshot(interfaces: [wifi], primaryName: "en6")
        XCTAssertEqual(MenuDisplay.address.title(for: snapshot.selected(.automatic)), "192.168.5.20")
        XCTAssertNil(snapshot.selected(.kind(.ethernet)))
    }
}
