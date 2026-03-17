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

    private let client: LMStudioClient
    private let model: String
    private let systemPrompt: String

    public init(
        client: LMStudioClient,
        model: String = "default",
        systemPrompt: String = TranscriptCleaner.defaultSystemPrompt
    ) {
        self.client = client
        self.model = model
        self.systemPrompt = systemPrompt
    }

    /// Cleans the raw transcript using the LLM. Falls back to raw text on failure or sanity check failure.
    public func clean(rawTranscript: String) async -> CleanupResult {
        let result = await client.complete(
            systemPrompt: systemPrompt,
            userMessage: rawTranscript,
            model: model
        )

        switch result {
        case .success(let cleaned):
            if TranscriptCleaner.passesSanityCheck(input: rawTranscript, output: cleaned) {
                return CleanupResult(text: cleaned, usedLLM: true)
            } else {
                return CleanupResult(
                    text: rawTranscript,
                    usedLLM: false,
                    error: "Sanity check failed: output length was out of acceptable range."
                )
            }
        case .failure(let error):
            return CleanupResult(
                text: rawTranscript,
                usedLLM: false,
                error: error.localizedDescription
            )
        }
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
