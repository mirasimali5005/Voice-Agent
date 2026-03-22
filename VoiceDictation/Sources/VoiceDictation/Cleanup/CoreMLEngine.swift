import Foundation
import CoreML

/// A cleanup backend that uses a CoreML model for on-device transcript cleanup.
///
/// The engine attempts to load a CoreML `.mlpackage` from the specified path.
/// If the model is not found or fails to load, the engine reports itself as
/// unavailable and `complete` returns a failure — allowing the caller to fall
/// back to another backend.
public final class CoreMLEngine: CleanupBackend, @unchecked Sendable {
    public let backendName = "CoreML"

    /// Default model path inside Application Support.
    public static let defaultModelPath: String = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("VoiceDictation/models/llama-3.2-1b.mlpackage")
            .path
    }()

    private let modelPath: String
    private var model: MLModel?
    private let lock = NSLock()

    // MARK: - Init

    /// Creates a CoreMLEngine that will look for a model at the given path.
    ///
    /// The model is loaded lazily on the first call to `isAvailable()` or `complete(...)`.
    public init(modelPath: String = CoreMLEngine.defaultModelPath) {
        self.modelPath = modelPath
    }

    // MARK: - CleanupBackend

    public func isAvailable() async -> Bool {
        return loadModelIfNeeded() != nil
    }

    public func complete(systemPrompt: String, userMessage: String) async -> Result<String, Error> {
        guard let model = loadModelIfNeeded() else {
            return .failure(CleanupBackendError.modelNotFound(path: modelPath))
        }

        // Build the prompt in chat format
        let fullPrompt = """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>

        \(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>

        \(userMessage)<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        """

        do {
            let result = try await predict(prompt: fullPrompt, model: model)
            return .success(result)
        } catch {
            return .failure(CleanupBackendError.predictionFailed(underlying: error.localizedDescription))
        }
    }

    // MARK: - Model Loading

    /// Loads the MLModel from disk if not already loaded. Returns nil if unavailable.
    private func loadModelIfNeeded() -> MLModel? {
        lock.lock()
        defer { lock.unlock() }

        if let model = self.model {
            return model
        }

        let modelURL = URL(fileURLWithPath: modelPath)

        guard FileManager.default.fileExists(atPath: modelPath) else {
            return nil
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            let loaded = try MLModel(contentsOf: modelURL, configuration: config)
            self.model = loaded
            print("[CoreMLEngine] Model loaded from \(modelPath)")
            return loaded
        } catch {
            print("[CoreMLEngine] Failed to load model: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Prediction

    /// Runs prediction on the loaded CoreML model.
    ///
    /// CoreML text-generation models vary in their input/output interface depending
    /// on how they were converted. This method attempts a general approach:
    /// it creates an MLDictionaryFeatureProvider with the prompt text and invokes
    /// `model.prediction(from:)`.
    private func predict(prompt: String, model: MLModel) async throws -> String {
        // Attempt to find input feature names from the model description
        let inputDescription = model.modelDescription.inputDescriptionsByName

        // Try common input key names used by CoreML text-generation models
        let possibleInputKeys = ["prompt", "input_text", "text", "inputText", "input_ids"]
        var inputKey: String?
        for key in possibleInputKeys {
            if inputDescription[key] != nil {
                inputKey = key
                break
            }
        }

        let featureProvider: MLFeatureProvider

        if let key = inputKey {
            // String-based input: pass the prompt directly
            let inputDict: [String: Any] = [key: prompt]
            featureProvider = try MLDictionaryFeatureProvider(dictionary: inputDict)
        } else if inputDescription["input_ids"] != nil {
            // Token-based input: encode the prompt as a simple byte-level representation.
            // A proper tokenizer would be needed for production use; this is a practical
            // fallback that works with models expecting token IDs.
            let tokens = simpleTokenize(prompt)
            let inputArray = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)
            for (i, token) in tokens.enumerated() {
                inputArray[[0, NSNumber(value: i)] as [NSNumber]] = NSNumber(value: token)
            }
            var inputDict: [String: Any] = ["input_ids": inputArray]

            // Add attention mask if the model expects it
            if inputDescription["attention_mask"] != nil {
                let mask = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)
                for i in 0..<tokens.count {
                    mask[[0, NSNumber(value: i)] as [NSNumber]] = 1
                }
                inputDict["attention_mask"] = mask
            }

            featureProvider = try MLDictionaryFeatureProvider(dictionary: inputDict)
        } else {
            throw CleanupBackendError.predictionFailed(
                underlying: "Could not determine model input format. Available inputs: \(Array(inputDescription.keys))"
            )
        }

        let prediction = try await model.prediction(from: featureProvider)

        // Try common output key names
        let possibleOutputKeys = ["output_text", "output", "text", "generated_text", "logits"]
        let outputDescription = model.modelDescription.outputDescriptionsByName

        for key in possibleOutputKeys {
            if let feature = prediction.featureValue(for: key) {
                let text = feature.stringValue
                if !text.isEmpty {
                    return text
                }
                // If it's a multi-array (logits), decode the argmax tokens
                if let multiArray = feature.multiArrayValue {
                    return decodeLogits(multiArray)
                }
            }
        }

        // Fallback: try first available output
        for key in outputDescription.keys {
            if let feature = prediction.featureValue(for: key) {
                let text = feature.stringValue
                if !text.isEmpty {
                    return text
                }
                if let multiArray = feature.multiArrayValue {
                    return decodeLogits(multiArray)
                }
            }
        }

        throw CleanupBackendError.predictionFailed(
            underlying: "Could not extract text from model output. Available outputs: \(Array(outputDescription.keys))"
        )
    }

    // MARK: - Simple Tokenization (fallback)

    /// Very simple byte-level tokenization. In production, you would load the
    /// actual tokenizer (e.g. via a SentencePiece or tiktoken-compatible library).
    private func simpleTokenize(_ text: String) -> [Int32] {
        return Array(text.utf8).map { Int32($0) }
    }

    /// Decodes logits by taking argmax at each position and converting to characters.
    /// This is a simplified decoder for basic CoreML outputs.
    private func decodeLogits(_ multiArray: MLMultiArray) -> String {
        let shape = multiArray.shape.map { $0.intValue }
        guard shape.count >= 2 else { return "" }

        let seqLen = shape.count == 3 ? shape[1] : shape[0]
        let vocabSize = shape.last ?? 0
        guard vocabSize > 0 else { return "" }

        var tokens: [Int] = []
        for pos in 0..<seqLen {
            var maxVal: Float = -.infinity
            var maxIdx = 0
            for v in 0..<vocabSize {
                let index: [NSNumber]
                if shape.count == 3 {
                    index = [0, NSNumber(value: pos), NSNumber(value: v)]
                } else {
                    index = [NSNumber(value: pos), NSNumber(value: v)]
                }
                let val = multiArray[index].floatValue
                if val > maxVal {
                    maxVal = val
                    maxIdx = v
                }
            }
            tokens.append(maxIdx)
        }

        // Convert token IDs to characters (byte-level fallback)
        let chars = tokens.compactMap { id -> Character? in
            guard id > 0 && id < 128 else { return nil }
            return Character(UnicodeScalar(id)!)
        }
        return String(chars)
    }
}
