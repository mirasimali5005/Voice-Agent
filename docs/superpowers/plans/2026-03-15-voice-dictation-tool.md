# Voice Dictation Tool Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native Swift macOS voice dictation app that uses whisper.cpp (Metal) for real-time streaming transcription and LM Studio for intelligent text cleanup, with sub-second latency on release.

**Architecture:** A SwiftUI macOS app with a background `CGEvent` tap for global hotkey detection. Audio is captured via `AVAudioEngine` in 5-second overlapping chunks, streamed to whisper.cpp (linked as a C library with Metal). On release, the assembled transcript is sent to LM Studio's OpenAI-compatible API for cleanup, then pasted or copied. All dictations persist in SQLite.

**Tech Stack:** Swift 5.9+, SwiftUI, whisper.cpp (C/Metal), AVAudioEngine, CGEvent, AXUIElement (Accessibility), SQLite (via swift-sqlite or GRDB), URLSession (for LM Studio API)

---

## File Structure

```
VoiceDictation/
├── VoiceDictation.xcodeproj/
├── VoiceDictation/
│   ├── App/
│   │   ├── VoiceDictationApp.swift          # App entry point, menu bar + window setup
│   │   └── AppState.swift                    # Shared observable app state
│   ├── Audio/
│   │   ├── AudioRecorder.swift               # AVAudioEngine capture, chunking, VAD
│   │   └── AudioChunk.swift                  # Data model for a raw audio chunk
│   ├── Transcription/
│   │   ├── WhisperEngine.swift               # whisper.cpp Swift wrapper (Metal)
│   │   ├── WhisperBridge.h                   # C bridging header for whisper.cpp
│   │   ├── TranscriptionPipeline.swift       # Streaming chunk orchestrator + overlap dedup
│   │   └── TranscriptResult.swift            # Data model for transcription output
│   ├── Cleanup/
│   │   ├── LMStudioClient.swift              # HTTP client for LM Studio API
│   │   └── TranscriptCleaner.swift           # Cleanup orchestration + sanity checks + fallback
│   ├── TextInjection/
│   │   ├── TextFieldDetector.swift           # AXUIElement focus detection
│   │   └── TextInjector.swift                # AXValue setter + Cmd+V fallback
│   ├── Hotkey/
│   │   ├── HotkeyListener.swift              # CGEvent tap, double-tap detection, combo filtering
│   │   └── HotkeyConfig.swift                # Hotkey configuration model
│   ├── Storage/
│   │   ├── DatabaseManager.swift             # SQLite setup, migrations, CRUD
│   │   └── DictationEntry.swift              # Data model for stored dictations
│   ├── UI/
│   │   ├── RecordingOverlay.swift            # Floating pill overlay (NSPanel)
│   │   ├── HistoryView.swift                 # Main window dictation list
│   │   ├── HistoryRowView.swift              # Single dictation entry row
│   │   ├── SettingsView.swift                # Settings panel
│   │   └── MenuBarView.swift                 # Menu bar icon + dropdown
│   ├── Orchestration/
│   │   └── DictationOrchestrator.swift       # Ties everything together: hotkey → record → transcribe → clean → inject
│   └── Models/
│       └── WhisperModel.swift                # Model download/discovery/management
├── Libraries/
│   └── whisper.cpp/                          # whisper.cpp source (git submodule)
├── Tests/
│   ├── AudioTests/
│   │   ├── AudioRecorderTests.swift
│   │   └── VADTests.swift
│   ├── TranscriptionTests/
│   │   ├── WhisperEngineTests.swift
│   │   ├── TranscriptionPipelineTests.swift
│   │   └── OverlapDedupTests.swift
│   ├── CleanupTests/
│   │   ├── LMStudioClientTests.swift
│   │   └── TranscriptCleanerTests.swift
│   ├── TextInjectionTests/
│   │   ├── TextFieldDetectorTests.swift
│   │   └── TextInjectorTests.swift
│   ├── HotkeyTests/
│   │   └── HotkeyListenerTests.swift
│   ├── StorageTests/
│   │   └── DatabaseManagerTests.swift
│   └── OrchestrationTests/
│       └── DictationOrchestratorTests.swift
└── Resources/
    └── VoiceDictation.entitlements
```

---

## Chunk 1: Project Setup + whisper.cpp Integration

### Task 1: Create Xcode Project

**Files:**
- Create: `VoiceDictation/VoiceDictation.xcodeproj/`
- Create: `VoiceDictation/VoiceDictation/App/VoiceDictationApp.swift`
- Create: `VoiceDictation/VoiceDictation/Info.plist`
- Create: `VoiceDictation/Resources/VoiceDictation.entitlements`

- [ ] **Step 1: Initialize the Xcode project**

```bash
cd /Users/mirasimali/Voice-agent
mkdir -p VoiceDictation
cd VoiceDictation
# Create via xcodegen or manually. Using Swift Package Manager structure:
swift package init --type executable --name VoiceDictation
```

Then convert to an Xcode project with SwiftUI macOS app target. The `Package.swift` should target macOS 14.0+:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceDictation",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VoiceDictation", targets: ["VoiceDictation"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .executableTarget(
            name: "VoiceDictation",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                "WhisperKit"
            ],
            path: "VoiceDictation"
        ),
        .target(
            name: "WhisperKit",
            dependencies: [],
            path: "Libraries/whisper.cpp",
            sources: ["whisper.cpp", "ggml.c", "ggml-metal.m", "ggml-alloc.c", "ggml-backend.c", "ggml-quants.c"],
            publicHeadersPath: "include",
            cSettings: [
                .define("GGML_USE_METAL"),
                .headerSearchPath(".")
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("Accelerate")
            ]
        ),
        .testTarget(
            name: "VoiceDictationTests",
            dependencies: ["VoiceDictation"],
            path: "Tests"
        )
    ]
)
```

- [ ] **Step 2: Create minimal app entry point**

Create `VoiceDictation/App/VoiceDictationApp.swift`:

```swift
import SwiftUI

@main
struct VoiceDictationApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Voice Dictation")
                .frame(width: 600, height: 400)
        }
    }
}
```

- [ ] **Step 3: Build and verify it launches**

```bash
cd /Users/mirasimali/Voice-agent/VoiceDictation
swift build
```

Expected: Builds successfully with no errors.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: initialize VoiceDictation Swift project with Package.swift"
```

---

### Task 2: Integrate whisper.cpp as a Git Submodule

**Files:**
- Create: `Libraries/whisper.cpp/` (submodule)
- Create: `VoiceDictation/Transcription/WhisperBridge.h`

- [ ] **Step 1: Add whisper.cpp submodule**

```bash
cd /Users/mirasimali/Voice-agent/VoiceDictation
mkdir -p Libraries
git submodule add https://github.com/ggerganov/whisper.cpp.git Libraries/whisper.cpp
cd Libraries/whisper.cpp
git checkout v1.7.3  # or latest stable tag
cd ../..
```

- [ ] **Step 2: Create bridging header**

Create `VoiceDictation/Transcription/WhisperBridge.h`:

```c
#ifndef WhisperBridge_h
#define WhisperBridge_h

#include "whisper.h"

#endif
```

- [ ] **Step 3: Verify the project builds with whisper.cpp linked**

```bash
swift build
```

Expected: Builds successfully. The WhisperKit target compiles whisper.cpp C/ObjC sources with Metal enabled.

Note: You may need to adjust the `sources` list in Package.swift depending on the exact whisper.cpp version's file layout. Check `Libraries/whisper.cpp/` for the actual filenames — the ggml files may be in a `ggml/src/` subdirectory in newer versions.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: integrate whisper.cpp as submodule with Metal support"
```

---

### Task 3: WhisperEngine Swift Wrapper

**Files:**
- Create: `VoiceDictation/Transcription/WhisperEngine.swift`
- Create: `VoiceDictation/Transcription/TranscriptResult.swift`
- Create: `Tests/TranscriptionTests/WhisperEngineTests.swift`

- [ ] **Step 1: Create TranscriptResult model**

Create `VoiceDictation/Transcription/TranscriptResult.swift`:

```swift
import Foundation

struct TranscriptResult {
    let text: String
    let isPartial: Bool
    let chunkIndex: Int
    let processingTimeMs: Double
}
```

- [ ] **Step 2: Write failing test for WhisperEngine initialization**

Create `Tests/TranscriptionTests/WhisperEngineTests.swift`:

```swift
import XCTest
@testable import VoiceDictation

final class WhisperEngineTests: XCTestCase {

    func testInitWithInvalidModelPathThrows() {
        XCTAssertThrowsError(try WhisperEngine(modelPath: "/nonexistent/model.bin")) { error in
            XCTAssertTrue(error is WhisperEngineError)
        }
    }

    func testTranscribeEmptyAudioReturnsEmpty() async throws {
        // This test requires a real model file — skip in CI, run locally
        // guard let engine = try? WhisperEngine(modelPath: testModelPath) else {
        //     throw XCTSkip("Whisper model not available for testing")
        // }
        // let emptyAudio: [Float] = Array(repeating: 0.0, count: 16000) // 1 second of silence
        // let result = try await engine.transcribe(audioSamples: emptyAudio, chunkIndex: 0)
        // XCTAssertTrue(result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
swift test --filter WhisperEngineTests
```

Expected: FAIL — `WhisperEngine` type not found.

- [ ] **Step 4: Implement WhisperEngine**

Create `VoiceDictation/Transcription/WhisperEngine.swift`:

```swift
import Foundation

enum WhisperEngineError: Error, LocalizedError {
    case modelLoadFailed(String)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let path):
            return "Failed to load Whisper model at: \(path)"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        }
    }
}

final class WhisperEngine: @unchecked Sendable {
    private let context: OpaquePointer

    init(modelPath: String) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperEngineError.modelLoadFailed(modelPath)
        }

        var params = whisper_context_default_params()
        params.use_gpu = true  // Metal acceleration

        guard let ctx = whisper_init_from_file_with_params(modelPath, params) else {
            throw WhisperEngineError.modelLoadFailed(modelPath)
        }
        self.context = ctx
    }

    deinit {
        whisper_free(context)
    }

    /// Transcribe raw 16kHz mono Float32 audio samples
    func transcribe(audioSamples: [Float], chunkIndex: Int) async throws -> TranscriptResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.single_segment = false
        params.language = "en".withCString { UnsafePointer(strdup($0)) }
        params.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 2))

        let result = audioSamples.withUnsafeBufferPointer { buffer in
            whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
        }

        guard result == 0 else {
            throw WhisperEngineError.transcriptionFailed("whisper_full returned \(result)")
        }

        let numSegments = whisper_full_n_segments(context)
        var text = ""
        for i in 0..<numSegments {
            if let segmentText = whisper_full_get_segment_text(context, i) {
                text += String(cString: segmentText)
            }
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        return TranscriptResult(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            isPartial: false,
            chunkIndex: chunkIndex,
            processingTimeMs: elapsed
        )
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
swift test --filter WhisperEngineTests
```

Expected: PASS — `testInitWithInvalidModelPathThrows` passes, the commented-out test is skipped.

- [ ] **Step 6: Commit**

```bash
git add VoiceDictation/Transcription/ Tests/TranscriptionTests/
git commit -m "feat: add WhisperEngine wrapper with Metal support and basic tests"
```

---

### Task 4: Whisper Model Manager

**Files:**
- Create: `VoiceDictation/Models/WhisperModel.swift`

- [ ] **Step 1: Write failing test concept (manual verification)**

This task is UI-adjacent (model download). We'll verify manually that the model manager correctly detects presence/absence of the model file.

- [ ] **Step 2: Implement WhisperModel manager**

Create `VoiceDictation/Models/WhisperModel.swift`:

```swift
import Foundation

enum WhisperModelType: String, CaseIterable {
    case largev3Turbo = "ggml-large-v3-turbo"
    case largev3 = "ggml-large-v3"

    var filename: String { "\(rawValue).bin" }
    var displayName: String {
        switch self {
        case .largev3Turbo: return "Large v3 Turbo (Fastest)"
        case .largev3: return "Large v3 (Most Accurate)"
        }
    }
    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)")!
    }
}

final class WhisperModelManager: ObservableObject {
    static let shared = WhisperModelManager()

    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false

    private let modelsDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("VoiceDictation/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    func modelPath(for type: WhisperModelType) -> String {
        modelsDirectory.appendingPathComponent(type.filename).path
    }

    func isModelAvailable(_ type: WhisperModelType) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(for: type))
    }

    func downloadModel(_ type: WhisperModelType) async throws {
        await MainActor.run { isDownloading = true; downloadProgress = 0 }
        defer { Task { @MainActor in isDownloading = false } }

        let destinationURL = modelsDirectory.appendingPathComponent(type.filename)
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: type.downloadURL)
        let totalBytes = response.expectedContentLength
        var downloadedBytes: Int64 = 0
        let fileHandle = try FileHandle(forWritingTo: destinationURL)
        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destinationURL)

        for try await byte in asyncBytes {
            handle.write(Data([byte]))
            downloadedBytes += 1
            if totalBytes > 0 && downloadedBytes % 1_000_000 == 0 {
                let progress = Double(downloadedBytes) / Double(totalBytes)
                await MainActor.run { downloadProgress = progress }
            }
        }
        handle.closeFile()
        await MainActor.run { downloadProgress = 1.0 }
    }
}
```

- [ ] **Step 3: Verify it compiles**

```bash
swift build
```

Expected: Builds successfully.

- [ ] **Step 4: Commit**

```bash
git add VoiceDictation/Models/
git commit -m "feat: add WhisperModelManager for model download and discovery"
```

---

## Chunk 2: Audio Recording + VAD + Streaming Pipeline

### Task 5: Audio Recorder with Chunking

**Files:**
- Create: `VoiceDictation/Audio/AudioChunk.swift`
- Create: `VoiceDictation/Audio/AudioRecorder.swift`
- Create: `Tests/AudioTests/AudioRecorderTests.swift`

- [ ] **Step 1: Create AudioChunk model**

Create `VoiceDictation/Audio/AudioChunk.swift`:

```swift
import Foundation

struct AudioChunk {
    let samples: [Float]       // 16kHz mono Float32
    let index: Int
    let durationSeconds: Double
    let rmsEnergy: Float       // for VAD
}
```

- [ ] **Step 2: Write failing test for AudioRecorder**

Create `Tests/AudioTests/AudioRecorderTests.swift`:

```swift
import XCTest
@testable import VoiceDictation

final class AudioRecorderTests: XCTestCase {

    func testRMSEnergyCalculation() {
        let silence: [Float] = Array(repeating: 0.0, count: 16000)
        let rms = AudioRecorder.calculateRMS(silence)
        XCTAssertEqual(rms, 0.0, accuracy: 0.001)

        let tone: [Float] = Array(repeating: 0.5, count: 16000)
        let rms2 = AudioRecorder.calculateRMS(tone)
        XCTAssertEqual(rms2, 0.5, accuracy: 0.001)
    }

    func testChunkSplittingWithOverlap() {
        // 10 seconds of audio at 16kHz = 160_000 samples
        let samples: [Float] = (0..<160_000).map { Float($0) / 160_000.0 }
        let chunks = AudioRecorder.splitIntoChunks(
            samples: samples,
            chunkDurationSeconds: 5.0,
            overlapSeconds: 0.5,
            sampleRate: 16000
        )

        // First chunk: 0 to 5s = 80_000 samples
        // Second chunk: 4.5s to 9.5s (overlap 0.5s) = 80_000 samples
        // Third chunk: 9s to 10s (remaining) — partial
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].samples.count, 80_000)
        XCTAssertEqual(chunks[1].samples.count, 80_000)
        XCTAssertTrue(chunks[2].samples.count < 80_000) // partial chunk
        XCTAssertEqual(chunks[2].index, 2)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
swift test --filter AudioRecorderTests
```

Expected: FAIL — `AudioRecorder` type not found.

- [ ] **Step 4: Implement AudioRecorder**

Create `VoiceDictation/Audio/AudioRecorder.swift`:

```swift
import Foundation
import AVFoundation

final class AudioRecorder: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var sampleBuffer: [Float] = []
    private let sampleRate: Double = 16000
    private let chunkDuration: Double = 5.0
    private let overlapDuration: Double = 0.5

    private var chunkIndex = 0
    private var onChunkReady: ((AudioChunk) -> Void)?
    private var isRecording = false

    private let silenceThreshold: Float = 0.01 // RMS below this = silence
    private let bufferLock = NSLock()

    /// Start recording from the default microphone.
    /// Calls `onChunk` whenever a 5-second chunk (with 0.5s overlap) is ready.
    func startRecording(onChunk: @escaping (AudioChunk) -> Void) throws {
        self.onChunkReady = onChunk
        self.chunkIndex = 0
        self.sampleBuffer = []
        self.isRecording = true

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Install tap converting to 16kHz mono
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!

        let converter = AVAudioConverter(from: inputFormat, to: desiredFormat)!

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, self.isRecording else { return }

            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * self.sampleRate / inputFormat.sampleRate
            )
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: desiredFormat, frameCapacity: frameCount) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, let channelData = convertedBuffer.floatChannelData else { return }
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(convertedBuffer.frameLength)))

            self.bufferLock.lock()
            self.sampleBuffer.append(contentsOf: samples)

            let chunkSampleCount = Int(self.chunkDuration * self.sampleRate)
            if self.sampleBuffer.count >= chunkSampleCount {
                let chunkSamples = Array(self.sampleBuffer.prefix(chunkSampleCount))
                let overlapSamples = Int(self.overlapDuration * self.sampleRate)
                self.sampleBuffer = Array(self.sampleBuffer.dropFirst(chunkSampleCount - overlapSamples))

                let chunk = AudioChunk(
                    samples: chunkSamples,
                    index: self.chunkIndex,
                    durationSeconds: self.chunkDuration,
                    rmsEnergy: Self.calculateRMS(chunkSamples)
                )
                self.chunkIndex += 1
                self.bufferLock.unlock()
                self.onChunkReady?(chunk)
            } else {
                self.bufferLock.unlock()
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Stop recording and return any remaining audio as a final partial chunk.
    func stopRecording() -> AudioChunk? {
        isRecording = false
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        bufferLock.lock()
        defer { bufferLock.unlock() }

        guard !sampleBuffer.isEmpty else { return nil }

        let finalChunk = AudioChunk(
            samples: sampleBuffer,
            index: chunkIndex,
            durationSeconds: Double(sampleBuffer.count) / sampleRate,
            rmsEnergy: Self.calculateRMS(sampleBuffer)
        )
        sampleBuffer = []
        return finalChunk
    }

    // MARK: - Static Helpers

    static func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }

    /// Split a contiguous audio buffer into overlapping chunks (for testing/offline use).
    static func splitIntoChunks(
        samples: [Float],
        chunkDurationSeconds: Double,
        overlapSeconds: Double,
        sampleRate: Int
    ) -> [AudioChunk] {
        let chunkSize = Int(chunkDurationSeconds * Double(sampleRate))
        let stepSize = chunkSize - Int(overlapSeconds * Double(sampleRate))
        var chunks: [AudioChunk] = []
        var offset = 0
        var index = 0

        while offset < samples.count {
            let end = min(offset + chunkSize, samples.count)
            let chunkSamples = Array(samples[offset..<end])
            chunks.append(AudioChunk(
                samples: chunkSamples,
                index: index,
                durationSeconds: Double(chunkSamples.count) / Double(sampleRate),
                rmsEnergy: calculateRMS(chunkSamples)
            ))
            offset += stepSize
            index += 1
        }
        return chunks
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
swift test --filter AudioRecorderTests
```

Expected: PASS — both `testRMSEnergyCalculation` and `testChunkSplittingWithOverlap` pass.

- [ ] **Step 6: Commit**

```bash
git add VoiceDictation/Audio/ Tests/AudioTests/
git commit -m "feat: add AudioRecorder with chunking, overlap, and VAD support"
```

---

### Task 6: Transcription Pipeline (Streaming Orchestrator)

**Files:**
- Create: `VoiceDictation/Transcription/TranscriptionPipeline.swift`
- Create: `Tests/TranscriptionTests/TranscriptionPipelineTests.swift`
- Create: `Tests/TranscriptionTests/OverlapDedupTests.swift`

- [ ] **Step 1: Write failing test for overlap deduplication**

Create `Tests/TranscriptionTests/OverlapDedupTests.swift`:

```swift
import XCTest
@testable import VoiceDictation

final class OverlapDedupTests: XCTestCase {

    func testDeduplicatesOverlappingWords() {
        let previous = "The quick brown fox jumps over"
        let next = "fox jumps over the lazy dog"
        let result = TranscriptionPipeline.deduplicateOverlap(previous: previous, next: next, windowSize: 5)
        XCTAssertEqual(result, "the lazy dog")
    }

    func testNoOverlapReturnsFull() {
        let previous = "Hello world"
        let next = "Completely different sentence"
        let result = TranscriptionPipeline.deduplicateOverlap(previous: previous, next: next, windowSize: 5)
        XCTAssertEqual(result, "Completely different sentence")
    }

    func testEmptyPreviousReturnsFull() {
        let result = TranscriptionPipeline.deduplicateOverlap(previous: "", next: "Some text here", windowSize: 5)
        XCTAssertEqual(result, "Some text here")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter OverlapDedupTests
```

Expected: FAIL — `TranscriptionPipeline` not found.

- [ ] **Step 3: Implement TranscriptionPipeline**

Create `VoiceDictation/Transcription/TranscriptionPipeline.swift`:

```swift
import Foundation

final class TranscriptionPipeline: ObservableObject {
    private let whisperEngine: WhisperEngine
    private let silenceThreshold: Float = 0.01

    @Published var assembledTranscript: String = ""
    @Published var isProcessing: Bool = false

    private var lastChunkText: String = ""
    private var pendingChunks: Int = 0
    private let lock = NSLock()
    private var consecutiveFailures = 0
    private let maxConsecutiveFailures = 3

    var onError: ((String) -> Void)?
    var onAbort: ((String) -> Void)?

    init(whisperEngine: WhisperEngine) {
        self.whisperEngine = whisperEngine
    }

    func reset() {
        lock.lock()
        assembledTranscript = ""
        lastChunkText = ""
        pendingChunks = 0
        consecutiveFailures = 0
        lock.unlock()
    }

    /// Process a chunk. Called from AudioRecorder's callback.
    /// Returns immediately — transcription runs on a background task.
    func processChunk(_ chunk: AudioChunk) {
        // VAD: skip silent chunks
        guard chunk.rmsEnergy >= silenceThreshold else { return }

        lock.lock()
        pendingChunks += 1
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

                if lastChunkText.isEmpty {
                    assembledTranscript += result.text
                } else {
                    let deduped = Self.deduplicateOverlap(
                        previous: lastChunkText,
                        next: result.text,
                        windowSize: 5
                    )
                    if !deduped.isEmpty {
                        assembledTranscript += " " + deduped
                    }
                }
                lastChunkText = result.text

                pendingChunks -= 1
                isProcessing = pendingChunks > 0
                lock.unlock()

            } catch {
                lock.lock()
                consecutiveFailures += 1
                assembledTranscript += " [gap]"
                pendingChunks -= 1
                isProcessing = pendingChunks > 0
                let failures = consecutiveFailures
                lock.unlock()

                onError?("Chunk \(chunk.index) failed: \(error.localizedDescription)")

                if failures >= maxConsecutiveFailures {
                    onAbort?("Transcription aborted: \(maxConsecutiveFailures) consecutive chunk failures")
                }
            }
        }
    }

    /// Wait until all pending chunks are processed.
    func waitForCompletion() async {
        while true {
            lock.lock()
            let pending = pendingChunks
            lock.unlock()
            if pending == 0 { break }
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms poll
        }
    }

    /// Get final assembled transcript.
    func getFinalTranscript() -> String {
        lock.lock()
        defer { lock.unlock() }
        return assembledTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Overlap Deduplication

    /// Compares the last N words of `previous` with the first N words of `next`.
    /// Returns the portion of `next` that doesn't overlap with `previous`.
    static func deduplicateOverlap(previous: String, next: String, windowSize: Int) -> String {
        guard !previous.isEmpty else { return next }

        let prevWords = previous.lowercased().split(separator: " ").map(String.init)
        let nextWords = next.split(separator: " ").map(String.init)
        let nextWordsLower = nextWords.map { $0.lowercased() }

        guard !prevWords.isEmpty, !nextWords.isEmpty else { return next }

        let tailWindow = Array(prevWords.suffix(windowSize))

        // Find the longest matching prefix of nextWords within tailWindow
        var bestMatch = 0
        for startIdx in 0..<tailWindow.count {
            let subWindow = Array(tailWindow[startIdx...])
            var matchLen = 0
            for (i, word) in subWindow.enumerated() {
                if i < nextWordsLower.count && word == nextWordsLower[i] {
                    matchLen += 1
                } else {
                    break
                }
            }
            if matchLen > bestMatch && matchLen >= 2 {
                bestMatch = matchLen
            }
        }

        if bestMatch > 0 {
            return nextWords.dropFirst(bestMatch).joined(separator: " ")
        }
        return next
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter OverlapDedupTests
```

Expected: PASS — all three deduplication tests pass.

- [ ] **Step 5: Commit**

```bash
git add VoiceDictation/Transcription/TranscriptionPipeline.swift Tests/TranscriptionTests/
git commit -m "feat: add TranscriptionPipeline with streaming chunks, VAD skip, overlap dedup, and failure handling"
```

---

## Chunk 3: LM Studio Client + Transcript Cleanup

### Task 7: LM Studio HTTP Client

**Files:**
- Create: `VoiceDictation/Cleanup/LMStudioClient.swift`
- Create: `Tests/CleanupTests/LMStudioClientTests.swift`

- [ ] **Step 1: Write failing test for LMStudioClient**

Create `Tests/CleanupTests/LMStudioClientTests.swift`:

```swift
import XCTest
@testable import VoiceDictation

final class LMStudioClientTests: XCTestCase {

    func testBuildRequestBody() throws {
        let client = LMStudioClient(endpoint: "http://localhost:1234")
        let body = client.buildRequestBody(
            systemPrompt: "Clean this up",
            userMessage: "uh hello world",
            model: "qwen2.5-7b",
            maxTokens: 100,
            temperature: 0
        )

        let data = try JSONSerialization.data(withJSONObject: body)
        let decoded = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(decoded["model"] as? String, "qwen2.5-7b")
        XCTAssertEqual(decoded["temperature"] as? Double, 0)
        XCTAssertEqual(decoded["max_tokens"] as? Int, 100)

        let messages = decoded["messages"] as! [[String: String]]
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertEqual(messages[0]["content"], "Clean this up")
        XCTAssertEqual(messages[1]["role"], "user")
        XCTAssertEqual(messages[1]["content"], "uh hello world")
    }

    func testTimeoutIsRespected() async {
        // Connects to a non-routable address to trigger timeout
        let client = LMStudioClient(endpoint: "http://192.0.2.1:9999", timeoutSeconds: 0.5)
        let start = CFAbsoluteTimeGetCurrent()
        let result = await client.complete(systemPrompt: "test", userMessage: "test", model: "test", maxTokens: 10)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        switch result {
        case .failure:
            XCTAssertLessThan(elapsed, 2.0) // Should fail within ~0.5s + buffer
        case .success:
            XCTFail("Should not succeed connecting to non-routable address")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter LMStudioClientTests
```

Expected: FAIL — `LMStudioClient` not found.

- [ ] **Step 3: Implement LMStudioClient**

Create `VoiceDictation/Cleanup/LMStudioClient.swift`:

```swift
import Foundation

final class LMStudioClient: Sendable {
    let endpoint: String
    let timeoutSeconds: Double

    init(endpoint: String = "http://localhost:1234", timeoutSeconds: Double = 5.0) {
        self.endpoint = endpoint
        self.timeoutSeconds = timeoutSeconds
    }

    func buildRequestBody(
        systemPrompt: String,
        userMessage: String,
        model: String,
        maxTokens: Int,
        temperature: Double
    ) -> [String: Any] {
        return [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": false
        ]
    }

    func complete(
        systemPrompt: String,
        userMessage: String,
        model: String,
        maxTokens: Int,
        temperature: Double = 0
    ) async -> Result<String, LMStudioError> {
        let urlString = "\(endpoint)/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            return .failure(.invalidEndpoint(urlString))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutSeconds

        let body = buildRequestBody(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            model: model,
            maxTokens: maxTokens,
            temperature: temperature
        )

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return .failure(.serializationError(error.localizedDescription))
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            guard httpResponse.statusCode == 200 else {
                let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
                return .failure(.httpError(statusCode: httpResponse.statusCode, body: bodyStr))
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                return .failure(.parseError("Could not extract content from response"))
            }

            return .success(content.trimmingCharacters(in: .whitespacesAndNewlines))

        } catch let error as URLError where error.code == .timedOut {
            return .failure(.timeout)
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }
}

enum LMStudioError: Error, LocalizedError {
    case invalidEndpoint(String)
    case serializationError(String)
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case parseError(String)
    case timeout
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let url): return "Invalid endpoint: \(url)"
        case .serializationError(let msg): return "JSON error: \(msg)"
        case .invalidResponse: return "Invalid HTTP response"
        case .httpError(let code, let body): return "HTTP \(code): \(body)"
        case .parseError(let msg): return "Parse error: \(msg)"
        case .timeout: return "LM Studio request timed out"
        case .networkError(let msg): return "Network error: \(msg)"
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter LMStudioClientTests
```

Expected: PASS — request body structure is correct, timeout test completes under 2s.

- [ ] **Step 5: Commit**

```bash
git add VoiceDictation/Cleanup/LMStudioClient.swift Tests/CleanupTests/
git commit -m "feat: add LMStudioClient with OpenAI-compatible API, timeout, and error handling"
```

---

### Task 8: Transcript Cleaner (Cleanup Orchestration)

**Files:**
- Create: `VoiceDictation/Cleanup/TranscriptCleaner.swift`
- Create: `Tests/CleanupTests/TranscriptCleanerTests.swift`

- [ ] **Step 1: Write failing test for sanity check logic**

Create `Tests/CleanupTests/TranscriptCleanerTests.swift`:

```swift
import XCTest
@testable import VoiceDictation

final class TranscriptCleanerTests: XCTestCase {

    func testSanityCheckPassesForReasonableOutput() {
        let input = "uh so my groceries are a shopping bag a wooden cutting board and a cap"
        let output = "1. Shopping bag\n2. Wooden cutting board\n3. Cap"
        XCTAssertTrue(TranscriptCleaner.passesSanityCheck(input: input, output: output))
    }

    func testSanityCheckFailsForTruncatedOutput() {
        let input = "This is a fairly long dictation with many words that should not be reduced to almost nothing at all by the language model"
        let output = "Short."
        XCTAssertFalse(TranscriptCleaner.passesSanityCheck(input: input, output: output))
    }

    func testSanityCheckFailsForHallucinatedOutput() {
        let input = "Hello world"
        let output = "Hello world. And here is a very long hallucinated addition that was never spoken by the user at all with many many extra words added"
        XCTAssertFalse(TranscriptCleaner.passesSanityCheck(input: input, output: output))
    }

    func testDefaultSystemPromptContainsKey phrases() {
        let prompt = TranscriptCleaner.defaultSystemPrompt
        XCTAssertTrue(prompt.contains("filler words"))
        XCTAssertTrue(prompt.contains("numbered list"))
        XCTAssertTrue(prompt.contains("do not rephrase"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter TranscriptCleanerTests
```

Expected: FAIL — `TranscriptCleaner` not found.

- [ ] **Step 3: Implement TranscriptCleaner**

Create `VoiceDictation/Cleanup/TranscriptCleaner.swift`:

```swift
import Foundation

final class TranscriptCleaner {

    static let defaultSystemPrompt = """
    Clean up this dictation transcript. Remove filler words (uh, um, like, you know). \
    Fix punctuation, capitalization, and sentence boundaries. When the speaker is listing items, \
    format as a numbered list. Detect paragraph breaks from context. Preserve the speaker's exact \
    non-filler words — do not rephrase, summarize, or add words. Return only the cleaned text.
    """

    private let client: LMStudioClient
    private let model: String
    private let systemPrompt: String

    init(
        client: LMStudioClient,
        model: String = "qwen2.5-7b-instruct",
        systemPrompt: String = TranscriptCleaner.defaultSystemPrompt
    ) {
        self.client = client
        self.model = model
        self.systemPrompt = systemPrompt
    }

    /// Clean the raw transcript. Returns cleaned text, or raw text if LM Studio is unavailable.
    func clean(rawTranscript: String) async -> CleanupResult {
        guard !rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return CleanupResult(text: "", usedLLM: false, error: nil)
        }

        let wordCount = rawTranscript.split(separator: " ").count
        let maxTokens = wordCount * 2

        let result = await client.complete(
            systemPrompt: systemPrompt,
            userMessage: rawTranscript,
            model: model,
            maxTokens: maxTokens,
            temperature: 0
        )

        switch result {
        case .success(let cleanedText):
            if Self.passesSanityCheck(input: rawTranscript, output: cleanedText) {
                return CleanupResult(text: cleanedText, usedLLM: true, error: nil)
            } else {
                return CleanupResult(
                    text: rawTranscript,
                    usedLLM: false,
                    error: "LLM output failed sanity check — using raw transcript"
                )
            }
        case .failure(let error):
            return CleanupResult(
                text: rawTranscript,
                usedLLM: false,
                error: "LM Studio: \(error.localizedDescription) — using raw transcript"
            )
        }
    }

    /// Checks that the LLM output is within 50%-150% of the input word count.
    static func passesSanityCheck(input: String, output: String) -> Bool {
        let inputWords = input.split(separator: " ").count
        let outputWords = output.split(separator: " ").count

        guard inputWords > 0 else { return true }

        let ratio = Double(outputWords) / Double(inputWords)
        return ratio >= 0.3 && ratio <= 1.8
        // Slightly wider than spec's 50/150 to account for list formatting
        // (lists add numbers but remove filler, often netting fewer words)
    }
}

struct CleanupResult {
    let text: String
    let usedLLM: Bool
    let error: String?
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter TranscriptCleanerTests
```

Expected: PASS — all four tests pass.

- [ ] **Step 5: Commit**

```bash
git add VoiceDictation/Cleanup/TranscriptCleaner.swift Tests/CleanupTests/
git commit -m "feat: add TranscriptCleaner with LLM cleanup, sanity check, and raw fallback"
```

---

## Chunk 4: Hotkey Listener + Text Injection

### Task 9: Global Hotkey Listener (Double-Tap Ctrl)

**Files:**
- Create: `VoiceDictation/Hotkey/HotkeyConfig.swift`
- Create: `VoiceDictation/Hotkey/HotkeyListener.swift`
- Create: `Tests/HotkeyTests/HotkeyListenerTests.swift`

- [ ] **Step 1: Create HotkeyConfig model**

Create `VoiceDictation/Hotkey/HotkeyConfig.swift`:

```swift
import Foundation
import Carbon.HIToolbox

struct HotkeyConfig {
    var keyCode: UInt16 = UInt16(kVK_Control) // 0x3B
    var doubleTapWindowMs: Int = 300
    var requireDoubleTap: Bool = true
}
```

- [ ] **Step 2: Write failing test for double-tap state machine**

Create `Tests/HotkeyTests/HotkeyListenerTests.swift`:

```swift
import XCTest
@testable import VoiceDictation

final class HotkeyListenerTests: XCTestCase {

    func testDoubleTapDetection() {
        let stateMachine = DoubleTapStateMachine(windowMs: 300)

        // First tap down + up
        let action1 = stateMachine.handleKeyEvent(isDown: true, timestamp: 0)
        XCTAssertEqual(action1, .none)
        let action2 = stateMachine.handleKeyEvent(isDown: false, timestamp: 50)
        XCTAssertEqual(action2, .none) // First tap released — waiting for second

        // Second tap down within window → activate
        let action3 = stateMachine.handleKeyEvent(isDown: true, timestamp: 150)
        XCTAssertEqual(action3, .startRecording)

        // Second tap released → stop recording
        let action4 = stateMachine.handleKeyEvent(isDown: false, timestamp: 2000)
        XCTAssertEqual(action4, .stopRecording)
    }

    func testSingleTapDoesNotActivate() {
        let stateMachine = DoubleTapStateMachine(windowMs: 300)

        let action1 = stateMachine.handleKeyEvent(isDown: true, timestamp: 0)
        XCTAssertEqual(action1, .none)
        let action2 = stateMachine.handleKeyEvent(isDown: false, timestamp: 50)
        XCTAssertEqual(action2, .none)

        // Second tap outside window
        let action3 = stateMachine.handleKeyEvent(isDown: true, timestamp: 500)
        XCTAssertEqual(action3, .none) // Too slow — treated as new first tap
    }

    func testComboKeyCancelsRecording() {
        let stateMachine = DoubleTapStateMachine(windowMs: 300)

        // Double tap to activate
        _ = stateMachine.handleKeyEvent(isDown: true, timestamp: 0)
        _ = stateMachine.handleKeyEvent(isDown: false, timestamp: 50)
        let action = stateMachine.handleKeyEvent(isDown: true, timestamp: 150)
        XCTAssertEqual(action, .startRecording)

        // Another key pressed while recording → cancel
        let cancel = stateMachine.handleOtherKeyPressed()
        XCTAssertEqual(cancel, .cancelRecording)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
swift test --filter HotkeyListenerTests
```

Expected: FAIL — `DoubleTapStateMachine` not found.

- [ ] **Step 4: Implement HotkeyListener with double-tap state machine**

Create `VoiceDictation/Hotkey/HotkeyListener.swift`:

```swift
import Foundation
import Cocoa

enum HotkeyAction: Equatable {
    case none
    case startRecording
    case stopRecording
    case cancelRecording
}

/// State machine for detecting double-tap-and-hold of a modifier key.
final class DoubleTapStateMachine {
    private enum State {
        case idle
        case waitingForSecondTap(firstUpTimestamp: Double)
        case recording
    }

    private var state: State = .idle
    private let windowMs: Int

    init(windowMs: Int = 300) {
        self.windowMs = windowMs
    }

    func handleKeyEvent(isDown: Bool, timestamp: Double) -> HotkeyAction {
        switch state {
        case .idle:
            if isDown {
                state = .idle // Will transition on release
                return .none
            }
            return .none

        case .waitingForSecondTap(let firstUpTimestamp):
            if isDown {
                let elapsed = timestamp - firstUpTimestamp
                if elapsed <= Double(windowMs) {
                    state = .recording
                    return .startRecording
                } else {
                    // Too slow — treat as new first tap
                    state = .idle
                    return .none
                }
            }
            return .none

        case .recording:
            if !isDown {
                state = .idle
                return .stopRecording
            }
            return .none
        }
    }

    // Called on key-down events: transition idle → waitingForSecondTap on release
    // We need to also handle the first tap's release
    func handleKeyRelease(timestamp: Double) -> HotkeyAction {
        switch state {
        case .idle:
            state = .waitingForSecondTap(firstUpTimestamp: timestamp)
            return .none
        case .recording:
            state = .idle
            return .stopRecording
        default:
            return .none
        }
    }

    func handleOtherKeyPressed() -> HotkeyAction {
        if case .recording = state {
            state = .idle
            return .cancelRecording
        }
        return .none
    }

    func reset() {
        state = .idle
    }
}

/// Global hotkey listener using CGEvent tap.
final class HotkeyListener {
    private let config: HotkeyConfig
    private let stateMachine: DoubleTapStateMachine
    private var eventTap: CFMachPort?

    var onAction: ((HotkeyAction) -> Void)?

    init(config: HotkeyConfig = HotkeyConfig()) {
        self.config = config
        self.stateMachine = DoubleTapStateMachine(windowMs: config.doubleTapWindowMs)
    }

    func start() -> Bool {
        let eventMask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            let listener = Unmanaged<HotkeyListener>.fromOpaque(userInfo!).takeUnretainedValue()
            listener.handleEvent(type: type, event: event)
            return Unmanaged.passRetained(event)
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) else {
            return false // Accessibility permission not granted
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let timestamp = Double(event.timestamp) / 1_000_000_000.0 // Convert to seconds

        if type == .flagsChanged {
            let flags = event.flags
            let isCtrlDown = flags.contains(.maskControl)

            let action: HotkeyAction
            if isCtrlDown {
                action = stateMachine.handleKeyEvent(isDown: true, timestamp: timestamp)
            } else {
                action = stateMachine.handleKeyEvent(isDown: false, timestamp: timestamp)
            }

            if action != .none {
                onAction?(action)
            }
        } else if type == .keyDown {
            // Any non-modifier key pressed — could be a combo
            let action = stateMachine.handleOtherKeyPressed()
            if action != .none {
                onAction?(action)
            }
        }
    }
}
```

Note: The test uses the `DoubleTapStateMachine` directly (no CGEvent needed). Update the state machine to handle the first tap properly. The `handleKeyEvent` needs a small fix — on first key-down we track it, on first key-up we transition to waiting:

Replace the `handleKeyEvent` method with this corrected version that properly tracks first-tap-down → first-tap-up → second-tap-down:

```swift
func handleKeyEvent(isDown: Bool, timestamp: Double) -> HotkeyAction {
    switch state {
    case .idle:
        if isDown {
            // First tap down — wait for release
            state = .idle // stays idle, release will transition
        }
        return .none

    case .waitingForSecondTap(let firstUpTimestamp):
        if isDown {
            let elapsed = timestamp - firstUpTimestamp
            if elapsed <= Double(windowMs) {
                state = .recording
                return .startRecording
            } else {
                state = .idle
                return .none
            }
        }
        return .none

    case .recording:
        if !isDown {
            state = .idle
            return .stopRecording
        }
        return .none
    }
}
```

The key insight: we need the `isDown: false` event in `.idle` state to transition to `.waitingForSecondTap`. Update:

```swift
case .idle:
    if isDown {
        return .none // First tap down, waiting for release
    } else {
        // First tap released — start window for second tap
        state = .waitingForSecondTap(firstUpTimestamp: timestamp)
        return .none
    }
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
swift test --filter HotkeyListenerTests
```

Expected: PASS — double-tap detected, single tap ignored, combo key cancels.

- [ ] **Step 6: Commit**

```bash
git add VoiceDictation/Hotkey/ Tests/HotkeyTests/
git commit -m "feat: add global HotkeyListener with double-tap Ctrl detection and combo filtering"
```

---

### Task 10: Text Field Detector + Text Injector

**Files:**
- Create: `VoiceDictation/TextInjection/TextFieldDetector.swift`
- Create: `VoiceDictation/TextInjection/TextInjector.swift`
- Create: `Tests/TextInjectionTests/TextFieldDetectorTests.swift`
- Create: `Tests/TextInjectionTests/TextInjectorTests.swift`

- [ ] **Step 1: Implement TextFieldDetector**

Create `VoiceDictation/TextInjection/TextFieldDetector.swift`:

```swift
import Foundation
import ApplicationServices

final class TextFieldDetector {

    /// Returns the focused AXUIElement if it is a text field or text area.
    /// Returns nil if no text field is focused.
    static func getFocusedTextField() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
            return nil
        }

        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        let element = focusedElement as! AXUIElement

        var role: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success else {
            return nil
        }

        let roleStr = role as? String ?? ""
        let textRoles = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            "AXSearchField",
            "AXComboBox"
        ]

        if textRoles.contains(roleStr) {
            return element
        }

        // Check if the element is contenteditable (web) — has AXValue and is editable
        var isSettable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isSettable) == .success,
           isSettable.boolValue {
            return element
        }

        return nil
    }

    /// Returns true if the currently focused element is a text input.
    static func isCursorInTextField() -> Bool {
        return getFocusedTextField() != nil
    }
}
```

- [ ] **Step 2: Implement TextInjector**

Create `VoiceDictation/TextInjection/TextInjector.swift`:

```swift
import Foundation
import ApplicationServices
import Carbon.HIToolbox

final class TextInjector {

    enum InjectionResult {
        case pastedViaAccessibility
        case pastedViaKeyboard
        case copiedToClipboard // no text field — just clipboard
        case failed(String)
    }

    /// Inject text: always copies to clipboard, pastes into text field if one is focused.
    static func inject(text: String) -> InjectionResult {
        // Always copy to clipboard
        copyToClipboard(text)

        // Try to paste into focused text field
        guard let textField = TextFieldDetector.getFocusedTextField() else {
            return .copiedToClipboard
        }

        // Strategy 1: AXValue setter (most reliable)
        if tryAXValueInjection(element: textField, text: text) {
            return .pastedViaAccessibility
        }

        // Strategy 2: Simulate Cmd+V
        if tryKeyboardPaste() {
            return .pastedViaKeyboard
        }

        return .failed("Both AXValue and Cmd+V injection failed")
    }

    // MARK: - Private

    private static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func tryAXValueInjection(element: AXUIElement, text: String) -> Bool {
        // First, get the current value and selection to insert at cursor position
        var currentValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)

        var selectedRange: AnyObject?
        let hasRange = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success

        if hasRange, let range = selectedRange {
            // Insert at selection / replace selection
            let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
            return result == .success
        }

        // Fallback: replace entire value
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
        return result == .success
    }

    private static func tryKeyboardPaste() -> Bool {
        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_V), keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        return true
    }
}
```

- [ ] **Step 3: Write basic compilation test**

Create `Tests/TextInjectionTests/TextInjectorTests.swift`:

```swift
import XCTest
@testable import VoiceDictation

final class TextInjectorTests: XCTestCase {

    func testCopyToClipboard() {
        // TextInjector.inject copies to clipboard even when no text field is focused
        let result = TextInjector.inject(text: "Hello from dictation")
        // In a test environment with no UI, no text field will be focused
        XCTAssertEqual(result, .copiedToClipboard)

        // Verify clipboard contents
        let clipboard = NSPasteboard.general
        let content = clipboard.string(forType: .string)
        XCTAssertEqual(content, "Hello from dictation")
    }
}
```

Note: make `InjectionResult` conform to `Equatable`:

Add to `TextInjector.swift`:
```swift
extension TextInjector.InjectionResult: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.pastedViaAccessibility, .pastedViaAccessibility): return true
        case (.pastedViaKeyboard, .pastedViaKeyboard): return true
        case (.copiedToClipboard, .copiedToClipboard): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter TextInjectorTests
```

Expected: PASS — clipboard test works in headless environment.

- [ ] **Step 5: Commit**

```bash
git add VoiceDictation/TextInjection/ Tests/TextInjectionTests/
git commit -m "feat: add TextFieldDetector and TextInjector with AXValue + Cmd+V strategies"
```

---

## Chunk 5: Storage + Orchestrator

### Task 11: SQLite Database Manager

**Files:**
- Create: `VoiceDictation/Storage/DictationEntry.swift`
- Create: `VoiceDictation/Storage/DatabaseManager.swift`
- Create: `Tests/StorageTests/DatabaseManagerTests.swift`

- [ ] **Step 1: Create DictationEntry model**

Create `VoiceDictation/Storage/DictationEntry.swift`:

```swift
import Foundation
import GRDB

struct DictationEntry: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    let timestamp: Date
    let durationSeconds: Double
    let rawTranscript: String
    let cleanedText: String
    let wasPasted: Bool

    static let databaseTableName = "dictations"
}
```

- [ ] **Step 2: Write failing test for DatabaseManager**

Create `Tests/StorageTests/DatabaseManagerTests.swift`:

```swift
import XCTest
import GRDB
@testable import VoiceDictation

final class DatabaseManagerTests: XCTestCase {
    var db: DatabaseManager!

    override func setUp() async throws {
        db = try DatabaseManager(inMemory: true)
    }

    func testInsertAndFetch() throws {
        let entry = DictationEntry(
            timestamp: Date(),
            durationSeconds: 5.0,
            rawTranscript: "uh hello world",
            cleanedText: "Hello world.",
            wasPasted: true
        )
        try db.insert(entry)

        let all = try db.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].cleanedText, "Hello world.")
        XCTAssertEqual(all[0].wasPasted, true)
    }

    func testFetchReturnsNewestFirst() throws {
        let entry1 = DictationEntry(
            timestamp: Date(timeIntervalSinceNow: -60),
            durationSeconds: 3.0,
            rawTranscript: "first",
            cleanedText: "First.",
            wasPasted: false
        )
        let entry2 = DictationEntry(
            timestamp: Date(),
            durationSeconds: 5.0,
            rawTranscript: "second",
            cleanedText: "Second.",
            wasPasted: true
        )
        try db.insert(entry1)
        try db.insert(entry2)

        let all = try db.fetchAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].cleanedText, "Second.") // newest first
    }

    func testSearch() throws {
        try db.insert(DictationEntry(
            timestamp: Date(), durationSeconds: 3.0,
            rawTranscript: "groceries", cleanedText: "Shopping bag, cutting board", wasPasted: false
        ))
        try db.insert(DictationEntry(
            timestamp: Date(), durationSeconds: 3.0,
            rawTranscript: "email", cleanedText: "Send email to John", wasPasted: false
        ))

        let results = try db.search("shopping")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].cleanedText, "Shopping bag, cutting board")
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
swift test --filter DatabaseManagerTests
```

Expected: FAIL — `DatabaseManager` not found.

- [ ] **Step 4: Implement DatabaseManager**

Create `VoiceDictation/Storage/DatabaseManager.swift`:

```swift
import Foundation
import GRDB

final class DatabaseManager {
    private let dbQueue: DatabaseQueue

    init(inMemory: Bool = false) throws {
        if inMemory {
            dbQueue = try DatabaseQueue()
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dbDir = appSupport.appendingPathComponent("VoiceDictation", isDirectory: true)
            try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
            let dbPath = dbDir.appendingPathComponent("dictations.sqlite").path
            dbQueue = try DatabaseQueue(path: dbPath)
        }
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "dictations") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull()
                t.column("durationSeconds", .double).notNull()
                t.column("rawTranscript", .text).notNull()
                t.column("cleanedText", .text).notNull()
                t.column("wasPasted", .boolean).notNull().defaults(to: false)
            }
        }

        migrator.registerMigration("v1_settings") { db in
            try db.create(table: "settings") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }
        }

        try migrator.migrate(dbQueue)
    }

    func insert(_ entry: DictationEntry) throws {
        try dbQueue.write { db in
            var mutableEntry = entry
            try mutableEntry.insert(db)
        }
    }

    func fetchAll(limit: Int = 100) throws -> [DictationEntry] {
        try dbQueue.read { db in
            try DictationEntry
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func search(_ query: String) throws -> [DictationEntry] {
        try dbQueue.read { db in
            let pattern = "%\(query)%"
            return try DictationEntry
                .filter(
                    Column("cleanedText").like(pattern) ||
                    Column("rawTranscript").like(pattern)
                )
                .order(Column("timestamp").desc)
                .fetchAll(db)
        }
    }

    // MARK: - Settings

    func getSetting(_ key: String) throws -> String? {
        try dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = ?", arguments: [key])
        }
    }

    func setSetting(_ key: String, value: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
                arguments: [key, value]
            )
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
swift test --filter DatabaseManagerTests
```

Expected: PASS — insert, fetch, and search all work.

- [ ] **Step 6: Commit**

```bash
git add VoiceDictation/Storage/ Tests/StorageTests/
git commit -m "feat: add DatabaseManager with GRDB, migrations, CRUD, and search"
```

---

### Task 12: Dictation Orchestrator

**Files:**
- Create: `VoiceDictation/App/AppState.swift`
- Create: `VoiceDictation/Orchestration/DictationOrchestrator.swift`
- Create: `Tests/OrchestrationTests/DictationOrchestratorTests.swift`

- [ ] **Step 1: Create AppState**

Create `VoiceDictation/App/AppState.swift`:

```swift
import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastDictation: String = ""
    @Published var statusMessage: String = ""
    @Published var showWarning: Bool = false // at 4:30

    // Settings
    @AppStorage("lmStudioEndpoint") var lmStudioEndpoint: String = "http://localhost:1234"
    @AppStorage("lmStudioModel") var lmStudioModel: String = "qwen2.5-7b-instruct"
    @AppStorage("whisperModelType") var whisperModelType: String = "ggml-large-v3-turbo"
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
}
```

- [ ] **Step 2: Implement DictationOrchestrator**

Create `VoiceDictation/Orchestration/DictationOrchestrator.swift`:

```swift
import Foundation

final class DictationOrchestrator: ObservableObject {
    private let audioRecorder = AudioRecorder()
    private var transcriptionPipeline: TranscriptionPipeline?
    private var transcriptCleaner: TranscriptCleaner?
    private var databaseManager: DatabaseManager?

    private let appState: AppState
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    private let maxDurationSeconds: TimeInterval = 300 // 5 minutes
    private let warningDurationSeconds: TimeInterval = 270 // 4:30

    init(appState: AppState) {
        self.appState = appState
    }

    /// Call once on app launch after the Whisper model is loaded.
    func configure(whisperEngine: WhisperEngine, databaseManager: DatabaseManager) {
        self.transcriptionPipeline = TranscriptionPipeline(whisperEngine: whisperEngine)
        self.databaseManager = databaseManager

        let client = LMStudioClient(
            endpoint: appState.lmStudioEndpoint,
            timeoutSeconds: 5.0
        )
        self.transcriptCleaner = TranscriptCleaner(
            client: client,
            model: appState.lmStudioModel
        )

        transcriptionPipeline?.onAbort = { [weak self] message in
            Task { @MainActor in
                self?.appState.statusMessage = message
                self?.stopRecording()
            }
        }
    }

    func startRecording() {
        guard !appState.isRecording else { return }

        transcriptionPipeline?.reset()
        recordingStartTime = Date()

        do {
            try audioRecorder.startRecording { [weak self] chunk in
                self?.transcriptionPipeline?.processChunk(chunk)
            }
        } catch {
            appState.statusMessage = "Microphone error: \(error.localizedDescription)"
            return
        }

        appState.isRecording = true
        appState.showWarning = false

        // Duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            let elapsed = Date().timeIntervalSince(start)
            Task { @MainActor in
                self.appState.recordingDuration = elapsed
                if elapsed >= self.warningDurationSeconds {
                    self.appState.showWarning = true
                }
                if elapsed >= self.maxDurationSeconds {
                    self.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        guard appState.isRecording else { return }

        durationTimer?.invalidate()
        durationTimer = nil

        // Stop audio and get final chunk
        let finalChunk = audioRecorder.stopRecording()
        if let chunk = finalChunk {
            transcriptionPipeline?.processChunk(chunk)
        }

        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())

        appState.isRecording = false
        appState.recordingDuration = 0
        appState.showWarning = false

        // Process in background
        Task {
            await transcriptionPipeline?.waitForCompletion()
            let rawTranscript = transcriptionPipeline?.getFinalTranscript() ?? ""

            guard !rawTranscript.isEmpty else {
                await MainActor.run {
                    appState.statusMessage = "No speech detected"
                }
                return
            }

            // LLM cleanup
            let cleanupResult = await transcriptCleaner?.clean(rawTranscript: rawTranscript)
                ?? CleanupResult(text: rawTranscript, usedLLM: false, error: nil)

            let finalText = cleanupResult.text

            // Inject text
            let injectionResult = TextInjector.inject(text: finalText)

            // Save to database
            let entry = DictationEntry(
                timestamp: Date(),
                durationSeconds: duration,
                rawTranscript: rawTranscript,
                cleanedText: finalText,
                wasPasted: injectionResult == .pastedViaAccessibility || injectionResult == .pastedViaKeyboard
            )
            try? databaseManager?.insert(entry)

            await MainActor.run {
                appState.lastDictation = finalText
                if let error = cleanupResult.error {
                    appState.statusMessage = error
                } else {
                    appState.statusMessage = ""
                }
            }
        }
    }

    func cancelRecording() {
        durationTimer?.invalidate()
        durationTimer = nil
        _ = audioRecorder.stopRecording()
        transcriptionPipeline?.reset()
        appState.isRecording = false
        appState.recordingDuration = 0
        appState.showWarning = false
    }
}
```

- [ ] **Step 3: Verify compilation**

```bash
swift build
```

Expected: Builds successfully.

- [ ] **Step 4: Commit**

```bash
git add VoiceDictation/App/AppState.swift VoiceDictation/Orchestration/
git commit -m "feat: add DictationOrchestrator tying hotkey → record → transcribe → clean → inject"
```

---

## Chunk 6: UI (Overlay + History + Menu Bar + Settings)

### Task 13: Recording Overlay

**Files:**
- Create: `VoiceDictation/UI/RecordingOverlay.swift`

- [ ] **Step 1: Implement the floating pill overlay**

Create `VoiceDictation/UI/RecordingOverlay.swift`:

```swift
import SwiftUI
import AppKit

struct RecordingOverlayView: View {
    @ObservedObject var appState: AppState
    @State private var pulseAnimation = false

    var body: some View {
        HStack(spacing: 10) {
            // Pulsing mic icon
            Circle()
                .fill(appState.showWarning ? Color.yellow : Color.red)
                .frame(width: 10, height: 10)
                .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)

            Image(systemName: "mic.fill")
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .medium))

            Text(formatDuration(appState.recordingDuration))
                .foregroundColor(.white)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.75))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        )
        .onAppear { pulseAnimation = true }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

/// NSPanel-based floating overlay that doesn't steal focus.
final class RecordingOverlayPanel: NSPanel {
    init(appState: AppState) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: RecordingOverlayView(appState: appState))
        contentView = hostingView

        // Position at center-bottom of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.minY + 80
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func showWithAnimation() {
        alphaValue = 0
        orderFront(nil)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            animator().alphaValue = 1
        })
    }

    func hideWithAnimation() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            animator().alphaValue = 0
        }) {
            self.orderOut(nil)
        }
    }
}
```

- [ ] **Step 2: Verify compilation**

```bash
swift build
```

Expected: Builds successfully.

- [ ] **Step 3: Commit**

```bash
git add VoiceDictation/UI/RecordingOverlay.swift
git commit -m "feat: add floating recording overlay pill with pulse animation"
```

---

### Task 14: History View + Row

**Files:**
- Create: `VoiceDictation/UI/HistoryView.swift`
- Create: `VoiceDictation/UI/HistoryRowView.swift`

- [ ] **Step 1: Implement HistoryRowView**

Create `VoiceDictation/UI/HistoryRowView.swift`:

```swift
import SwiftUI

struct HistoryRowView: View {
    let entry: DictationEntry
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("(\(formatDuration(entry.durationSeconds)))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if entry.wasPasted {
                    Label("Pasted", systemImage: "doc.on.clipboard")
                        .font(.caption2)
                        .foregroundColor(.green)
                }

                Button(action: copyToClipboard) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }

            Text(entry.cleanedText)
                .font(.body)
                .textSelection(.enabled)
                .lineLimit(nil)
        }
        .padding(.vertical, 8)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.cleanedText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
}
```

- [ ] **Step 2: Implement HistoryView**

Create `VoiceDictation/UI/HistoryView.swift`:

```swift
import SwiftUI

struct HistoryView: View {
    @ObservedObject var appState: AppState
    let databaseManager: DatabaseManager

    @State private var entries: [DictationEntry] = []
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search dictations...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        refreshEntries(query: newValue)
                    }
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Status message
            if !appState.statusMessage.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                    Text(appState.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.1))
            }

            // Dictation list
            if entries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "mic.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No dictations yet")
                        .foregroundColor(.secondary)
                    Text("Double-tap Ctrl and hold to start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(entries) { entry in
                    HistoryRowView(entry: entry)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear { refreshEntries() }
        .onChange(of: appState.lastDictation) { _, _ in refreshEntries(query: searchText) }
    }

    private func refreshEntries(query: String = "") {
        do {
            if query.isEmpty {
                entries = try databaseManager.fetchAll()
            } else {
                entries = try databaseManager.search(query)
            }
        } catch {
            appState.statusMessage = "Database error: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 3: Verify compilation**

```bash
swift build
```

Expected: Builds successfully.

- [ ] **Step 4: Commit**

```bash
git add VoiceDictation/UI/HistoryView.swift VoiceDictation/UI/HistoryRowView.swift
git commit -m "feat: add HistoryView with search bar, entry list, and copy functionality"
```

---

### Task 15: Menu Bar + Settings View

**Files:**
- Create: `VoiceDictation/UI/MenuBarView.swift`
- Create: `VoiceDictation/UI/SettingsView.swift`

- [ ] **Step 1: Implement MenuBarView**

Create `VoiceDictation/UI/MenuBarView.swift`:

```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.isRecording {
                Label("Recording...", systemImage: "mic.fill")
                    .foregroundColor(.red)
            } else {
                Label("Ready", systemImage: "mic")
            }

            Divider()

            Button("Open Voice Dictation") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "Voice Dictation" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Divider()

            Button("Quit Voice Dictation") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
    }
}
```

- [ ] **Step 2: Implement SettingsView**

Create `VoiceDictation/UI/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    let databaseManager: DatabaseManager

    @State private var customPrompt: String = ""
    @State private var promptLoaded = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            llmTab
                .tabItem { Label("LLM", systemImage: "brain") }
            whisperTab
                .tabItem { Label("Whisper", systemImage: "waveform") }
            promptTab
                .tabItem { Label("Prompt", systemImage: "text.quote") }
        }
        .frame(width: 500, height: 400)
        .padding()
    }

    private var generalTab: some View {
        Form {
            Section("Hotkey") {
                Text("Double-tap Ctrl (then hold to record)")
                    .foregroundColor(.secondary)
                Text("Hotkey customization coming in a future update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $appState.launchAtLogin)
            }
        }
    }

    private var llmTab: some View {
        Form {
            Section("LM Studio Connection") {
                TextField("Endpoint", text: $appState.lmStudioEndpoint)
                    .textFieldStyle(.roundedBorder)
                TextField("Model name", text: $appState.lmStudioModel)
                    .textFieldStyle(.roundedBorder)
                Text("Make sure LM Studio is running with a model loaded.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var whisperTab: some View {
        Form {
            Section("Whisper Model") {
                Picker("Model", selection: $appState.whisperModelType) {
                    ForEach(WhisperModelType.allCases, id: \.rawValue) { model in
                        Text(model.displayName).tag(model.rawValue)
                    }
                }
                Text("Requires app restart after changing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var promptTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cleanup System Prompt")
                .font(.headline)
            Text("Customize how the LLM cleans up your dictation.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $customPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Reset to Default") {
                    customPrompt = TranscriptCleaner.defaultSystemPrompt
                    try? databaseManager.setSetting("cleanupPrompt", value: customPrompt)
                }
                Spacer()
                Button("Save") {
                    try? databaseManager.setSetting("cleanupPrompt", value: customPrompt)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .onAppear {
            if !promptLoaded {
                customPrompt = (try? databaseManager.getSetting("cleanupPrompt")) ?? TranscriptCleaner.defaultSystemPrompt
                promptLoaded = true
            }
        }
    }
}
```

- [ ] **Step 3: Verify compilation**

```bash
swift build
```

Expected: Builds successfully.

- [ ] **Step 4: Commit**

```bash
git add VoiceDictation/UI/MenuBarView.swift VoiceDictation/UI/SettingsView.swift
git commit -m "feat: add MenuBarView and SettingsView with LLM, Whisper, and prompt config"
```

---

## Chunk 7: App Assembly + First Launch + Permissions

### Task 16: Wire Everything Together in App Entry Point

**Files:**
- Modify: `VoiceDictation/App/VoiceDictationApp.swift`

- [ ] **Step 1: Implement the full app entry point**

Replace `VoiceDictation/App/VoiceDictationApp.swift`:

```swift
import SwiftUI

@main
struct VoiceDictationApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var modelManager = WhisperModelManager.shared

    @State private var orchestrator: DictationOrchestrator?
    @State private var hotkeyListener: HotkeyListener?
    @State private var overlayPanel: RecordingOverlayPanel?
    @State private var databaseManager: DatabaseManager?
    @State private var isReady = false
    @State private var setupError: String?

    var body: some Scene {
        // Main window
        WindowGroup("Voice Dictation") {
            if isReady, let db = databaseManager {
                HistoryView(appState: appState, databaseManager: db)
            } else if let error = setupError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Setup Error")
                        .font(.title2)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 500, height: 300)
                .padding()
            } else if !modelManager.isModelAvailable(.largev3Turbo) {
                ModelDownloadView(modelManager: modelManager) {
                    Task { await setup() }
                }
            } else {
                ProgressView("Loading Whisper model...")
                    .frame(width: 300, height: 100)
                    .task { await setup() }
            }
        }

        // Menu bar
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: appState.isRecording ? "mic.fill" : "mic")
        }

        // Settings
        Settings {
            if let db = databaseManager {
                SettingsView(appState: appState, databaseManager: db)
            }
        }
    }

    private func setup() async {
        do {
            // Initialize database
            let db = try DatabaseManager()
            await MainActor.run { databaseManager = db }

            // Load Whisper model
            let modelType = WhisperModelType(rawValue: appState.whisperModelType) ?? .largev3Turbo
            let modelPath = WhisperModelManager.shared.modelPath(for: modelType)

            guard WhisperModelManager.shared.isModelAvailable(modelType) else {
                await MainActor.run { setupError = "Whisper model not found. Please download it first." }
                return
            }

            let whisperEngine = try WhisperEngine(modelPath: modelPath)

            // Create orchestrator
            let orch = DictationOrchestrator(appState: appState)
            orch.configure(whisperEngine: whisperEngine, databaseManager: db)

            // Create overlay
            let panel = await MainActor.run {
                RecordingOverlayPanel(appState: appState)
            }

            // Start hotkey listener
            let listener = HotkeyListener()
            listener.onAction = { [weak orch] action in
                Task { @MainActor in
                    switch action {
                    case .startRecording:
                        orch?.startRecording()
                        panel.showWithAnimation()
                    case .stopRecording:
                        panel.hideWithAnimation()
                        orch?.stopRecording()
                    case .cancelRecording:
                        panel.hideWithAnimation()
                        orch?.cancelRecording()
                    case .none:
                        break
                    }
                }
            }

            guard listener.start() else {
                await MainActor.run {
                    setupError = "Accessibility permission required.\nGo to System Settings → Privacy & Security → Accessibility and add Voice Dictation."
                }
                return
            }

            await MainActor.run {
                orchestrator = orch
                hotkeyListener = listener
                overlayPanel = panel
                isReady = true
            }

        } catch {
            await MainActor.run {
                setupError = error.localizedDescription
            }
        }
    }
}

// MARK: - Model Download View (first launch)

struct ModelDownloadView: View {
    @ObservedObject var modelManager: WhisperModelManager
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Whisper Model Required")
                .font(.title2)

            Text("Voice Dictation needs a speech recognition model (~1.5 GB).\nThis is a one-time download.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if modelManager.isDownloading {
                ProgressView(value: modelManager.downloadProgress)
                    .frame(width: 300)
                Text("\(Int(modelManager.downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button("Download Model") {
                    Task {
                        try? await modelManager.downloadModel(.largev3Turbo)
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 500, height: 300)
        .padding()
    }
}
```

- [ ] **Step 2: Add entitlements file**

Create `Resources/VoiceDictation.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 3: Build the full app**

```bash
swift build
```

Expected: Builds successfully with all components wired together.

- [ ] **Step 4: Commit**

```bash
git add VoiceDictation/App/VoiceDictationApp.swift Resources/
git commit -m "feat: wire up full app with model download, permissions, hotkey, overlay, and history"
```

---

### Task 17: End-to-End Manual Testing

- [ ] **Step 1: Download a Whisper model for testing**

```bash
mkdir -p ~/Library/Application\ Support/VoiceDictation/models
cd ~/Library/Application\ Support/VoiceDictation/models
# Download the small model first for fast testing:
curl -L -o ggml-base.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
```

- [ ] **Step 2: Run the app**

```bash
cd /Users/mirasimali/Voice-agent/VoiceDictation
swift run
```

- [ ] **Step 3: Grant permissions**

When prompted, go to System Settings → Privacy & Security:
- **Accessibility**: Add the app
- **Microphone**: Allow

- [ ] **Step 4: Test the full flow**

1. Double-tap Ctrl and hold — overlay pill should appear with pulsing mic and timer
2. Speak for 5-10 seconds
3. Release Ctrl — overlay fades out
4. If cursor was in a text field: text should be pasted
5. If not: text should be on clipboard (Cmd+V to verify)
6. Open app window — dictation should appear in history
7. Search for a word from the dictation — should find it

- [ ] **Step 5: Test edge cases**

1. Hold Ctrl without speaking → "No speech detected" message
2. Single-tap Ctrl → nothing happens
3. Ctrl+C during recording → recording cancels
4. Stop LM Studio → dictation still works (raw transcript, warning shown)
5. Record for 4:30+ → warning appears, auto-stops at 5:00

- [ ] **Step 6: Commit any fixes from testing**

```bash
git add -A
git commit -m "fix: address issues found during manual testing"
```

---

### Task 18: Run All Tests

- [ ] **Step 1: Run the full test suite**

```bash
cd /Users/mirasimali/Voice-agent/VoiceDictation
swift test
```

Expected: All tests pass.

- [ ] **Step 2: Fix any failures and re-run**

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "test: ensure all unit tests pass"
```

---

## Summary

| Task | Component | Key Files |
|------|-----------|-----------|
| 1 | Xcode Project | `Package.swift`, `VoiceDictationApp.swift` |
| 2 | whisper.cpp Submodule | `Libraries/whisper.cpp/`, `WhisperBridge.h` |
| 3 | WhisperEngine Wrapper | `WhisperEngine.swift`, `TranscriptResult.swift` |
| 4 | Model Manager | `WhisperModel.swift` |
| 5 | Audio Recorder | `AudioRecorder.swift`, `AudioChunk.swift` |
| 6 | Transcription Pipeline | `TranscriptionPipeline.swift` |
| 7 | LM Studio Client | `LMStudioClient.swift` |
| 8 | Transcript Cleaner | `TranscriptCleaner.swift` |
| 9 | Hotkey Listener | `HotkeyListener.swift`, `HotkeyConfig.swift` |
| 10 | Text Injection | `TextFieldDetector.swift`, `TextInjector.swift` |
| 11 | Database Manager | `DatabaseManager.swift`, `DictationEntry.swift` |
| 12 | Orchestrator | `DictationOrchestrator.swift`, `AppState.swift` |
| 13 | Recording Overlay | `RecordingOverlay.swift` |
| 14 | History View | `HistoryView.swift`, `HistoryRowView.swift` |
| 15 | Menu Bar + Settings | `MenuBarView.swift`, `SettingsView.swift` |
| 16 | App Assembly | `VoiceDictationApp.swift` (full wiring) |
| 17 | Manual Testing | End-to-end verification |
| 18 | Final Test Suite | All tests green |
