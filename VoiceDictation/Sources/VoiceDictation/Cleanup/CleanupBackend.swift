import Foundation

/// A backend that can clean up raw transcripts using an LLM or similar model.
///
/// Conforming types provide a `complete` method that takes a system prompt and
/// user message and returns the cleaned text. The protocol enables fallback
/// chains: e.g. CoreML -> LM Studio -> raw transcript.
public protocol CleanupBackend: Sendable {
    /// A human-readable name for this backend (used in logging).
    var backendName: String { get }

    /// Whether this backend is currently available (model loaded, server reachable, etc.).
    func isAvailable() async -> Bool

    /// Sends a completion request and returns the cleaned text.
    ///
    /// - Parameters:
    ///   - systemPrompt: Instructions for the model.
    ///   - userMessage: The raw transcript to clean.
    /// - Returns: `.success` with the cleaned text, or `.failure` with an error.
    func complete(systemPrompt: String, userMessage: String) async -> Result<String, Error>
}

/// Errors specific to the cleanup backend chain.
public enum CleanupBackendError: Error, LocalizedError, Sendable {
    case modelNotFound(path: String)
    case modelLoadFailed(underlying: String)
    case predictionFailed(underlying: String)
    case noBackendAvailable

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "CoreML model not found at: \(path)"
        case .modelLoadFailed(let underlying):
            return "Failed to load CoreML model: \(underlying)"
        case .predictionFailed(let underlying):
            return "CoreML prediction failed: \(underlying)"
        case .noBackendAvailable:
            return "No cleanup backend is available."
        }
    }
}
