import AppKit
import Foundation

/// Detects the current environment context (frontmost app, time of day)
/// to provide situational awareness for dictation cleanup.
struct ContextDetector {

    /// Returns the localized name of the frontmost application.
    static func getFrontmostApp() -> String {
        NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    }

    /// Returns a human-readable time-of-day label based on the current hour.
    static func getTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default:       return "night"
        }
    }

    /// Builds a full `DictationContext` snapshot combining app, time, and mode.
    static func getCurrentContext(mode: DictationMode) -> DictationContext {
        DictationContext(
            appName: getFrontmostApp(),
            timeOfDay: getTimeOfDay(),
            mode: mode
        )
    }
}
