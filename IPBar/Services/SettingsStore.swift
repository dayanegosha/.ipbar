import Foundation
import Combine
import IPBarCore

@MainActor
final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    var onChange: (() -> Void)?
    @Published var addressFamily: AddressFamily { didSet { defaults.set(addressFamily.rawValue, forKey: "addressFamily"); onChange?() } }
    @Published var onboardingComplete: Bool { didSet { defaults.set(onboardingComplete, forKey: "onboardingComplete") } }
    var didAttemptDefaultLogin: Bool {
        get { defaults.bool(forKey: "didAttemptDefaultLogin") }
        set { defaults.set(newValue, forKey: "didAttemptDefaultLogin") }
    }
    @Published var display: MenuDisplay { didSet { defaults.set(display.rawValue, forKey: "menuDisplay"); onChange?() } }
    @Published var selection: String { didSet { defaults.set(selection, forKey: "interfaceSelection"); onChange?() } }
    @Published var showIPv6: Bool { didSet { defaults.set(showIPv6, forKey: "showIPv6"); onChange?() } }
    @Published var automaticRefresh: Bool { didSet { defaults.set(automaticRefresh, forKey: "automaticRefresh"); onChange?() } }
    @Published var interval: Int { didSet { defaults.set(interval, forKey: "refreshInterval"); onChange?() } }

    static let intervals = [1, 3, 5, 10, 30]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        addressFamily = AddressFamily(rawValue: defaults.string(forKey: "addressFamily") ?? "") ?? .ipv4
        onboardingComplete = defaults.bool(forKey: "onboardingComplete")
        display = MenuDisplay(rawValue: defaults.string(forKey: "menuDisplay") ?? "") ?? .address
        selection = defaults.string(forKey: "interfaceSelection") ?? "automatic"
        showIPv6 = defaults.object(forKey: "showIPv6") as? Bool ?? true
        automaticRefresh = defaults.object(forKey: "automaticRefresh") as? Bool ?? true
        let savedInterval = defaults.integer(forKey: "refreshInterval")
        interval = Self.intervals.contains(savedInterval) ? savedInterval : 5
    }
}
