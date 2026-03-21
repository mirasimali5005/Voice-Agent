import Foundation

/// Represents a single word-level change between the original and edited text.
struct WordChange: Equatable {
    let before: String
    let after: String
}

/// Computes word-level diffs between an original transcript and a user-edited version.
struct DiffEngine {

    /// Returns an array of `WordChange` representing words that were changed, added, or removed.
    /// Uses Longest Common Subsequence (LCS) to align words before extracting changes.
    static func diff(original: String, edited: String) -> [WordChange] {
        let originalWords = original.split(separator: " ").map(String.init)
        let editedWords = edited.split(separator: " ").map(String.init)

        let lcs = longestCommonSubsequence(originalWords, editedWords)

        var changes: [WordChange] = []
        var oi = 0
        var ei = 0
        var li = 0

        while oi < originalWords.count || ei < editedWords.count {
            if li < lcs.count,
               oi < originalWords.count,
               ei < editedWords.count,
               originalWords[oi] == lcs[li],
               editedWords[ei] == lcs[li] {
                // Both match the LCS element — no change
                oi += 1
                ei += 1
                li += 1
            } else if li < lcs.count,
                      oi < originalWords.count,
                      originalWords[oi] != lcs[li],
                      ei < editedWords.count,
                      editedWords[ei] != lcs[li] {
                // Both differ from LCS — this is a replacement
                changes.append(WordChange(before: originalWords[oi], after: editedWords[ei]))
                oi += 1
                ei += 1
            } else if oi < originalWords.count,
                      (li >= lcs.count || originalWords[oi] != lcs[li]) {
                // Original word not in LCS — it was deleted
                changes.append(WordChange(before: originalWords[oi], after: ""))
                oi += 1
            } else if ei < editedWords.count,
                      (li >= lcs.count || editedWords[ei] != lcs[li]) {
                // Edited word not in LCS — it was inserted
                changes.append(WordChange(before: "", after: editedWords[ei]))
                ei += 1
            }
        }

        return changes
    }

    // MARK: - LCS

    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count
        let n = b.count
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

        // Backtrack to find the actual subsequence
        var result: [String] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                result.append(a[i - 1])
                i -= 1
                j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        return result.reversed()
    }
}
