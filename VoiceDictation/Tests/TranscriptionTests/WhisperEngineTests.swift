import XCTest
@testable import VoiceDictation

final class WhisperEngineTests: XCTestCase {
    func testInitWithInvalidModelPathThrows() {
        let invalidPath = "/nonexistent/path/to/model.bin"
        XCTAssertThrowsError(try WhisperEngine(modelPath: invalidPath)) { error in
            guard let whisperError = error as? WhisperEngineError else {
                XCTFail("Expected WhisperEngineError, got \(type(of: error))")
                return
            }
            if case .modelLoadFailed(let path) = whisperError {
                XCTAssertEqual(path, invalidPath)
            } else {
                XCTFail("Expected modelLoadFailed error, got \(whisperError)")
            }
        }
    }
}
