import Foundation

/// Compresses a set of rules into compact text suitable for prompt injection.
struct RuleCompressor {

    /// Maximum number of lines in the compressed output.
    static let maxLines = 50

    /// Formats rules into compact text grouped by type.
    /// Returns a string ready for injection into an LLM system prompt.
    static func compress(rules: [RuleEntry]) -> String {
        guard !rules.isEmpty else { return "" }

        // Group rules by type
        var replacements: [RuleEntry] = []
        var style: [RuleEntry] = []
        var formatting: [RuleEntry] = []
        var other: [RuleEntry] = []

        for rule in rules {
            switch rule.ruleType {
            case "replacement":
                replacements.append(rule)
            case "style":
                style.append(rule)
            case "formatting":
                formatting.append(rule)
            default:
                other.append(rule)
            }
        }

        var lines: [String] = []

        if !replacements.isEmpty {
            lines.append("## Replacements")
            for rule in replacements.prefix(maxLines / 3) {
                let replacement = rule.replacement ?? ""
                lines.append("- \"\(rule.pattern)\" -> \"\(replacement)\"")
            }
        }

        if !style.isEmpty {
            lines.append("## Style")
            for rule in style.prefix(maxLines / 3) {
                let desc = rule.replacement ?? rule.reasoning ?? rule.pattern
                lines.append("- \(desc)")
            }
        }

        if !formatting.isEmpty {
            lines.append("## Formatting")
            for rule in formatting.prefix(maxLines / 3) {
                let desc = rule.replacement ?? rule.reasoning ?? rule.pattern
                lines.append("- \(desc)")
            }
        }

        if !other.isEmpty {
            lines.append("## Other")
            for rule in other.prefix(maxLines / 4) {
                let desc = rule.replacement ?? rule.reasoning ?? rule.pattern
                lines.append("- \(desc)")
            }
        }

        // Enforce max line limit
        let truncated = Array(lines.prefix(maxLines))
        return truncated.joined(separator: "\n")
    }
}
