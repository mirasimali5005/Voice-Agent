import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject var modelManager: WhisperModelManager
    let modelType: WhisperModelType
    let onComplete: () -> Void

    @State private var isDownloading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundColor(.red.opacity(0.8))

                VStack(spacing: 8) {
                    Text("Whisper Model Required")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Voice Dictation needs to download the \(modelType.displayName) model to transcribe speech.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 13))
                        .frame(maxWidth: 350)
                }

                if isDownloading {
                    VStack(spacing: 8) {
                        ProgressView(value: modelManager.downloadProgress)
                            .tint(.red)
                            .frame(width: 280)

                        Text("\(Int(modelManager.downloadProgress * 100))%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(maxWidth: 350)
                }

                if !isDownloading {
                    Button("Download Model") {
                        startDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red.opacity(0.8))
                    .controlSize(.large)
                }
            }
            .padding(40)
        }
        .preferredColorScheme(.dark)
        .frame(width: 500, height: 350)
    }

    private func startDownload() {
        isDownloading = true
        errorMessage = nil

        Task {
            do {
                try await modelManager.downloadModel(modelType)
                await MainActor.run {
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    errorMessage = "Download failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
