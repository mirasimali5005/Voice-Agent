import Foundation

/// The result of a transcript cleanup operation.
public struct CleanupResult: Sendable {
    /// The cleaned (or fallback raw) text.
    public let text: String
    /// Whether the LLM was used successfully to clean the transcript.
    public let usedLLM: Bool
    /// An optional error description if something went wrong.
    public let error: String?

    public init(text: String, usedLLM: Bool, error: String? = nil) {
        self.text = text
        self.usedLLM = usedLLM
        self.error = error
    }
}

/// Cleans raw voice transcripts using an LLM via LM Studio.
public final class TranscriptCleaner: Sendable {
    /// The default system prompt instructing the LLM how to clean transcripts.
    public static let defaultSystemPrompt = """
        You are a voice-to-text cleanup assistant. You receive raw speech-to-text output and clean it into polished text.

        CRITICAL RULES:
        1. Remove filler words: um, uh, uhh, like, you know, so, basically, I mean, right, well, actually, kind of, sort of.
        2. Fix punctuation, capitalization, and sentence boundaries.
        3. If the speaker lists items, format as a numbered or bulleted list.
        4. PRESERVE the speaker's exact words (minus fillers). Do NOT rephrase, summarize, or add your own words.
        5. Output ONLY the cleaned text. No commentary, no headers, no "Here is the cleaned text:", nothing extra.

        CONTEXT AWARENESS — Use context to fix speech-to-text errors:
        - Recognize proper nouns, brand names, and tech terms from context. Examples:
          "quen" or "kwen" → "Qwen" (an AI model by Alibaba)
          "deep seek" → "DeepSeek"
          "gemma" → "Gemma" (a Google AI model)
          "l m studio" or "lm studio" → "LM Studio"
          "whisper" → "Whisper" (OpenAI's speech model)
          "mac o s" → "macOS"
          "swift" → "Swift" (when talking about programming)
          "x code" → "Xcode"
          "g p t" → "GPT"
          "chat g p t" → "ChatGPT"
          "open a i" → "OpenAI"
          "anthropic" → "Anthropic"
          "claude" → "Claude"
          "python" → "Python"
          "java script" → "JavaScript"
        - Recognize abbreviations spoken as letters: "l l m" → "LLM", "a p i" → "API", "u i" → "UI", "g p u" → "GPU", "c p u" → "CPU", "r a m" → "RAM", "s t t" → "STT"
        - Use surrounding words to infer the correct spelling of ambiguous words.
        - Fix number formatting: "eight billion" → "8 billion", "four point five" → "4.5"

        Remember: output ONLY the cleaned transcript text, nothing else.
        """

    // MARK: - Mode-Specific Prompt Templates

    /// Extra instructions appended when Formal mode is active.
    public static let formalPrompt = """
        Clean up using professional, formal language. Expand contractions (gonna→going to, wanna→want to). Use proper punctuation.
        """

    /// Extra instructions appended when Casual mode is active.
    public static let casualPrompt = """
        Clean up keeping casual, conversational tone. Keep contractions. Fix obvious filler words only.
        """

    /// Extra instructions appended when Coding mode is active.
    public static let codingPrompt = """
        Clean up preserving all technical terms, code syntax, camelCase, snake_case. Don't expand abbreviations.
        """

    /// Returns the mode-specific prompt fragment for the given mode.
    static func modePrompt(for mode: DictationMode) -> String {
        switch mode {
        case .formal:  return formalPrompt
        case .casual:  return casualPrompt
        case .coding:  return codingPrompt
        }
    }

    /// Ordered list of backends to try. The cleaner attempts each in order,
    /// falling through to the next on failure or unavailability.
    private let backends: [any CleanupBackend]
    private let systemPrompt: String

    /// Initialize with an ordered list of cleanup backends and optional system prompt.
    ///
    /// The cleaner will try each backend in order during `clean(...)`. If a
    /// backend reports itself as unavailable or returns a failure, the next
    /// backend is tried. If all fail, the raw transcript is returned.
    public init(
        backends: [any CleanupBackend],
        systemPrompt: String = TranscriptCleaner.defaultSystemPrompt
    ) {
        self.backends = backends
        self.systemPrompt = systemPrompt
    }

    /// Convenience initializer that wraps a single LMStudioClient (backward compat).
    public convenience init(
        client: LMStudioClient,
        model: String = "default",
        systemPrompt: String = TranscriptCleaner.defaultSystemPrompt
    ) {
        self.init(backends: [client], systemPrompt: systemPrompt)
    }

    /// Cleans the raw transcript by trying each backend in order.
    ///
    /// The method tries each backend sequentially:
    /// 1. CoreML (if model exists) — fastest, no network
    /// 2. LM Studio (if running) — good quality
    /// 3. Raw transcript (fallback) — no cleanup
    ///
    /// Falls back to raw text if all backends fail or sanity check fails.
    func clean(rawTranscript: String, mode: DictationMode = .casual) async -> CleanupResult {
        // Build the final prompt: base system prompt + mode-specific instructions
        let modeFragment = Self.modePrompt(for: mode)
        let fullPrompt = systemPrompt + "\n\n" + modeFragment

        var lastError: String?

        for backend in backends {
            // Check availability first to skip unavailable backends quickly
            guard await backend.isAvailable() else {
                print("[TranscriptCleaner] Skipping \(backend.backendName): not available")
                lastError = "\(backend.backendName) not available"
                continue
            }

            let result = await backend.complete(
                systemPrompt: fullPrompt,
                userMessage: rawTranscript
            )

            switch result {
            case .success(let cleaned):
                if TranscriptCleaner.passesSanityCheck(input: rawTranscript, output: cleaned) {
                    print("[TranscriptCleaner] Cleaned via \(backend.backendName)")
                    return CleanupResult(text: cleaned, usedLLM: true)
                } else {
                    print("[TranscriptCleaner] \(backend.backendName) failed sanity check, trying next")
                    lastError = "Sanity check failed for \(backend.backendName)"
                    continue
                }
            case .failure(let error):
                print("[TranscriptCleaner] \(backend.backendName) failed: \(error.localizedDescription)")
                lastError = error.localizedDescription
                continue
            }
        }

        // All backends failed — return raw transcript
        return CleanupResult(
            text: rawTranscript,
            usedLLM: false,
            error: lastError
        )
    }

    /// Checks that the output word count is between 30% and 180% of the input word count.
    public static func passesSanityCheck(input: String, output: String) -> Bool {
        let inputWords = input.split(whereSeparator: { $0.isWhitespace }).count
        let outputWords = output.split(whereSeparator: { $0.isWhitespace }).count

        // If input is very short (0-2 words), allow any reasonable output
        guard inputWords > 2 else { return true }

        let lowerBound = Double(inputWords) * 0.30
        let upperBound = Double(inputWords) * 1.80

        return Double(outputWords) >= lowerBound && Double(outputWords) <= upperBound
    }
}
