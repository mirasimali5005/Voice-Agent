import Foundation

/// A cleanup backend that uses a local MLX model for on-device transcript cleanup.
///
/// The engine runs mlx_lm via a Python subprocess to generate cleaned text.
/// The model must be downloaded first using `scripts/convert-llama-coreml.py`.
/// If the model is not found, the engine reports itself as unavailable,
/// allowing the caller to fall back to another backend (e.g. LM Studio).
public final class CoreMLEngine: CleanupBackend, @unchecked Sendable {
    public let backendName = "MLX (Local)"

    /// Default model path inside Application Support.
    public static let defaultModelPath: String = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("VoiceDictation/models/cleanup-llm-mlx")
            .path
    }()

    private let modelPath: String
    private let pythonPath: String

    // MARK: - Init

    public init(modelPath: String = CoreMLEngine.defaultModelPath) {
        self.modelPath = modelPath
        // Find python3 — try common locations
        let candidates = [
            "/opt/miniconda3/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
        self.pythonPath = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "python3"
    }

    // MARK: - CleanupBackend

    public func isAvailable() async -> Bool {
        // Check if the MLX model directory exists and has model files
        let modelDir = URL(fileURLWithPath: modelPath)
        let configPath = modelDir.appendingPathComponent("config.json").path
        return FileManager.default.fileExists(atPath: configPath)
    }

    public func complete(systemPrompt: String, userMessage: String) async -> Result<String, Error> {
        guard await isAvailable() else {
            return .failure(CleanupBackendError.modelNotFound(path: modelPath))
        }

        do {
            let result = try await runMLXGenerate(systemPrompt: systemPrompt, userMessage: userMessage)
            return .success(result)
        } catch {
            return .failure(CleanupBackendError.predictionFailed(underlying: error.localizedDescription))
        }
    }

    // MARK: - MLX Generation

    /// Runs mlx_lm generate via a Python subprocess.
    private func runMLXGenerate(systemPrompt: String, userMessage: String) async throws -> String {
        // Create a small Python script that loads the model and generates text
        let pythonScript = """
        import sys, json
        from mlx_lm import load, generate

        model_path = sys.argv[1]
        system_prompt = sys.argv[2]
        user_message = sys.argv[3]

        model, tokenizer = load(model_path)

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ]

        prompt = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        result = generate(model, tokenizer, prompt=prompt, max_tokens=2048, temp=0.3)

        # Print only the result — no extra text
        print(result.strip())
        """

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: self.pythonPath)
                process.arguments = ["-c", pythonScript, self.modelPath, systemPrompt, userMessage]

                // Suppress stderr (mlx prints progress bars)
                let stderrPipe = Pipe()
                process.standardError = stderrPipe

                let stdoutPipe = Pipe()
                process.standardOutput = stdoutPipe

                // Set a timeout
                let timeoutSeconds: Double = 30
                let timer = DispatchSource.makeTimerSource(queue: .global())
                timer.schedule(deadline: .now() + timeoutSeconds)
                timer.setEventHandler {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                timer.resume()

                do {
                    try process.run()
                    process.waitUntilExit()
                    timer.cancel()

                    if process.terminationStatus == 0 {
                        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !output.isEmpty {
                            continuation.resume(returning: output)
                        } else {
                            continuation.resume(throwing: CleanupBackendError.predictionFailed(
                                underlying: "MLX returned empty output"
                            ))
                        }
                    } else {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: CleanupBackendError.predictionFailed(
                            underlying: "MLX process exited with code \(process.terminationStatus): \(errStr.prefix(200))"
                        ))
                    }
                } catch {
                    timer.cancel()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
