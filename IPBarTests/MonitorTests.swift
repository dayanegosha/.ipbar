import XCTest
import Combine
import IPBarCore

private final class ControlledReader: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    let started = XCTestExpectation(description: "First read started")
    let nextRead = XCTestExpectation(description: "Next read started")
    let release = DispatchSemaphore(value: 0)

    func read() -> NetworkSnapshot {
        lock.lock()
        count += 1
        let call = count
        lock.unlock()
        if call == 1 {
            started.fulfill()
            _ = release.wait(timeout: .now() + 3)
        } else { nextRead.fulfill() }
        let ip = call == 1 ? "192.168.1.2" : "10.0.0.9"
        return NetworkSnapshot(interfaces: [NetworkInterface(name: "en5", kind: .wifi, ipv4: [IPv4Address(ip)])], primaryName: "en5")
    }
}

final class MonitorTests: XCTestCase {
    @MainActor
    func testNetworkChangeRejectsInFlightOldAddress() async {
        let reader = ControlledReader()
        let monitor = NetworkMonitor(readSnapshot: { reader.read() }, observesSystem: false)
        monitor.configure(polling: false, interval: 5)
        let fresh = expectation(description: "New address published")
        let subscription = monitor.$snapshot.sink { snapshot in
            let address = snapshot.selected(.automatic)?.primaryAddress?.address
            XCTAssertNotEqual(address, "192.168.1.2", "An old result must not undo invalidation")
            if address == "10.0.0.9" { fresh.fulfill() }
        }
        defer { monitor.stop(); reader.release.signal(); subscription.cancel() }
        monitor.start()
        await fulfillment(of: [reader.started], timeout: 2)
        monitor.networkChanged()
        XCTAssertTrue(monitor.isChecking)
        XCTAssertTrue(monitor.snapshot.interfaces.isEmpty)
        reader.release.signal()
        await fulfillment(of: [fresh], timeout: 2)
        XCTAssertEqual(monitor.snapshot.selected(.automatic)?.primaryAddress?.address, "10.0.0.9")
        XCTAssertFalse(monitor.isChecking)
    }

    @MainActor
    func testStopDiscardsPendingRead() async {
        let reader = ControlledReader()
        let monitor = NetworkMonitor(readSnapshot: { reader.read() }, observesSystem: false)
        monitor.configure(polling: false, interval: 5)
        let published = expectation(description: "No result after stop")
        published.isInverted = true
        let subscription = monitor.$snapshot.dropFirst().sink { _ in published.fulfill() }
        defer { subscription.cancel() }
        monitor.start()
        await fulfillment(of: [reader.started], timeout: 2)
        monitor.stop()
        reader.release.signal()
        await fulfillment(of: [published], timeout: 0.2)
        XCTAssertTrue(monitor.snapshot.interfaces.isEmpty)
    }

    @MainActor
    func testEventsStillRefreshWhenPeriodicPollingIsDisabled() async {
        let reader = ControlledReader()
        let monitor = NetworkMonitor(readSnapshot: { reader.read() }, observesSystem: false)
        monitor.configure(polling: false, interval: 30)
        let initial = expectation(description: "Initial snapshot")
        let changed = expectation(description: "Event snapshot")
        let subscription = monitor.$snapshot.sink { snapshot in
            switch snapshot.selected(.automatic)?.primaryAddress?.address {
            case "192.168.1.2": initial.fulfill()
            case "10.0.0.9": changed.fulfill()
            default: break
            }
        }
        defer { monitor.stop(); subscription.cancel() }
        reader.release.signal()
        monitor.start()
        await fulfillment(of: [initial], timeout: 2)
        monitor.networkChanged()
        XCTAssertTrue(monitor.isChecking)
        await fulfillment(of: [changed], timeout: 2)
        XCTAssertFalse(monitor.isChecking)
    }
}
