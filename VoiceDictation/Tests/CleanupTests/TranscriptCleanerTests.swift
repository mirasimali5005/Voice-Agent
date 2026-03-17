import XCTest
@testable import VoiceDictation

final class TranscriptCleanerTests: XCTestCase {

    func testSanityCheckPassesForReasonableOutput() {
        let input = "um so I need to get uh milk eggs bread and you know some butter from the grocery store"
        let output = "I need to get milk, eggs, bread, and some butter from the grocery store."
        XCTAssertTrue(
            TranscriptCleaner.passesSanityCheck(input: input, output: output),
            "A reasonable cleanup should pass the sanity check"
        )
    }

    func testSanityCheckFailsForTruncatedOutput() {
        let input = """
            So basically what I want to do is like go to the store and um pick up some groceries \
            and then you know come home and like cook dinner for the family and uh maybe watch a \
            movie afterwards if we have time and the kids are not too tired
            """
        let output = "Go store."
        XCTAssertFalse(
            TranscriptCleaner.passesSanityCheck(input: input, output: output),
            "Heavily truncated output should fail the sanity check"
        )
    }

    func testSanityCheckFailsForHallucinatedOutput() {
        let input = "Get milk and eggs."
        let output = """
            Here is your complete grocery list with nutritional information and recommended brands \
            for each item. Milk is an excellent source of calcium and vitamin D. I recommend organic \
            whole milk from a local farm. Eggs should be free range and ideally pastured for the best \
            omega-3 content. You might also want to consider adding bread, butter, cheese, yogurt, \
            and fresh vegetables to round out your shopping trip.
            """
        XCTAssertFalse(
            TranscriptCleaner.passesSanityCheck(input: input, output: output),
            "Hallucinated/expanded output should fail the sanity check"
        )
    }

    func testDefaultSystemPromptContainsKeyPhrases() {
        let prompt = TranscriptCleaner.defaultSystemPrompt
        XCTAssertTrue(prompt.contains("filler words"), "Prompt should mention 'filler words'")
        XCTAssertTrue(prompt.contains("numbered list"), "Prompt should mention 'numbered list'")
        XCTAssertTrue(
            prompt.lowercased().contains("do not rephrase"),
            "Prompt should contain 'do not rephrase'"
        )
    }
}
