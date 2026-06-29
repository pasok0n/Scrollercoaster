import Cocoa

final class ScrollInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { eventTap != nil }

    func start() -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passRetained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> CGEvent? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return event
        }

        // isContinuous == 1: trackpad or Magic Mouse — pass through unchanged.
        // Regular mouse wheels report isContinuous == 0 (discrete line events).
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
        guard isContinuous == 0 else { return event }

        let dy = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let dx = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let fdy = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fdx = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        let pdy = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let pdx = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)

        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -dy)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -dx)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fdy)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fdx)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: -pdy)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: -pdx)

        return event
    }
}

private func eventTapCallback(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }
    let interceptor = Unmanaged<ScrollInterceptor>.fromOpaque(refcon).takeUnretainedValue()
    if let out = interceptor.handle(type: type, event: event) {
        return Unmanaged.passRetained(out)
    }
    return nil
}
