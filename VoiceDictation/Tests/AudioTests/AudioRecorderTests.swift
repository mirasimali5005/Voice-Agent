import XCTest
@testable import VoiceDictation

final class AudioRecorderTests: XCTestCase {

    // MARK: - RMS Energy Tests

    func testRMSEnergyCalculation_silence() {
        // Silence: all zeros should return 0
        let silence = [Float](repeating: 0.0, count: 1000)
        let rms = AudioRecorder.calculateRMS(silence)
        XCTAssertEqual(rms, 0.0, accuracy: 1e-6, "RMS of silence should be 0")
    }

    func testRMSEnergyCalculation_constant() {
        // Constant 0.5: RMS of constant value should equal the value itself
        let constant = [Float](repeating: 0.5, count: 1000)
        let rms = AudioRecorder.calculateRMS(constant)
        XCTAssertEqual(rms, 0.5, accuracy: 1e-6, "RMS of constant 0.5 should be 0.5")
    }

    func testRMSEnergyCalculation_empty() {
        let empty: [Float] = []
        let rms = AudioRecorder.calculateRMS(empty)
        XCTAssertEqual(rms, 0.0, "RMS of empty array should be 0")
    }

    func testRMSEnergyCalculation_knownValues() {
        // For samples [1, -1], RMS = sqrt((1+1)/2) = 1.0
        let samples: [Float] = [1.0, -1.0]
        let rms = AudioRecorder.calculateRMS(samples)
        XCTAssertEqual(rms, 1.0, accuracy: 1e-6)
    }

    // MARK: - Chunk Splitting Tests

    func testChunkSplittingWithOverlap() {
        // 10 seconds at 16kHz = 160,000 samples
        let sampleRate: Double = 16000
        let totalDuration: Double = 10.0
        let sampleCount = Int(sampleRate * totalDuration)
        let samples = [Float](repeating: 0.1, count: sampleCount)

        let chunks = AudioRecorder.splitIntoChunks(
            samples: samples,
            chunkDurationSeconds: 5.0,
            overlapSeconds: 0.5,
            sampleRate: sampleRate
        )

        // With 5s chunks and 0.5s overlap, step = 4.5s
        // Chunk 0: 0..80000 (5s)
        // Chunk 1: 72000..152000 (5s)
        // Chunk 2: 144000..160000 (1s partial)
        XCTAssertEqual(chunks.count, 3, "10 seconds should produce 3 chunks with 5s window and 0.5s overlap")

        // First two chunks should be full 80,000 samples
        XCTAssertEqual(chunks[0].samples.count, 80000, "First chunk should have 80,000 samples")
        XCTAssertEqual(chunks[1].samples.count, 80000, "Second chunk should have 80,000 samples")

        // Third chunk is partial (remaining samples)
        XCTAssertTrue(chunks[2].samples.count < 80000, "Third chunk should be partial")
        XCTAssertTrue(chunks[2].samples.count > 0, "Third chunk should have some samples")

        // Verify chunk indices
        XCTAssertEqual(chunks[0].index, 0)
        XCTAssertEqual(chunks[1].index, 1)
        XCTAssertEqual(chunks[2].index, 2)

        // Verify durations
        XCTAssertEqual(chunks[0].durationSeconds, 5.0, accuracy: 0.01)
        XCTAssertEqual(chunks[1].durationSeconds, 5.0, accuracy: 0.01)
        XCTAssertTrue(chunks[2].durationSeconds < 5.0)
        XCTAssertTrue(chunks[2].durationSeconds > 0)
    }

    func testChunkSplittingEmpty() {
        let chunks = AudioRecorder.splitIntoChunks(samples: [])
        XCTAssertTrue(chunks.isEmpty, "Empty samples should produce no chunks")
    }

    func testChunkSplittingSinglePartial() {
        // Less than one chunk worth of samples
        let samples = [Float](repeating: 0.1, count: 40000) // 2.5 seconds
        let chunks = AudioRecorder.splitIntoChunks(samples: samples)
        XCTAssertEqual(chunks.count, 1, "Partial samples should produce 1 chunk")
        XCTAssertEqual(chunks[0].samples.count, 40000)
    }
}
