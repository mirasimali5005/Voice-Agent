import XCTest
@testable import VoiceDictation

final class PatternMatcherTests: XCTestCase {

    func testGeneratesRuleWhenCountMeetsThreshold() {
        let corrections = (0..<5).map { _ in
            CorrectionEntry(beforeText: "gonna", afterText: "going to")
        }

        let rules = PatternMatcher.generateRules(from: corrections)
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].pattern, "gonna")
        XCTAssertEqual(rules[0].replacement, "going to")
        XCTAssertEqual(rules[0].ruleType, "replacement")
        XCTAssertGreaterThan(rules[0].confidence, 0)
    }

    func testDoesNotGenerateRuleBelowThreshold() {
        let corrections = [
            CorrectionEntry(beforeText: "gonna", afterText: "going to"),
            CorrectionEntry(beforeText: "gonna", afterText: "going to"),
        ]

        let rules = PatternMatcher.generateRules(from: corrections)
        XCTAssertTrue(rules.isEmpty)
    }

    func testDeduplicatesAgainstExistingRules() {
        let corrections = (0..<5).map { _ in
            CorrectionEntry(beforeText: "gonna", afterText: "going to")
        }

        let existingRules = [
            RuleEntry(ruleType: "replacement", pattern: "gonna", replacement: "going to")
        ]

        let rules = PatternMatcher.generateRules(from: corrections, existingRules: existingRules)
        XCTAssertTrue(rules.isEmpty)
    }

    func testEmptyCorrections() {
        let rules = PatternMatcher.generateRules(from: [])
        XCTAssertTrue(rules.isEmpty)
    }

    func testMultiplePatterns() {
        var corrections: [CorrectionEntry] = []
        for _ in 0..<4 {
            corrections.append(CorrectionEntry(beforeText: "gonna", afterText: "going to"))
        }
        for _ in 0..<3 {
            corrections.append(CorrectionEntry(beforeText: "wanna", afterText: "want to"))
        }

        let rules = PatternMatcher.generateRules(from: corrections)
        XCTAssertEqual(rules.count, 2)
        let patterns = Set(rules.map(\.pattern))
        XCTAssertTrue(patterns.contains("gonna"))
        XCTAssertTrue(patterns.contains("wanna"))
    }

    func testConfidenceCalculation() {
        var corrections: [CorrectionEntry] = []
        for _ in 0..<3 {
            corrections.append(CorrectionEntry(beforeText: "gonna", afterText: "going to"))
        }
        for _ in 0..<7 {
            corrections.append(CorrectionEntry(beforeText: "wanna", afterText: "want to"))
        }

        let rules = PatternMatcher.generateRules(from: corrections)
        let gonnaRule = rules.first { $0.pattern == "gonna" }
        let wannaRule = rules.first { $0.pattern == "wanna" }

        XCTAssertNotNil(gonnaRule)
        XCTAssertNotNil(wannaRule)
        // wanna has more corrections so should have higher confidence
        if let g = gonnaRule, let w = wannaRule {
            XCTAssertGreaterThan(w.confidence, g.confidence)
        }
    }
}
