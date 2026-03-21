import Foundation

/// Represents a single explained change with optional rule attribution.
struct ExplainedChange: Identifiable {
    let id = UUID()
    let before: String
    let after: String
    let reason: String
    let ruleId: Int64?
}

/// Matches word-level changes to known rules and produces human-readable explanations.
struct ChangeExplainer {

    /// For each `WordChange`, attempt to find a matching `RuleEntry` and produce
    /// an `ExplainedChange` with a human-readable reason.
    static func explain(changes: [WordChange], rules: [RuleEntry]) -> [ExplainedChange] {
        var result: [ExplainedChange] = []

        for change in changes {
            let matchingRule = rules.first { rule in
                rule.pattern == change.before && rule.replacement == change.after
            }

            let reason: String
            let ruleId: Int64?

            if let rule = matchingRule {
                reason = rule.reasoning
                    ?? "User corrected \(rule.pattern) \u{2192} \(rule.replacement ?? "")"
                ruleId = rule.id
            } else {
                reason = "Cleaned by AI"
                ruleId = nil
            }

            let explained = ExplainedChange(
                before: change.before,
                after: change.after,
                reason: reason,
                ruleId: ruleId
            )
            result.append(explained)
        }

        return result
    }
}
