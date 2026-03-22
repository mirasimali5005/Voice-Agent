import Foundation

/// Analyzes accumulated corrections to generate reusable replacement rules.
struct PatternMatcher {

    /// Minimum number of identical corrections needed before promoting to a rule.
    static let minimumCount = 3

    /// Generates rules from a list of corrections.
    /// Groups corrections by (beforeText -> afterText), and if a group appears
    /// at least `minimumCount` times, creates a replacement rule with confidence
    /// proportional to the group size.
    static func generateRules(
        from corrections: [CorrectionEntry],
        existingRules: [RuleEntry] = []
    ) -> [RuleEntry] {
        guard !corrections.isEmpty else { return [] }

        // Group corrections by (before, after)
        var groups: [String: (after: String, count: Int)] = [:]
        for correction in corrections {
            let key = correction.beforeText
            if let existing = groups[key], existing.after == correction.afterText {
                groups[key] = (after: correction.afterText, count: existing.count + correction.count)
            } else if groups[key] == nil {
                groups[key] = (after: correction.afterText, count: correction.count)
            }
        }

        let totalCorrections = max(corrections.count, 1)

        // Build set of existing rule patterns for deduplication
        let existingPatterns = Set(existingRules.map { "\($0.pattern)->\($0.replacement ?? "")" })

        var rules: [RuleEntry] = []
        for (before, value) in groups where value.count >= minimumCount {
            let key = "\(before)->\(value.after)"
            guard !existingPatterns.contains(key) else { continue }

            let confidence = Double(value.count) / Double(totalCorrections)
            let rule = RuleEntry(
                ruleType: "replacement",
                pattern: before,
                replacement: value.after,
                reasoning: "Auto-generated from \(value.count) corrections",
                confidence: min(confidence, 1.0)
            )
            rules.append(rule)
        }

        return rules.sorted { $0.confidence > $1.confidence }
    }
}
