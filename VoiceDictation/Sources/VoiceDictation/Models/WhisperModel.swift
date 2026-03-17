import Foundation

enum WhisperModelType: String, CaseIterable, Identifiable {
    case largev3Turbo
    case largev3

    var id: String { rawValue }

    var filename: String {
        switch self {
        case .largev3Turbo:
            return "ggml-large-v3-turbo.bin"
        case .largev3:
            return "ggml-large-v3.bin"
        }
    }

    var displayName: String {
        switch self {
        case .largev3Turbo:
            return "Large V3 Turbo"
        case .largev3:
            return "Large V3"
        }
    }

    var downloadURL: URL {
        switch self {
        case .largev3Turbo:
            return URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!
        case .largev3:
            return URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin")!
        }
    }
}

final class WhisperModelManager: ObservableObject {
    static let shared = WhisperModelManager()

    @Published var downloadProgress: Double = 0.0

    let modelsDirectory: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport
            .appendingPathComponent("VoiceDictation", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    func modelPath(for type: WhisperModelType) -> String {
        modelsDirectory.appendingPathComponent(type.filename).path
    }

    func isModelAvailable(_ type: WhisperModelType) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(for: type))
    }

    func downloadModel(_ type: WhisperModelType) async throws {
        let destination = modelsDirectory.appendingPathComponent(type.filename)

        await MainActor.run {
            downloadProgress = 0.0
        }

        let (tempURL, response) = try await URLSession.shared.download(from: type.downloadURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // Move downloaded file to destination, replacing if needed
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: tempURL, to: destination)

        await MainActor.run {
            downloadProgress = 1.0
        }
    }
}
