import Cocoa

final class ScrollInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapSelf: Unmanaged<ScrollInterceptor>?

    var isRunning: Bool { eventTap != nil }

    var disableAcceleration: Bool = false
    var scrollSpeed: Double = 10.0

    func start() -> Bool {
        guard !isRunning else {
            // Re-enable in case the tap was disabled without handle() firing.
            CGEvent.tapEnable(tap: eventTap!, enable: true)
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
            CFMachPortInvalidate(tap)
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

        if disableAcceleration {
            // Re-read the already-inverted integer deltas to get the scroll direction.
            let lineDy = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let lineDx = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            // Normalise to ±1 so any per-event acceleration is stripped, then apply the
            // user-configured speed. This replaces all six delta fields so that every
            // consumer (deltaY, scrollingDeltaY, pixel delta) sees the same linear value.
            let signDy = Int64(lineDy.signum())
            let signDx = Int64(lineDx.signum())
            let speed = max(1.0, scrollSpeed.rounded())
            let speedInt = Int64(speed)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: signDy * speedInt)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: signDx * speedInt)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Double(signDy) * speed)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: Double(signDx) * speed)
            event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: Double(signDy) * speed)
            event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: Double(signDx) * speed)
        }

        return event
    }
}

private func eventTapCallback(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let interceptor = Unmanaged<ScrollInterceptor>.fromOpaque(refcon).takeUnretainedValue()
    if let out = interceptor.handle(type: type, event: event) {
        return Unmanaged.passUnretained(out)
    }
    return nil
}
