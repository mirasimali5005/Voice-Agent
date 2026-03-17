import Foundation
import Combine

final class DictationOrchestrator {
    // MARK: - Dependencies
    private let appState: AppState
    private var whisperEngine: WhisperEngine?
    private var databaseManager: DatabaseManager?
    private var pipeline: TranscriptionPipeline?
    private var cleaner: TranscriptCleaner?

    // MARK: - Recording State
    private let audioRecorder = AudioRecorder()
    private var durationTimer: DispatchSourceTimer?
    private var recordingStartTime: Date?

    // MARK: - Filler words to strip instantly (no LLM needed)
    private static let fillerPattern: NSRegularExpression? = {
        let fillers = [
            "\\buh\\b", "\\bum\\b", "\\bumm\\b", "\\buhh\\b",
            "\\byou know\\b", "\\blike\\b(?=\\s)", "\\bbasically\\b",
            "\\bi mean\\b", "\\bso\\b(?=\\s*,)", "\\bright\\b(?=\\s*,)",
            "\\bwell\\b(?=\\s*,)", "\\bactually\\b(?=\\s*,)"
        ]
        return try? NSRegularExpression(
            pattern: fillers.joined(separator: "|"),
            options: [.caseInsensitive]
        )
    }()

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Configuration

    func configure(whisperEngine: WhisperEngine, databaseManager: DatabaseManager) {
        self.whisperEngine = whisperEngine
        self.databaseManager = databaseManager
        self.pipeline = TranscriptionPipeline(whisperEngine: whisperEngine)
        rebuildCleaner()
    }

    /// Rebuilds the TranscriptCleaner with the latest settings (custom prompt, endpoint).
    /// Called at configure time and before each recording so edits take effect immediately.
    private func rebuildCleaner() {
        let client = LMStudioClient(
            endpoint: appState.lmStudioEndpoint,
            timeoutSeconds: 30.0
        )

        // Read custom prompt from database; fall back to default
        var prompt = TranscriptCleaner.defaultSystemPrompt
        if let db = databaseManager,
           let saved = try? db.getSetting("cleanupPrompt"),
           !saved.isEmpty {
            prompt = saved
        }

        self.cleaner = TranscriptCleaner(
            client: client,
            model: appState.lmStudioModel,
            systemPrompt: prompt
        )
    }

    // MARK: - Quick Regex Cleanup (instant, no LLM)

    static func quickCleanup(_ text: String) -> String {
        guard let pattern = fillerPattern else { return text }
        let range = NSRange(text.startIndex..., in: text)
        var cleaned = pattern.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        cleaned = cleaned.replacingOccurrences(of: " ,", with: ",")
        cleaned = cleaned.replacingOccurrences(of: ",,", with: ",")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Recording Control

    func startRecording() {
        guard let pipeline = pipeline else { return }

        // Rebuild cleaner so any prompt/model changes take effect
        rebuildCleaner()

        pipeline.reset()
        recordingStartTime = Date()

        do {
            try audioRecorder.startRecording(
                onChunk: { [weak self] chunk in
                    self?.pipeline?.processChunk(chunk)
                },
                onAudioLevel: { [weak self] level in
                    DispatchQueue.main.async {
                        self?.appState.currentAudioLevel = level
                    }
                }
            )
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.appState.statusMessage = "Failed to start recording: \(error.localizedDescription)"
            }
            return
        }

        // Update UI state
        self.appState.isRecording = true
        self.appState.recordingDuration = 0
        self.appState.showWarning = false
        self.appState.statusMessage = "Recording..."

        // GCD timer — fires reliably regardless of RunLoop mode
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(500), repeating: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            guard let self = self, let start = self.recordingStartTime else { return }
            let elapsed = Date().timeIntervalSince(start)
            self.appState.recordingDuration = elapsed

            if elapsed >= 270 && !self.appState.showWarning {
                self.appState.showWarning = true
                self.appState.statusMessage = "Warning: approaching 5-minute limit"
            }
            if elapsed >= 300 {
                self.stopRecording()
            }
        }
        timer.resume()
        self.durationTimer = timer
    }

    func stopRecording() {
        durationTimer?.cancel()
        durationTimer = nil

        let finalChunk = audioRecorder.stopRecording()
        let duration = appState.recordingDuration

        // CAPTURE the focused text field NOW, before any async work
        let focusedTextField = TextFieldDetector.getFocusedTextField()

        appState.isRecording = false
        appState.currentAudioLevel = 0
        appState.statusMessage = "Processing..."

        guard let pipeline = pipeline else { return }

        if let chunk = finalChunk {
            pipeline.processChunk(chunk)
        }

        Task { [weak self] in
            guard let self = self else { return }

            await pipeline.waitForCompletion()
            let rawTranscript = pipeline.getFinalTranscript()

            guard !rawTranscript.isEmpty else {
                await MainActor.run {
                    self.appState.statusMessage = "No speech detected"
                    self.appState.lastDictation = ""
                }
                return
            }

            let quickCleaned = Self.quickCleanup(rawTranscript)

            let injectionResult = TextInjector.inject(
                text: quickCleaned,
                focusedElement: focusedTextField
            )
            let wasPasted: Bool
            switch injectionResult {
            case .pastedViaAccessibility, .pastedViaKeyboard:
                wasPasted = true
            case .copiedToClipboard, .failed:
                wasPasted = false
            }

            await MainActor.run {
                self.appState.lastDictation = quickCleaned
                switch injectionResult {
                case .pastedViaAccessibility, .pastedViaKeyboard:
                    self.appState.statusMessage = "Pasted (cleaning up...)"
                case .copiedToClipboard:
                    self.appState.statusMessage = "Copied to clipboard (cleaning up...)"
                case .failed(let reason):
                    self.appState.statusMessage = "Clipboard only: \(reason)"
                }
            }

            // Save entry
            let entry: DictationEntry
            do {
                entry = try self.databaseManager?.insert(DictationEntry(
                    timestamp: Date(),
                    durationSeconds: duration,
                    rawTranscript: rawTranscript,
                    cleanedText: quickCleaned,
                    wasPasted: wasPasted
                )) ?? DictationEntry(
                    timestamp: Date(),
                    durationSeconds: duration,
                    rawTranscript: rawTranscript,
                    cleanedText: quickCleaned,
                    wasPasted: wasPasted
                )
            } catch {
                entry = DictationEntry(
                    timestamp: Date(),
                    durationSeconds: duration,
                    rawTranscript: rawTranscript,
                    cleanedText: quickCleaned,
                    wasPasted: wasPasted
                )
            }

            // LLM cleanup in background
            if let cleaner = self.cleaner {
                let cleanupResult = await cleaner.clean(rawTranscript: rawTranscript)
                if cleanupResult.usedLLM {
                    try? self.databaseManager?.updateCleanedText(
                        id: entry.id,
                        cleanedText: cleanupResult.text
                    )
                    await MainActor.run {
                        self.appState.lastDictation = cleanupResult.text
                        self.appState.statusMessage = wasPasted ? "Pasted" : "Copied to clipboard"
                    }
                } else {
                    await MainActor.run {
                        if let error = cleanupResult.error {
                            self.appState.statusMessage = "LM Studio: \(error)"
                        } else {
                            self.appState.statusMessage = wasPasted ? "Pasted" : "Copied to clipboard"
                        }
                    }
                }
            } else {
                await MainActor.run {
                    self.appState.statusMessage = wasPasted ? "Pasted" : "Copied to clipboard"
                    self.appState.showWarning = false
                }
            }
        }
    }

    func cancelRecording() {
        durationTimer?.cancel()
        durationTimer = nil
        _ = audioRecorder.stopRecording()
        pipeline?.reset()

        appState.isRecording = false
        appState.recordingDuration = 0
        appState.currentAudioLevel = 0
        appState.showWarning = false
        appState.statusMessage = "Recording cancelled"
    }
}
