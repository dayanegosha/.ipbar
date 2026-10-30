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

private final class SlowRefreshReader: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    let release = DispatchSemaphore(value: 0)

    func read() -> NetworkSnapshot {
        lock.lock()
        count += 1
        let call = count
        lock.unlock()
        if call > 1 { _ = release.wait(timeout: .now() + 5) }
        return NetworkSnapshot(interfaces: [NetworkInterface(name: "en5", ipv4: [IPv4Address("10.0.0.5")])], primaryName: "en5")
    }
}

final class MonitorTests: XCTestCase {
    @MainActor
    func testRepeatedEventsCannotExtendStaleAddressDeadlineForever() async {
        let reader = SlowRefreshReader()
        let monitor = NetworkMonitor(readSnapshot: { reader.read() }, observesSystem: false)
        monitor.configure(polling: false, interval: 30)
        let initial = expectation(description: "Initial address")
        let expired = expectation(description: "Timed-out address removed")
        let subscription = monitor.$snapshot.sink { snapshot in
            if snapshot.selected(.automatic)?.primaryAddress != nil { initial.fulfill() }
            if !snapshot.warnings.isEmpty { expired.fulfill() }
        }
        defer { monitor.stop(); reader.release.signal(); subscription.cancel() }
        monitor.start()
        await fulfillment(of: [initial], timeout: 2)
        for _ in 0..<10 {
            monitor.networkChanged()
            try? await Task.sleep(nanoseconds: 160_000_000)
        }
        await fulfillment(of: [expired], timeout: 1.5)
        XCTAssertTrue(monitor.snapshot.interfaces.isEmpty)
    }

    @MainActor
    func testNetworkRefreshKeepsAddressUntilNewSnapshotIsReady() async {
        let reader = ControlledReader()
        let monitor = NetworkMonitor(readSnapshot: { reader.read() }, observesSystem: false)
        monitor.configure(polling: false, interval: 30)
        let initial = expectation(description: "Initial address")
        let changed = expectation(description: "Replacement address")
        var hasAddress = false
        let subscription = monitor.$snapshot.sink { snapshot in
            let address = snapshot.selected(.automatic)?.primaryAddress?.address
            if hasAddress { XCTAssertNotNil(address, "Refresh must not flash No IP between valid snapshots") }
            if address == "192.168.1.2" { hasAddress = true; initial.fulfill() }
            if address == "10.0.0.9" { changed.fulfill() }
        }
        defer { monitor.stop(); subscription.cancel() }
        reader.release.signal()
        monitor.start()
        await fulfillment(of: [initial], timeout: 2)
        monitor.networkChanged()
        XCTAssertEqual(monitor.snapshot.selected(.automatic)?.primaryAddress?.address, "192.168.1.2")
        await fulfillment(of: [changed], timeout: 2)
        XCTAssertEqual(monitor.snapshot.selected(.automatic)?.primaryAddress?.address, "10.0.0.9")
    }

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
