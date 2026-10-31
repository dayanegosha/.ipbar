import AppKit
import SwiftUI
import Combine
import IPBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = NetworkMonitor()
    private let settings = SettingsStore()
    private let wifi = WiFiController()
    private let login = LoginItemController()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let navigation = PopoverNavigation()
    private var subscriptions: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           let other = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate()
            NSApp.terminate(nil)
            return
        }
        installMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "IPBarStatusItem"
        if let button = item.button {
            button.title = "No IP"
            button.font = NSFont.menuBarFont(ofSize: 0)
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel(".ipbar — No IP")
        }
        statusItem = item
        popover.behavior = .transient
        popover.animates = true
        let hostingController = NSHostingController(rootView: PopoverView(
            navigation: navigation, monitor: monitor, settings: settings, wifi: wifi, login: login))
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
        Publishers.CombineLatest4(monitor.$snapshot, settings.$selection, settings.$display, settings.$addressFamily)
            .sink { [weak self] snapshot, selection, display, family in
                let interface = snapshot.selected(InterfaceSelection(rawValue: selection), family: family)
                let title = display.title(for: interface, family: family)
                guard let button = self?.statusItem?.button else { return }
                if button.title != title { button.title = title }
                button.toolTip = ".ipbar — \(snapshot.status(for: interface).rawValue)"
                button.setAccessibilityLabel(".ipbar — \(title)")
            }.store(in: &subscriptions)
        settings.onChange = { [weak self] in
            guard let self else { return }
            self.monitor.configure(polling: true, interval: self.settings.interval)
        }
        monitor.configure(polling: true, interval: settings.interval)
        wifi.didChange = { [weak self] in self?.monitor.refresh() }
        monitor.start()
        login.enableOnFirstLaunch(settings: settings)
        if !settings.onboardingComplete {
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.popover.isShown else { return }
                self.togglePopover()
            }
        }
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil); return }
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        monitor.refresh()
        wifi.refresh()
    }

    @objc private func showSettings() {
        login.refresh()
        navigation.showsSettings = true
        if !popover.isShown { togglePopover() }
    }

    private func installMenu() {
        let menu = NSMenu()
        let item = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit .ipbar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu
        menu.addItem(item)
        NSApp.mainMenu = menu
    }

    func applicationDidBecomeActive(_ notification: Notification) { login.refresh(); wifi.refresh() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { togglePopover() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        subscriptions.removeAll()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }
}
