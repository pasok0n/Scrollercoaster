import Cocoa

NSApp = NSApplication.shared
NSApp.setActivationPolicy(.accessory)

let delegate = AppDelegate()
NSApp.delegate = delegate
NSApp.run()
