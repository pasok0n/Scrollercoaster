import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let interceptor = ScrollInterceptor()
    private let globalPreferences = UserDefaults(suiteName: ".GlobalPreferences")
    private var statusItem: NSStatusItem?
    private var warningItem: NSMenuItem?
    private var loginItem: NSMenuItem?
    private var accessibilityTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        requestAccessibilityIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        interceptor.stop()
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Scrollercoaster")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self

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
        loginItem = login
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        checkNaturalScrollingWarning()
        loginItem?.state = isLoginItemEnabled ? .on : .off
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
                loginItem?.state = .off
            } else {
                try SMAppService.mainApp.register()
                loginItem?.state = .on
            }
        } catch {
            loginItem?.state = isLoginItemEnabled ? .on : .off
            NSAlert(error: error).runModal()
        }
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            launchInterceptor()
        } else {
            var attempts = 0
            accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                attempts += 1
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.accessibilityTimer = nil
                    self?.launchInterceptor()
                } else if attempts >= 120 {
                    timer.invalidate()
                    self?.accessibilityTimer = nil
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
        let naturalScrolling = globalPreferences?.bool(forKey: "com.apple.swipescrolldirection") ?? true
        warningItem?.isHidden = naturalScrolling
    }

    @objc private func openScrollSettings() {
        let url: URL
        if #available(macOS 13, *) {
            url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!
        } else {
            url = URL(string: "x-apple.systempreferences:com.apple.preference.trackpad")!
        }
        NSWorkspace.shared.open(url)
    }
}
