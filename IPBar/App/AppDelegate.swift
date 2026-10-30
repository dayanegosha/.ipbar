import AppKit
import SwiftUI
import Combine
import IPBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = NetworkMonitor()
    private let settings = SettingsStore()
    private let login = LoginItemController()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
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
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("IP Bar — No IP")
        }
        statusItem = item
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView(
            monitor: monitor, settings: settings,
            openSettings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) }))
        popover.contentSize = NSSize(width: 380, height: 600)
        Publishers.CombineLatest3(monitor.$snapshot, settings.$selection, settings.$display)
            .sink { [weak self] snapshot, selection, display in
                let interface = snapshot.selected(InterfaceSelection(rawValue: selection))
                let title = display.title(for: interface)
                self?.statusItem?.button?.title = title
                self?.statusItem?.button?.toolTip = "IP Bar — \(snapshot.status(for: interface).rawValue)"
                self?.statusItem?.button?.setAccessibilityLabel("IP Bar — \(title)")
            }.store(in: &subscriptions)
        settings.onChange = { [weak self] in
            guard let self else { return }
            self.monitor.configure(polling: self.settings.automaticRefresh, interval: self.settings.interval)
        }
        monitor.configure(polling: settings.automaticRefresh, interval: settings.interval)
        monitor.start()
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil); return }
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        monitor.refresh()
    }

    @objc private func showSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 570),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "IP Bar Settings"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: SettingsView(settings: settings, monitor: monitor, login: login))
            window.center()
            settingsWindow = window
        }
        login.refresh()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func installMenu() {
        let menu = NSMenu()
        let item = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit IP Bar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu
        menu.addItem(item)
        NSApp.mainMenu = menu
    }

    func applicationDidBecomeActive(_ notification: Notification) { login.refresh() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { togglePopover() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        subscriptions.removeAll()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }
}
