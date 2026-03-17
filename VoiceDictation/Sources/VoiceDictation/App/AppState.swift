import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastDictation: String = ""
    @Published var statusMessage: String = ""
    @Published var showWarning: Bool = false
    @Published var currentAudioLevel: Float = 0

    @AppStorage("lmStudioEndpoint") var lmStudioEndpoint: String = "http://localhost:1234"
    @AppStorage("lmStudioModel") var lmStudioModel: String = "qwen2.5-7b-instruct"
    @AppStorage("whisperModelType") var whisperModelType: String = "ggml-large-v3-turbo"
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
}
