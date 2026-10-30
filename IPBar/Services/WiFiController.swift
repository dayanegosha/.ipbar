import Foundation
import Combine
import CoreWLAN

private struct WiFiState: Sendable {
    var name: String?
    var poweredOn: Bool?
}

@MainActor
final class WiFiController: ObservableObject {
    @Published private(set) var poweredOn: Bool?
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?
    private let queue = DispatchQueue(label: "com.georgezhurik.ipbar.wifi", qos: .utility)
    private var isReading = false
    private var interfaceName: String?
    var didChange: (() -> Void)?

    func refresh() {
        guard !isReading, !isBusy else { return }
        isReading = true
        queue.async { [weak self] in
            let interface = CWWiFiClient.shared().interface()
            let state = WiFiState(name: interface?.interfaceName, poweredOn: interface?.powerOn())
            Task { @MainActor [weak self] in
                self?.interfaceName = state.name
                self?.poweredOn = state.poweredOn
                self?.isReading = false
            }
        }
    }

    func setPower(_ enabled: Bool) {
        guard !isBusy, let name = interfaceName else { return }
        isBusy = true
        errorMessage = nil
        queue.async { [weak self] in
            let interface = CWWiFiClient.shared().interface(withName: name)
            let errorMessage: String?
            do {
                guard let interface else { throw CocoaError(.featureUnsupported) }
                try interface.setPower(enabled)
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
            let poweredOn = interface?.powerOn()
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.poweredOn = poweredOn
                self.errorMessage = errorMessage
                self.isBusy = false
                self.didChange?()
            }
        }
    }
}
