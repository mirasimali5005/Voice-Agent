import Foundation

struct AudioChunk {
    let samples: [Float]       // 16kHz mono Float32
    let index: Int
    let durationSeconds: Double
    let rmsEnergy: Float       // for VAD
}
