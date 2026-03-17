import XCTest
@testable import VoiceDictation

final class OverlapDedupTests: XCTestCase {

    func testDeduplicateWithOverlap() {
        let previous = "The quick brown fox jumps over"
        let next = "fox jumps over the lazy dog"
        let result = TranscriptionPipeline.deduplicateOverlap(
            previous: previous,
            next: next,
            windowSize: 5
        )
        XCTAssertEqual(result, "the lazy dog")
    }

    func testDeduplicateNoOverlap() {
        let previous = "Hello world"
        let next = "Goodbye universe"
        let result = TranscriptionPipeline.deduplicateOverlap(
            previous: previous,
            next: next,
            windowSize: 5
        )
        XCTAssertEqual(result, "Goodbye universe")
    }

    func testDeduplicateEmptyPrevious() {
        let result = TranscriptionPipeline.deduplicateOverlap(
            previous: "",
            next: "Hello world",
            windowSize: 5
        )
        XCTAssertEqual(result, "Hello world")
    }

    func testDeduplicateEmptyNext() {
        let result = TranscriptionPipeline.deduplicateOverlap(
            previous: "Hello world",
            next: "",
            windowSize: 5
        )
        XCTAssertEqual(result, "")
    }

    func testDeduplicateCaseInsensitive() {
        let previous = "The Quick Brown"
        let next = "the quick brown fox"
        let result = TranscriptionPipeline.deduplicateOverlap(
            previous: previous,
            next: next,
            windowSize: 5
        )
        XCTAssertEqual(result, "fox")
    }

    func testDeduplicatePartialOverlap() {
        // Only 2 words overlap
        let previous = "one two three four"
        let next = "three four five six"
        let result = TranscriptionPipeline.deduplicateOverlap(
            previous: previous,
            next: next,
            windowSize: 5
        )
        XCTAssertEqual(result, "five six")
    }

    func testDeduplicateSingleWordNoMatch() {
        // Single word overlap should NOT be deduped (requires 2+ match)
        let previous = "hello world"
        let next = "world is great"
        let result = TranscriptionPipeline.deduplicateOverlap(
            previous: previous,
            next: next,
            windowSize: 5
        )
        XCTAssertEqual(result, "world is great")
    }
}
