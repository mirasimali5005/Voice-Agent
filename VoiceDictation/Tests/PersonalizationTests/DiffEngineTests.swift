import XCTest
@testable import VoiceDictation

final class DiffEngineTests: XCTestCase {

    func testBasicWordReplacement() {
        let changes = DiffEngine.diff(
            original: "gonna do it",
            edited: "going to do it"
        )
        // "gonna" -> "going", "" -> "to"
        XCTAssertFalse(changes.isEmpty)
        let befores = changes.map(\.before)
        let afters = changes.map(\.after)
        XCTAssertTrue(befores.contains("gonna"))
        XCTAssertTrue(afters.contains("going"))
        XCTAssertTrue(afters.contains("to"))
    }

    func testDeletion() {
        let changes = DiffEngine.diff(
            original: "I um want to go",
            edited: "I want to go"
        )
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].before, "um")
        XCTAssertEqual(changes[0].after, "")
    }

    func testNoChanges() {
        let changes = DiffEngine.diff(
            original: "hello world",
            edited: "hello world"
        )
        XCTAssertTrue(changes.isEmpty)
    }

    func testMultipleChanges() {
        let changes = DiffEngine.diff(
            original: "I wanna gonna do uh stuff",
            edited: "I want to do stuff"
        )
        XCTAssertFalse(changes.isEmpty)
        // Should detect: wanna->want, gonna removed or replaced, uh removed
        let befores = Set(changes.map(\.before))
        XCTAssertTrue(befores.contains("wanna") || befores.contains("gonna") || befores.contains("uh"))
    }

    func testInsertion() {
        let changes = DiffEngine.diff(
            original: "I want go",
            edited: "I want to go"
        )
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].before, "")
        XCTAssertEqual(changes[0].after, "to")
    }

    func testEmptyStrings() {
        let changes = DiffEngine.diff(original: "", edited: "")
        XCTAssertTrue(changes.isEmpty)
    }

    func testOriginalEmpty() {
        let changes = DiffEngine.diff(original: "", edited: "hello world")
        XCTAssertEqual(changes.count, 2)
        XCTAssertTrue(changes.allSatisfy { $0.before == "" })
    }

    func testEditedEmpty() {
        let changes = DiffEngine.diff(original: "hello world", edited: "")
        XCTAssertEqual(changes.count, 2)
        XCTAssertTrue(changes.allSatisfy { $0.after == "" })
    }
}
