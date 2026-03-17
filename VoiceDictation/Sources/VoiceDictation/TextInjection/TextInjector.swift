import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

enum InjectionResult: Equatable {
    case pastedViaAccessibility
    case pastedViaKeyboard
    case copiedToClipboard
    case failed(String)
}

struct TextInjector {

    /// Inject transcribed text.
    /// - `focusedElement`: optionally pass a pre-captured AXUIElement (captured at Ctrl-release time).
    ///   If nil, will try to detect the current focused text field.
    /// Always copies to clipboard. If a text field is available, also pastes there.
    static func inject(text: String, focusedElement: AXUIElement? = nil) -> InjectionResult {
        // Step 1: Always copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Step 2: Check if there's a text field focused (pre-captured or detect now)
        let element = focusedElement ?? TextFieldDetector.getFocusedTextField()
        guard element != nil else {
            return .copiedToClipboard
        }

        // Step 3: Simulate Cmd+V to paste from clipboard
        // (AX injection via kAXSelectedTextAttribute is unreliable — many apps report
        // success but don't actually insert the text. Cmd+V works universally.)
        if simulatePaste() {
            return .pastedViaKeyboard
        }

        return .copiedToClipboard
    }

    // MARK: - Private

    private static func tryAccessibilityInject(element: AXUIElement, text: String) -> Bool {
        // Try setting selected text first (inserts at cursor position)
        let selectedResult = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        if selectedResult == .success {
            return true
        }

        // Try replacing the entire value
        let valueResult = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )
        return valueResult == .success
    }

    private static func simulatePaste() -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Key code 9 = V
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Use cgAnnotatedSessionEventTap — more reliable across apps
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        // Small delay so the app processes the keyDown before keyUp
        usleep(50_000) // 50ms
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }
}
