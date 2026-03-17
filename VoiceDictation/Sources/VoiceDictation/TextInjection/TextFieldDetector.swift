import Foundation
import ApplicationServices

struct TextFieldDetector {

    private static let textFieldRoles: Set<String> = [
        kAXTextFieldRole,
        kAXTextAreaRole,
        "AXSearchField",
        kAXComboBoxRole,
    ]

    /// Returns the focused AXUIElement if it is a text-input field, otherwise nil.
    static func getFocusedTextField() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        // Get the focused application
        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard appResult == .success, let app = focusedApp else {
            return nil
        }

        // Get the focused element within that app
        var focusedElement: AnyObject?
        let elemResult = AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard elemResult == .success, let element = focusedElement else {
            return nil
        }

        let axElement = element as! AXUIElement

        // Check the role
        var roleValue: AnyObject?
        let roleResult = AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleValue)
        if roleResult == .success, let role = roleValue as? String, textFieldRoles.contains(role) {
            return axElement
        }

        // Fallback: check if AXValue is settable (e.g. web content editable fields)
        var settable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(axElement, kAXValueAttribute as CFString, &settable)
        if settableResult == .success && settable.boolValue {
            return axElement
        }

        return nil
    }

    /// Convenience: returns true if the cursor is currently in a text field.
    static func isCursorInTextField() -> Bool {
        return getFocusedTextField() != nil
    }
}
