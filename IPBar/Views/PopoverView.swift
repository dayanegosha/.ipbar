import SwiftUI

@MainActor
final class PopoverNavigation: ObservableObject {
    @Published var showsSettings = false
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
            } else if navigation.showsSettings {
                VStack(spacing: 0) {
                    HStack {
                        Button { navigation.showsSettings = false } label: {
                            Label("Back", systemImage: "chevron.left")
                        }.buttonStyle(.plain).foregroundStyle(.secondary)
                        Spacer()
                        Text("Settings").font(.headline)
                        Spacer()
                        Color.clear.frame(width: 48, height: 1)
                    }.padding(20)
                    Divider()
                    SettingsView(settings: settings, monitor: monitor, login: login)
                }
            } else {
                MenuBarView(monitor: monitor, settings: settings, wifi: wifi,
                    openSettings: { navigation.showsSettings = true },
                    quit: { NSApp.terminate(nil) })
            }
        }
        .frame(width: 380, height: 590)
    }
}
