import XCTest
import IPBarCore

final class SettingsTests: XCTestCase {
    @MainActor
    func testSettingsPersistInAnIsolatedDefaultsDomain() {
        let name = "com.georgezhurik.ipbar.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.selection, "automatic")
        XCTAssertEqual(settings.interval, 5)
        settings.addressFamily = .ipv6
        settings.onboardingComplete = true
        settings.didAttemptDefaultLogin = true
        settings.display = .interface
        settings.selection = "interface:en19"
        settings.showIPv6 = false
        settings.interval = 30
        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.addressFamily, .ipv6)
        XCTAssertTrue(restored.onboardingComplete)
        XCTAssertTrue(restored.didAttemptDefaultLogin)
        XCTAssertEqual(restored.display, .interface)
        XCTAssertEqual(restored.selection, "interface:en19")
        XCTAssertFalse(restored.showIPv6)
        XCTAssertEqual(restored.interval, 30)
    }

    @MainActor
    func testInvalidStoredIntervalUsesDefault() {
        let name = "com.georgezhurik.ipbar.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(-1, forKey: "refreshInterval")
        defaults.set("missing", forKey: "menuDisplay")
        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.interval, 5)
        XCTAssertEqual(settings.display, .address)
    }
}
