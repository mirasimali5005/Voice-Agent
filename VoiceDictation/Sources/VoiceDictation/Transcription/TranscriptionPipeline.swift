import Combine
import Foundation

final class TranscriptionPipeline: ObservableObject {
    // MARK: - Published Properties
    @Published var assembledTranscript: String = ""
    @Published var isProcessing: Bool = false

    // MARK: - Callbacks
    var onError: ((String) -> Void)?
    var onAbort: ((String) -> Void)?

    // MARK: - Private State
    private let whisperEngine: WhisperEngine
    private let lock = NSLock()
    private var pendingCount: Int = 0
    private var consecutiveFailures: Int = 0
    private var previousChunkText: String = ""
    private var aborted: Bool = false

    // MARK: - Init

    init(whisperEngine: WhisperEngine) {
        self.whisperEngine = whisperEngine
    }

    // MARK: - Public API

    func reset() {
        lock.lock()
        assembledTranscript = ""
        isProcessing = false
        pendingCount = 0
        consecutiveFailures = 0
        previousChunkText = ""
        aborted = false
        lock.unlock()
    }

    func processChunk(_ chunk: AudioChunk) {
        // VAD check: skip truly silent chunks (0.002 is very low — only filters dead silence)
        guard chunk.rmsEnergy >= 0.002 else { return }

        lock.lock()
        guard !aborted else {
            lock.unlock()
            return
        }
        pendingCount += 1
        isProcessing = true
        lock.unlock()

        Task {
            do {
                let result = try await whisperEngine.transcribe(
                    audioSamples: chunk.samples,
                    chunkIndex: chunk.index
                )

                lock.lock()
                consecutiveFailures = 0

                let deduped: String
                if previousChunkText.isEmpty {
                    deduped = result.text
                } else {
                    deduped = TranscriptionPipeline.deduplicateOverlap(
                        previous: previousChunkText,
                        next: result.text,
                        windowSize: 5
                    )
                }

                if !deduped.isEmpty {
                    if assembledTranscript.isEmpty {
                        assembledTranscript = deduped
                    } else {
                        assembledTranscript += " " + deduped
                    }
                }

                previousChunkText = result.text
                pendingCount -= 1
                if pendingCount == 0 {
                    isProcessing = false
                }
                lock.unlock()

            } catch {
                lock.lock()
                consecutiveFailures += 1
                let failures = consecutiveFailures

                if failures >= 3 {
                    aborted = true
                    pendingCount -= 1
                    if pendingCount == 0 {
                        isProcessing = false
                    }
                    let callback = onAbort
                    lock.unlock()
                    callback?("Aborted after 3 consecutive transcription failures: \(error.localizedDescription)")
                } else {
                    // Log gap on single failure
                    if assembledTranscript.isEmpty {
                        assembledTranscript = "[gap]"
                    } else {
                        assembledTranscript += " [gap]"
                    }
                    pendingCount -= 1
                    if pendingCount == 0 {
                        isProcessing = false
                    }
                    let callback = onError
                    lock.unlock()
                    callback?("Transcription failed for chunk \(chunk.index): \(error.localizedDescription)")
                }
            }
        }
    }

    func waitForCompletion() async {
        while true {
            lock.lock()
            let pending = pendingCount
            lock.unlock()
            if pending == 0 { break }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }

    func getFinalTranscript() -> String {
        lock.lock()
        let transcript = assembledTranscript
        lock.unlock()
        return transcript
    }

    // MARK: - Overlap Deduplication

    static func deduplicateOverlap(previous: String, next: String, windowSize: Int = 5) -> String {
        guard !previous.isEmpty, !next.isEmpty else { return next }

        let prevWords = previous.split(separator: " ").map(String.init)
        let nextWords = next.split(separator: " ").map(String.init)

        guard !prevWords.isEmpty, !nextWords.isEmpty else { return next }

        let window = min(windowSize, prevWords.count, nextWords.count)

        // Look for overlapping sequences at the boundary
        // Check if the last N words of previous match the first N words of next
        // Try longest match first
        for matchLen in stride(from: window, through: 2, by: -1) {
            let prevTail = prevWords.suffix(matchLen).map { $0.lowercased() }
            let nextHead = nextWords.prefix(matchLen).map { $0.lowercased() }

            if prevTail == nextHead {
                // Found overlap: drop the matching prefix from next
                let remaining = nextWords.dropFirst(matchLen)
                return remaining.joined(separator: " ")
            }
        }

        // No overlap found
        return next
    }
}
