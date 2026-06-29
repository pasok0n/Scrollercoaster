import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let interceptor = ScrollInterceptor()
    private var statusItem: NSStatusItem?
    private var warningItem: NSMenuItem?
    private var loginItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        requestAccessibilityIfNeeded()
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Scrollercoaster")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Scrollercoaster", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(.separator())

        let warning = NSMenuItem(
            title: "⚠ Enable Natural Scrolling in System Settings",
            action: #selector(openScrollSettings),
            keyEquivalent: ""
        )
        warning.target = self
        warning.isHidden = true
        warningItem = warning
        menu.addItem(warning)

        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = isLoginItemEnabled ? .on : .off
        loginItem = login
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        item.menu = menu
        statusItem = item

        checkNaturalScrollingWarning()
    }

    private var isLoginItemEnabled: Bool {
        if #available(macOS 13, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc private func toggleLoginItem() {
        guard #available(macOS 13, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            loginItem?.state = isLoginItemEnabled ? .on : .off
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            launchInterceptor()
        } else {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.launchInterceptor()
                }
            }
        }
    }

    private func launchInterceptor() {
        let ok = interceptor.start()
        if !ok {
            statusItem?.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error")
        }
    }

    private func checkNaturalScrollingWarning() {
        let defaults = UserDefaults(suiteName: ".GlobalPreferences")
        let naturalScrolling = defaults?.bool(forKey: "com.apple.swipescrolldirection") ?? true
        warningItem?.isHidden = naturalScrolling
    }

    @objc private func openScrollSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.trackpad")!)
    }
}
