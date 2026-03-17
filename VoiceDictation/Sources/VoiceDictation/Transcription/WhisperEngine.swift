import Foundation
import CWhisper

enum WhisperEngineError: Error, LocalizedError {
    case modelLoadFailed(path: String)
    case transcriptionFailed(code: Int32)

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let path):
            return "Failed to load Whisper model at path: \(path)"
        case .transcriptionFailed(let code):
            return "Whisper transcription failed with code: \(code)"
        }
    }
}

final class WhisperEngine: @unchecked Sendable {
    private let context: OpaquePointer
    /// Serial queue to prevent concurrent whisper_full calls (NOT thread-safe on same context)
    private let processingQueue = DispatchQueue(label: "com.voicedictation.whisper", qos: .userInitiated)

    init(modelPath: String) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperEngineError.modelLoadFailed(path: modelPath)
        }

        var contextParams = whisper_context_default_params()
        contextParams.use_gpu = true

        guard let ctx = whisper_init_from_file_with_params(modelPath, contextParams) else {
            throw WhisperEngineError.modelLoadFailed(path: modelPath)
        }

        self.context = ctx
    }

    deinit {
        whisper_free(context)
    }

    func transcribe(audioSamples: [Float], chunkIndex: Int) async throws -> TranscriptResult {
        // Dispatch to serial queue so whisper_full is never called concurrently
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TranscriptResult, Error>) in
            processingQueue.async { [self] in
                let startTime = CFAbsoluteTimeGetCurrent()

                var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
                params.print_progress = false
                params.print_timestamps = false
                let langCString = strdup("en")
                params.language = UnsafePointer(langCString)

                let threadCount = max(1, Int32(ProcessInfo.processInfo.processorCount - 2))
                params.n_threads = threadCount

                let result = audioSamples.withUnsafeBufferPointer { buffer -> Int32 in
                    guard let baseAddress = buffer.baseAddress else { return -1 }
                    return whisper_full(self.context, params, baseAddress, Int32(audioSamples.count))
                }

                free(langCString)

                guard result == 0 else {
                    continuation.resume(throwing: WhisperEngineError.transcriptionFailed(code: result))
                    return
                }

                let segmentCount = whisper_full_n_segments(self.context)
                var transcribedText = ""

                for i in 0..<segmentCount {
                    if let cString = whisper_full_get_segment_text(self.context, i) {
                        transcribedText += String(cString: cString)
                    }
                }

                let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

                continuation.resume(returning: TranscriptResult(
                    text: transcribedText.trimmingCharacters(in: .whitespaces),
                    isPartial: false,
                    chunkIndex: chunkIndex,
                    processingTimeMs: elapsedMs
                ))
            }
        }
    }
}
