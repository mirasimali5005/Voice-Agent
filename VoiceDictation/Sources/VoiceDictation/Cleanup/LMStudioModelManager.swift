import Foundation

/// Represents a model available in LM Studio
struct LMModel: Identifiable, Hashable {
    let id: String   // e.g. "deepseek/deepseek-r1-0528-qwen3-8b"
    let params: String // e.g. "8B"
    let arch: String   // e.g. "qwen3"
    let size: String   // e.g. "4.62 GB"
}

/// Manages LM Studio models via the `lms` CLI
final class LMStudioModelManager: ObservableObject {
    static let shared = LMStudioModelManager()

    @Published var availableModels: [LMModel] = []
    @Published var loadedModelName: String = "None"
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let lmsPath: String
    private var pollTimer: DispatchSourceTimer?

    private init() {
        // Find lms binary
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        lmsPath = "\(home)/.lmstudio/bin/lms"

        // Start polling loaded model every 5s
        startPolling()
    }

    // MARK: - Polling

    private func startPolling() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: .seconds(5))
        timer.setEventHandler { [weak self] in
            self?.refreshLoadedModel()
        }
        timer.resume()
        pollTimer = timer
    }

    // MARK: - Refresh loaded model

    func refreshLoadedModel() {
        let output = runLMS(["ps"])
        let name: String
        if output.contains("No models") {
            name = "None"
        } else {
            // Parse the loaded model name from lms ps output
            // Format: table with model paths
            let lines = output.components(separatedBy: "\n")
            var modelName = "Unknown"
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Skip headers and empty lines
                if trimmed.isEmpty || trimmed.starts(with: "Loaded") || trimmed.starts(with: "---") || trimmed.starts(with: "TYPE") || trimmed.starts(with: "LLM") || trimmed.starts(with: "EMBEDDING") {
                    continue
                }
                // The model identifier is typically the first non-whitespace token
                let parts = trimmed.split(separator: " ", maxSplits: 1)
                if let first = parts.first {
                    let candidate = String(first)
                    // Skip if it looks like a column header
                    if candidate.count > 3 && !candidate.allSatisfy({ $0.isUppercase || $0 == "_" }) {
                        modelName = candidate
                        break
                    }
                }
            }
            name = modelName
        }
        DispatchQueue.main.async { [weak self] in
            self?.loadedModelName = name
        }
    }

    // MARK: - List available models

    func refreshAvailableModels() {
        let output = runLMS(["ls"])
        var models: [LMModel] = []

        let lines = output.components(separatedBy: "\n")
        var inLLMSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "LLM") && trimmed.contains("PARAMS") {
                inLLMSection = true
                continue
            }
            if trimmed.starts(with: "EMBEDDING") {
                inLLMSection = false
                continue
            }

            if inLLMSection && !trimmed.isEmpty {
                // Parse: "deepseek/deepseek-r1-0528-qwen3-8b (1 variant)    8B        qwen3      4.62 GB     Local"
                let components = trimmed.components(separatedBy: "     ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

                if components.count >= 3 {
                    var name = components[0]
                    // Remove "(N variant)" suffix
                    if let parenRange = name.range(of: " (") {
                        name = String(name[..<parenRange.lowerBound])
                    }

                    let params = components.count > 1 ? components[1] : "?"
                    let arch = components.count > 2 ? components[2] : "?"
                    let size = components.count > 3 ? components[3] : "?"

                    models.append(LMModel(id: name, params: params, arch: arch, size: size))
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.availableModels = models
        }
    }

    // MARK: - Load/Unload

    func loadModel(_ modelId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = true
            self?.error = nil
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Unload current model first
            let psOutput = self.runLMS(["ps"])
            if !psOutput.contains("No models") {
                _ = self.runLMS(["unload", "--all"])
                Thread.sleep(forTimeInterval: 1)
            }

            // Load new model
            let result = self.runLMS(["load", modelId, "--gpu", "max", "-y"])

            DispatchQueue.main.async {
                self.isLoading = false
                if result.lowercased().contains("error") || result.lowercased().contains("fail") {
                    self.error = "Failed to load model: \(result)"
                } else {
                    self.error = nil
                }
            }

            // Refresh after a moment
            Thread.sleep(forTimeInterval: 2)
            self.refreshLoadedModel()
        }
    }

    func unloadAll() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = self?.runLMS(["unload", "--all"])
            Thread.sleep(forTimeInterval: 1)
            self?.refreshLoadedModel()
        }
    }

    // MARK: - CLI Helper

    private func runLMS(_ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: lmsPath)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
