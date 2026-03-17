import AVFoundation
import Foundation

enum AudioRecorderError: Error, LocalizedError {
    case audioEngineSetupFailed(String)
    case converterCreationFailed
    case alreadyRecording

    var errorDescription: String? {
        switch self {
        case .audioEngineSetupFailed(let reason):
            return "Audio engine setup failed: \(reason)"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .alreadyRecording:
            return "Already recording"
        }
    }
}

final class AudioRecorder {
    // MARK: - Constants
    static let sampleRate: Double = 16000
    static let chunkDurationSeconds: Double = 5.0
    static let overlapSeconds: Double = 0.5
    static let chunkSampleCount: Int = Int(sampleRate * chunkDurationSeconds)     // 80,000
    static let overlapSampleCount: Int = Int(sampleRate * overlapSeconds)          // 8,000

    // MARK: - Properties
    private let audioEngine = AVAudioEngine()
    private var sampleBuffer: [Float] = []
    private let bufferLock = NSLock()
    private var chunkIndex: Int = 0
    private var onChunkCallback: ((AudioChunk) -> Void)?
    private var onAudioLevelCallback: ((Float) -> Void)?
    private var isRecording = false

    // MARK: - Recording

    func startRecording(onChunk: @escaping (AudioChunk) -> Void, onAudioLevel: ((Float) -> Void)? = nil) throws {
        bufferLock.lock()
        guard !isRecording else {
            bufferLock.unlock()
            throw AudioRecorderError.alreadyRecording
        }
        isRecording = true
        sampleBuffer.removeAll()
        chunkIndex = 0
        onChunkCallback = onChunk
        onAudioLevelCallback = onAudioLevel
        bufferLock.unlock()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioRecorder.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.audioEngineSetupFailed("Could not create target format")
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.converterCreationFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processInputBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        try audioEngine.start()
    }

    func stopRecording() -> AudioChunk? {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        bufferLock.lock()
        isRecording = false
        let remainingSamples = sampleBuffer
        sampleBuffer.removeAll()
        let currentIndex = chunkIndex
        onChunkCallback = nil
        onAudioLevelCallback = nil
        bufferLock.unlock()

        guard !remainingSamples.isEmpty else { return nil }

        let duration = Double(remainingSamples.count) / AudioRecorder.sampleRate
        let rms = AudioRecorder.calculateRMS(remainingSamples)

        return AudioChunk(
            samples: remainingSamples,
            index: currentIndex,
            durationSeconds: duration,
            rmsEnergy: rms
        )
    }

    // MARK: - Buffer Processing

    private func processInputBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * AudioRecorder.sampleRate / buffer.format.sampleRate
        )
        guard frameCapacity > 0 else { return }

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCapacity + 1
        ) else { return }

        var error: NSError?
        var hasData = false
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if hasData {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasData = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard error == nil,
              let floatData = convertedBuffer.floatChannelData,
              convertedBuffer.frameLength > 0 else { return }

        let samples = Array(UnsafeBufferPointer(
            start: floatData[0],
            count: Int(convertedBuffer.frameLength)
        ))

        // Publish real-time audio level for UI visualization
        let level = AudioRecorder.calculateRMS(samples)
        onAudioLevelCallback?(level)

        bufferLock.lock()
        sampleBuffer.append(contentsOf: samples)

        while sampleBuffer.count >= AudioRecorder.chunkSampleCount {
            let chunkSamples = Array(sampleBuffer.prefix(AudioRecorder.chunkSampleCount))
            let rms = AudioRecorder.calculateRMS(chunkSamples)
            let chunk = AudioChunk(
                samples: chunkSamples,
                index: chunkIndex,
                durationSeconds: AudioRecorder.chunkDurationSeconds,
                rmsEnergy: rms
            )
            chunkIndex += 1

            // Keep overlap: remove all but last overlapSampleCount samples from the consumed portion
            sampleBuffer.removeFirst(AudioRecorder.chunkSampleCount - AudioRecorder.overlapSampleCount)

            let callback = onChunkCallback
            bufferLock.unlock()
            callback?(chunk)
            bufferLock.lock()
        }

        bufferLock.unlock()
    }

    // MARK: - Static Utilities

    static func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sumOfSquares: Float = 0
        for sample in samples {
            sumOfSquares += sample * sample
        }
        return sqrt(sumOfSquares / Float(samples.count))
    }

    static func splitIntoChunks(
        samples: [Float],
        chunkDurationSeconds: Double = AudioRecorder.chunkDurationSeconds,
        overlapSeconds: Double = AudioRecorder.overlapSeconds,
        sampleRate: Double = AudioRecorder.sampleRate
    ) -> [AudioChunk] {
        guard !samples.isEmpty else { return [] }

        let chunkSize = Int(sampleRate * chunkDurationSeconds)
        let overlapSize = Int(sampleRate * overlapSeconds)
        let stepSize = chunkSize - overlapSize

        var chunks: [AudioChunk] = []
        var offset = 0
        var index = 0

        while offset < samples.count {
            let end = min(offset + chunkSize, samples.count)
            let chunkSamples = Array(samples[offset..<end])
            let duration = Double(chunkSamples.count) / sampleRate
            let rms = calculateRMS(chunkSamples)

            chunks.append(AudioChunk(
                samples: chunkSamples,
                index: index,
                durationSeconds: duration,
                rmsEnergy: rms
            ))

            index += 1
            offset += stepSize

            // If this chunk was already partial (didn't fill chunkSize), stop
            if end - (offset - stepSize) < chunkSize && offset < samples.count {
                // There's remaining data that wasn't a full chunk - it was already captured
                // Check if remaining samples after step would be empty
            }
            // If we've reached or passed the end, stop
            if end >= samples.count {
                break
            }
        }

        return chunks
    }
}
