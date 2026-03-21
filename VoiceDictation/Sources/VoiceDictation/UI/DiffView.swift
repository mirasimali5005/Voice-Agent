import SwiftUI

/// Displays a word-level inline diff between an original and cleaned transcript,
/// with per-change explanations and optional undo actions.
struct DiffView: View {
    let original: String
    let cleaned: String
    let explanations: [ExplainedChange]

    /// Called when the user taps "Undo" on a specific change.
    /// Receives the `ExplainedChange` that should be reverted.
    var onUndo: ((ExplainedChange) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Inline diff text
            inlineDiff

            // Per-change explanations
            if !explanations.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Changes")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                        .textCase(.uppercase)

                    ForEach(explanations) { change in
                        changeRow(change)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Inline Diff

    private var inlineDiff: some View {
        let tokens = buildDiffTokens()
        return DiffTokenTextView(tokens: tokens)
    }

    private func changeRow(_ change: ExplainedChange) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if !change.before.isEmpty {
                        Text(change.before)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .strikethrough()
                    }
                    if !change.before.isEmpty && !change.after.isEmpty {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    if !change.after.isEmpty {
                        Text(change.after)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green.opacity(0.8))
                    }
                }

                Text(change.reason)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(2)
            }

            Spacer()

            if let onUndo = onUndo {
                Button {
                    onUndo(change)
                } label: {
                    Text("Undo")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange.opacity(0.8))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Token Building

    fileprivate enum DiffToken {
        case unchanged(String)
        case removed(String)
        case added(String)
    }

    private func buildDiffTokens() -> [DiffToken] {
        let originalWords = original.split(separator: " ").map(String.init)
        let cleanedWords = cleaned.split(separator: " ").map(String.init)
        let lcs = longestCommonSubsequence(originalWords, cleanedWords)

        var tokens: [DiffToken] = []
        var oi = 0, ei = 0, li = 0

        while oi < originalWords.count || ei < cleanedWords.count {
            if li < lcs.count,
               oi < originalWords.count,
               ei < cleanedWords.count,
               originalWords[oi] == lcs[li],
               cleanedWords[ei] == lcs[li] {
                tokens.append(.unchanged(originalWords[oi]))
                oi += 1; ei += 1; li += 1
            } else if li < lcs.count,
                      oi < originalWords.count,
                      originalWords[oi] != lcs[li],
                      ei < cleanedWords.count,
                      cleanedWords[ei] != lcs[li] {
                tokens.append(.removed(originalWords[oi]))
                tokens.append(.added(cleanedWords[ei]))
                oi += 1; ei += 1
            } else if oi < originalWords.count,
                      (li >= lcs.count || originalWords[oi] != lcs[li]) {
                tokens.append(.removed(originalWords[oi]))
                oi += 1
            } else if ei < cleanedWords.count,
                      (li >= lcs.count || cleanedWords[ei] != lcs[li]) {
                tokens.append(.added(cleanedWords[ei]))
                ei += 1
            }
        }

        return tokens
    }

    private func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count, n = b.count
        guard m > 0, n > 0 else { return [] }
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        var result: [String] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                result.append(a[i - 1])
                i -= 1; j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return result.reversed()
    }
}

// MARK: - Inline diff text rendering

/// Renders diff tokens as a single styled `Text` view with colored words.
private struct DiffTokenTextView: View {
    let tokens: [DiffView.DiffToken]

    var body: some View {
        buildText()
            .font(.system(size: 12))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func buildText() -> Text {
        var combined = Text("")
        var isFirst = true

        for token in tokens {
            let space: Text = isFirst ? Text("") : Text(" ")
            switch token {
            case .unchanged(let word):
                combined = combined + space + Text(word)
                    .foregroundColor(.white.opacity(0.85))
            case .removed(let word):
                combined = combined + space + Text(word)
                    .foregroundColor(.red.opacity(0.7))
                    .strikethrough(true, color: .red.opacity(0.5))
            case .added(let word):
                combined = combined + space + Text(word)
                    .foregroundColor(.green.opacity(0.8))
            }
            isFirst = false
        }

        return combined
    }
}
