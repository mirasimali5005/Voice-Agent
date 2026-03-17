import Foundation
import CoreGraphics

// MARK: - HotkeyListener
// Hold the Fn (Globe) key to record. Release to stop.
// Consumes Fn key events to prevent the system emoji picker / dictation from activating.

class HotkeyListener {
    var onAction: ((HotkeyAction) -> Void)?

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRecording = false
    private var previousFnState = false

    /// Start listening for global hotkey events.
    /// Returns `false` if Accessibility permission is not granted.
    func start() -> Bool {
        // Only listen for modifier flag changes (Fn press/release).
        // We do NOT listen for keyDown — other keys should not cancel recording.
        let eventMask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        isRecording = false
        previousFnState = false
    }

    fileprivate func handleEvent(_ type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .flagsChanged {
            let fnNow = event.flags.contains(.maskSecondaryFn)

            // Only act when the Fn bit specifically changed
            if fnNow != previousFnState {
                previousFnState = fnNow

                if fnNow && !isRecording {
                    // Fn pressed — start recording
                    isRecording = true
                    onAction?(.startRecording)
                    return nil // consume event to suppress emoji picker / system dictation
                } else if !fnNow && isRecording {
                    // Fn released — stop recording
                    isRecording = false
                    onAction?(.stopRecording)
                    return nil // consume the release too
                }
            }

            // Pass through other modifier changes (Shift, Cmd, etc.)
            return Unmanaged.passUnretained(event)
        }

        // Ignore all other key presses while recording — do NOT cancel.
        // Recording only stops when Fn is released.
        return Unmanaged.passUnretained(event)
    }
}

// MARK: - C callback

private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let listener = Unmanaged<HotkeyListener>.fromOpaque(userInfo).takeUnretainedValue()

    // Re-enable the tap if macOS disabled it (this happens periodically)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = listener.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    return listener.handleEvent(type, event: event)
}
