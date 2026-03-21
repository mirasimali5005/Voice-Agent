import Foundation

/// A snapshot of the environment at the time dictation starts.
struct DictationContext {
    let appName: String
    let timeOfDay: String
    let mode: DictationMode

    /// Returns a short sentence describing the current context, suitable
    /// for prepending to the LLM system prompt.
    func promptFragment() -> String {
        "You are writing in \(appName) during the \(timeOfDay) in \(mode.rawValue.capitalized) mode."
    }
}
