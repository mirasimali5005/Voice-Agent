import XCTest
@testable import VoiceDictation

final class DatabaseManagerTests: XCTestCase {

    func testInsertAndFetch() throws {
        let db = try DatabaseManager(inMemory: true)

        let entry = DictationEntry(
            timestamp: Date(),
            durationSeconds: 3.5,
            rawTranscript: "hello world",
            cleanedText: "Hello world.",
            wasPasted: true
        )
        try db.insert(entry)

        let results = try db.fetchAll()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].rawTranscript, "hello world")
        XCTAssertEqual(results[0].cleanedText, "Hello world.")
        XCTAssertEqual(results[0].durationSeconds, 3.5)
        XCTAssertTrue(results[0].wasPasted)
        XCTAssertNotNil(results[0].id)
    }

    func testFetchReturnsNewestFirst() throws {
        let db = try DatabaseManager(inMemory: true)

        let older = DictationEntry(
            timestamp: Date(timeIntervalSince1970: 1000),
            durationSeconds: 1.0,
            rawTranscript: "older entry",
            cleanedText: "Older entry.",
            wasPasted: false
        )
        let newer = DictationEntry(
            timestamp: Date(timeIntervalSince1970: 2000),
            durationSeconds: 2.0,
            rawTranscript: "newer entry",
            cleanedText: "Newer entry.",
            wasPasted: true
        )

        try db.insert(older)
        try db.insert(newer)

        let results = try db.fetchAll()
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].rawTranscript, "newer entry")
        XCTAssertEqual(results[1].rawTranscript, "older entry")
    }

    func testSearch() throws {
        let db = try DatabaseManager(inMemory: true)

        let apple = DictationEntry(
            timestamp: Date(),
            durationSeconds: 1.0,
            rawTranscript: "I like apples",
            cleanedText: "I like apples.",
            wasPasted: false
        )
        let banana = DictationEntry(
            timestamp: Date(),
            durationSeconds: 1.0,
            rawTranscript: "I like bananas",
            cleanedText: "I like bananas.",
            wasPasted: false
        )

        try db.insert(apple)
        try db.insert(banana)

        let results = try db.search("apple")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].rawTranscript, "I like apples")
    }

    func testSettings() throws {
        let db = try DatabaseManager(inMemory: true)

        // Initially nil
        let val = try db.getSetting("theme")
        XCTAssertNil(val)

        // Set and get
        try db.setSetting("theme", value: "dark")
        XCTAssertEqual(try db.getSetting("theme"), "dark")

        // Overwrite
        try db.setSetting("theme", value: "light")
        XCTAssertEqual(try db.getSetting("theme"), "light")
    }
}
