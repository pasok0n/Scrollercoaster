import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSTextFieldDelegate {
    private static let hideStatusIconKey = "hideStatusIcon"

    private let interceptor = ScrollInterceptor()
    private let globalPreferences = UserDefaults(suiteName: ".GlobalPreferences")
    private var statusItem: NSStatusItem?
    private var warningItem: NSMenuItem?
    private var noAccelItem: NSMenuItem?
    private var speedSlider: NSSlider?
    private var speedValueLabel: NSTextField?
    private var loginItem: NSMenuItem?
    private var hideIconItem: NSMenuItem?
    private var accessibilityTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        requestAccessibilityIfNeeded()
        // Popping the menu on a login-item launch would steal focus at every boot;
        // only do it when the user deliberately opened the app.
        if !launchedAsLoginItem {
            DispatchQueue.main.async { [weak self] in self?.showMenuIfIconHidden() }
        }
    }

    private var launchedAsLoginItem: Bool {
        // Only valid while the launch event is being handled, i.e. inside
        // applicationDidFinishLaunching.
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
            == OSType(keyAELaunchedAsLogInItem)
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityTimer?.invalidate()
        interceptor.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMenuIfIconHidden()
        return true
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Scrollercoaster")
        item.button?.image?.isTemplate = true
        item.isVisible = !UserDefaults.standard.bool(forKey: Self.hideStatusIconKey)

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

        let noAccel = NSMenuItem(title: "Disable Scroll Acceleration", action: #selector(toggleNoAccel), keyEquivalent: "")
        noAccel.target = self
        noAccelItem = noAccel
        menu.addItem(noAccel)

        let sliderContainer = NSView(frame: NSRect(x: 0, y: 0, width: 285, height: 28))
        let slowLabel = NSTextField(labelWithString: "Slow")
        slowLabel.frame = NSRect(x: 38, y: 7, width: 32, height: 14)
        slowLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        slowLabel.textColor = .secondaryLabelColor
        let slider = NSSlider(frame: NSRect(x: 73, y: 4, width: 140, height: 20))
        slider.minValue = 1
        slider.maxValue = 100
        slider.doubleValue = UserDefaults.standard.object(forKey: "scrollSpeed") as? Double ?? 10.0
        slider.isEnabled = UserDefaults.standard.bool(forKey: "disableScrollAcceleration")
        slider.target = self
        slider.action = #selector(scrollSpeedChanged(_:))
        slider.isContinuous = true
        let fastLabel = NSTextField(labelWithString: "Fast")
        fastLabel.frame = NSRect(x: 216, y: 7, width: 30, height: 14)
        fastLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        fastLabel.textColor = .secondaryLabelColor
        let initialSpeed = UserDefaults.standard.object(forKey: "scrollSpeed") as? Double ?? 10.0
        let valueLabel = NSTextField()
        valueLabel.frame = NSRect(x: 247, y: 5, width: 36, height: 18)
        valueLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        valueLabel.alignment = .right
        valueLabel.stringValue = "\(Int(initialSpeed.rounded()))"
        valueLabel.delegate = self
        let fmt = NumberFormatter()
        fmt.numberStyle = .none
        fmt.minimum = 1
        fmt.maximum = 100
        fmt.allowsFloats = false
        valueLabel.formatter = fmt
        sliderContainer.addSubview(slowLabel)
        sliderContainer.addSubview(slider)
        sliderContainer.addSubview(fastLabel)
        sliderContainer.addSubview(valueLabel)
        let sliderItem = NSMenuItem()
        sliderItem.view = sliderContainer
        speedSlider = slider
        speedValueLabel = valueLabel
        menu.addItem(sliderItem)

        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        if #unavailable(macOS 13) {
            login.isEnabled = false
        }
        loginItem = login
        menu.addItem(login)

        let hideIcon = NSMenuItem(title: "Hide Menu Bar Icon", action: #selector(toggleHideIcon), keyEquivalent: "")
        hideIcon.target = self
        hideIconItem = hideIcon
        menu.addItem(hideIcon)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        checkNaturalScrollingWarning()
        loginItem?.state = isLoginItemEnabled ? .on : .off
        hideIconItem?.state = UserDefaults.standard.bool(forKey: Self.hideStatusIconKey) ? .on : .off
        let accelDisabled = UserDefaults.standard.bool(forKey: "disableScrollAcceleration")
        noAccelItem?.state = accelDisabled ? .on : .off
        let speed = UserDefaults.standard.object(forKey: "scrollSpeed") as? Double ?? 10.0
        speedSlider?.doubleValue = speed
        speedSlider?.isEnabled = accelDisabled
        speedValueLabel?.isEnabled = accelDisabled
        speedValueLabel?.stringValue = "\(Int(speed.rounded()))"
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

    @objc private func toggleHideIcon() {
        let hidden = !UserDefaults.standard.bool(forKey: Self.hideStatusIconKey)
        UserDefaults.standard.set(hidden, forKey: Self.hideStatusIconKey)
        hideIconItem?.state = hidden ? .on : .off
        statusItem?.isVisible = !hidden
    }

    private func showMenuIfIconHidden() {
        guard UserDefaults.standard.bool(forKey: Self.hideStatusIconKey), let menu = statusItem?.menu else { return }
        // screens.first is the screen that owns the menu bar; NSScreen.main is
        // merely the screen with keyboard focus.
        guard let screenFrame = NSScreen.screens.first?.frame else { return }
        NSApp.activate(ignoringOtherApps: true)
        let location = NSPoint(
            x: screenFrame.maxX - menu.size.width - 20,
            y: screenFrame.maxY - NSStatusBar.system.thickness
        )
        menu.popUp(positioning: nil, at: location, in: nil)
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            launchInterceptor()
        } else {
            var attempts = 0
            let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
                attempts += 1
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.accessibilityTimer = nil
                    self?.launchInterceptor()
                } else if attempts >= 120 {
                    timer.invalidate()
                    self?.accessibilityTimer = nil
                    self?.showFailureAlert(
                        message: "Scrollercoaster is not running",
                        informative: "Accessibility access was not granted. Grant it to Scrollercoaster in System Settings → Privacy & Security → Accessibility, then relaunch the app."
                    )
                }
            }
            // .common so the poll keeps running while a menu is being tracked.
            RunLoop.main.add(timer, forMode: .common)
            accessibilityTimer = timer
        }
    }

    private func showFailureAlert(message: String, informative: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = informative
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func launchInterceptor() {
        interceptor.disableAcceleration = UserDefaults.standard.bool(forKey: "disableScrollAcceleration")
        interceptor.scrollSpeed = UserDefaults.standard.object(forKey: "scrollSpeed") as? Double ?? 10.0
        guard interceptor.start() else {
            statusItem?.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error")
            statusItem?.button?.toolTip = "Scrollercoaster failed to start. Re-grant Accessibility access in System Settings."
            showFailureAlert(
                message: "Scrollercoaster failed to start",
                informative: "Re-grant Accessibility access to Scrollercoaster in System Settings → Privacy & Security → Accessibility, then relaunch the app."
            )
            return
        }
    }

    private func checkNaturalScrollingWarning() {
        let naturalScrolling = globalPreferences?.bool(forKey: "com.apple.swipescrolldirection") ?? true
        warningItem?.isHidden = naturalScrolling
    }

    @objc private func toggleNoAccel() {
        let enabled = !UserDefaults.standard.bool(forKey: "disableScrollAcceleration")
        UserDefaults.standard.set(enabled, forKey: "disableScrollAcceleration")
        interceptor.disableAcceleration = enabled
        noAccelItem?.state = enabled ? .on : .off
        speedSlider?.isEnabled = enabled
        speedValueLabel?.isEnabled = enabled
    }

    @objc private func scrollSpeedChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        UserDefaults.standard.set(value, forKey: "scrollSpeed")
        interceptor.scrollSpeed = value
        speedValueLabel?.stringValue = "\(Int(value.rounded()))"
    }

    @objc private func scrollSpeedValueEntered(_ sender: NSTextField) {
        guard !sender.stringValue.isEmpty else { return }
        let clamped = min(100, max(1, sender.integerValue))
        sender.integerValue = clamped
        speedSlider?.doubleValue = Double(clamped)
        UserDefaults.standard.set(Double(clamped), forKey: "scrollSpeed")
        interceptor.scrollSpeed = Double(clamped)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === speedValueLabel else { return }
        scrollSpeedValueEntered(field)
    }

    @objc private func openScrollSettings() {
        let urlString: String
        if #available(macOS 13, *) {
            urlString = "x-apple.systempreferences:com.apple.Trackpad-Settings.extension"
        } else {
            urlString = "x-apple.systempreferences:com.apple.preference.trackpad"
        }
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
