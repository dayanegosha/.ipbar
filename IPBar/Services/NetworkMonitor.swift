import AppKit
import Combine
import Network
import SystemConfiguration
import IPBarCore

private final class NetworkEventRelay: @unchecked Sendable {
    let handler: @Sendable () -> Void
    init(handler: @escaping @Sendable () -> Void) { self.handler = handler }
}

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var snapshot = NetworkSnapshot()
    @Published private(set) var isRefreshing = false
    @Published private(set) var isChecking = true
    @Published private(set) var monitoringWarning: String?
    private let provider = NetworkInfoProvider()
    private let queue = DispatchQueue(label: "com.georgezhurik.ipbar.discovery", qos: .utility)
    private let eventQueue = DispatchQueue(label: "com.georgezhurik.ipbar.events", qos: .utility)
    private var store: SCDynamicStore?
    private var pathMonitor: NWPathMonitor?
    private var timer: Timer?
    private var debounce: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var generation = 0
    private var inFlight = false
    private var pending = false
    private var running = false
    private var polling = true
    private var interval = 5

    func start() {
        guard !running else { return }
        running = true
        let relay = NetworkEventRelay { [weak self] in
            Task { @MainActor [weak self] in self?.networkChanged() }
        }
        var context = SCDynamicStoreContext(version: 0, info: Unmanaged.passUnretained(relay).toOpaque(), retain: { pointer in
            let relay = Unmanaged<NetworkEventRelay>.fromOpaque(pointer).takeUnretainedValue()
            return UnsafeRawPointer(Unmanaged.passRetained(relay).toOpaque())
        }, release: { pointer in
            Unmanaged<NetworkEventRelay>.fromOpaque(pointer).release()
        }, copyDescription: nil)
        store = SCDynamicStoreCreate(nil, "IP Bar events" as CFString, { _, _, context in
            guard let context else { return }
            Unmanaged<NetworkEventRelay>.fromOpaque(context).takeUnretainedValue().handler()
        }, &context)
        if let store {
            let patterns = ["State:/Network/Global/.*", "State:/Network/Interface/.*/.*", "State:/Network/Service/.*/.*", "Setup:/Network/.*"]
            if !SCDynamicStoreSetNotificationKeys(store, nil, patterns as CFArray)
                || !SCDynamicStoreSetDispatchQueue(store, eventQueue) {
                monitoringWarning = "Some network notifications are unavailable. Keep automatic refresh enabled."
            }
        } else {
            monitoringWarning = "Network notifications are unavailable. Keep automatic refresh enabled."
        }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor [weak self] in self?.networkChanged() }
        }
        monitor.start(queue: eventQueue)
        pathMonitor = monitor
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.timer?.invalidate()
                self?.timer = nil
                self?.invalidate()
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.configureTimer(); self?.networkChanged() }
        })
        configureTimer()
        refresh()
    }

    func configure(polling: Bool, interval: Int) {
        guard self.polling != polling || self.interval != interval else { return }
        self.polling = polling
        self.interval = interval
        configureTimer()
    }

    private func configureTimer() {
        timer?.invalidate()
        timer = nil
        guard running, polling else { return }
        let timer = Timer(timeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        timer.tolerance = min(1, TimeInterval(interval) * 0.15)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func invalidate() {
        generation += 1
        snapshot = NetworkSnapshot()
        isChecking = true
    }

    private func networkChanged() {
        guard running else { return }
        invalidate()
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    func refresh() {
        guard running else { return }
        if inFlight { pending = true; return }
        inFlight = true
        isRefreshing = true
        let request = generation
        let provider = provider
        queue.async { [weak self] in
            let result = provider.snapshot()
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.inFlight = false
                guard self.running else { return }
                if request == self.generation {
                    self.snapshot = result
                    self.isChecking = false
                }
                self.isRefreshing = false
                if self.pending {
                    self.pending = false
                    self.refresh()
                }
            }
        }
    }

    func stop() {
        running = false
        generation += 1
        pending = false
        timer?.invalidate()
        timer = nil
        debounce?.cancel()
        debounce = nil
        pathMonitor?.cancel()
        pathMonitor = nil
        if let store { SCDynamicStoreSetDispatchQueue(store, nil) }
        store = nil
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
    }
}
