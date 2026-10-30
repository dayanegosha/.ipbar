import SwiftUI

@MainActor
final class PopoverNavigation: ObservableObject {
    @Published var showsSettings = false
    @Published var showsAddresses = false
}

struct PopoverView: View {
    @ObservedObject var navigation: PopoverNavigation
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var settings: SettingsStore
    @ObservedObject var wifi: WiFiController
    @ObservedObject var login: LoginItemController

    var body: some View {
        Group {
            if !settings.onboardingComplete {
                OnboardingView(settings: settings, login: login)
            } else if navigation.showsSettings || navigation.showsAddresses {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            navigation.showsSettings = false
                            navigation.showsAddresses = false
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }.buttonStyle(.plain).foregroundStyle(.secondary)
                        Spacer()
                        Text(navigation.showsSettings ? "Settings" : "All addresses").font(.headline)
                        Spacer()
                        Color.clear.frame(width: 48, height: 1)
                    }.padding(20)
                    Divider()
                    if navigation.showsSettings {
                        SettingsView(settings: settings, monitor: monitor, login: login)
                    } else {
                        AddressesView(monitor: monitor, settings: settings)
                    }
                }
            } else {
                MenuBarView(monitor: monitor, settings: settings, wifi: wifi,
                    openAddresses: { navigation.showsAddresses = true },
                    openSettings: { navigation.showsSettings = true },
                    quit: { NSApp.terminate(nil) })
            }
        }
        .frame(width: 380, height: settings.onboardingComplete ? 520 : 590)
    }
}
