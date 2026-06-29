import Cocoa

final class ScrollInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapSelf: Unmanaged<ScrollInterceptor>?

    var isRunning: Bool { eventTap != nil }

    func start() -> Bool {
        guard !isRunning else {
            // Re-enable in case the tap was disabled without handle() firing.
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return true
        }
        guard AXIsProcessTrusted() else { return false }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)

        let retained = Unmanaged.passRetained(self)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: retained.toOpaque()
        ) else {
            retained.release()
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            retained.release()
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        tapSelf = retained
        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tapSelf?.release()
        tapSelf = nil
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> CGEvent? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return event
        }

        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        // Pass through trackpad and Magic Mouse, which set a non-zero scroll or momentum phase.
        // Smooth-scrolling mice report isContinuous but have no phase — treat them like discrete mice.
        guard isContinuous == 0 || (phase == 0 && momentumPhase == 0) else { return event }

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
