import XCTest
@testable import VoiceDictation

final class RuleCompressorTests: XCTestCase {

    func testEmptyRules() {
        let result = RuleCompressor.compress(rules: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testReplacementRules() {
        let rules = [
            RuleEntry(ruleType: "replacement", pattern: "gonna", replacement: "going to"),
            RuleEntry(ruleType: "replacement", pattern: "wanna", replacement: "want to"),
        ]

        let result = RuleCompressor.compress(rules: rules)
        XCTAssertTrue(result.contains("## Replacements"))
        XCTAssertTrue(result.contains("\"gonna\" -> \"going to\""))
        XCTAssertTrue(result.contains("\"wanna\" -> \"want to\""))
    }

    func testGroupsByType() {
        let rules = [
            RuleEntry(ruleType: "replacement", pattern: "gonna", replacement: "going to"),
            RuleEntry(ruleType: "style", pattern: "formal", replacement: "Use formal tone"),
            RuleEntry(ruleType: "formatting", pattern: "bullets", replacement: "Use bullet points"),
        ]

        let result = RuleCompressor.compress(rules: rules)
        XCTAssertTrue(result.contains("## Replacements"))
        XCTAssertTrue(result.contains("## Style"))
        XCTAssertTrue(result.contains("## Formatting"))
    }

    func testMaxLineLimit() {
        // Create many rules to test truncation
        let rules = (0..<100).map { i in
            RuleEntry(ruleType: "replacement", pattern: "word\(i)", replacement: "replaced\(i)")
        }

        let result = RuleCompressor.compress(rules: rules)
        let lineCount = result.components(separatedBy: "\n").count
        XCTAssertLessThanOrEqual(lineCount, RuleCompressor.maxLines)
    }

    func testOtherRuleType() {
        let rules = [
            RuleEntry(ruleType: "custom", pattern: "test", reasoning: "Custom rule reasoning"),
        ]

        let result = RuleCompressor.compress(rules: rules)
        XCTAssertTrue(result.contains("## Other"))
        XCTAssertTrue(result.contains("Custom rule reasoning"))
    }
}
