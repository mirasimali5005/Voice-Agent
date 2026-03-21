import SwiftUI

struct HistoryRowView: View {
    let entry: DictationEntry
    let databaseManager: DatabaseManager

    @State private var isHovered = false
    @State private var showCopied = false
    @State private var showDiff = false
    @State private var isEditing = false
    @State private var editText: String = ""
    @State private var currentCleanedText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: meta info
            HStack(alignment: .center, spacing: 8) {
                Text(entry.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))

                Text(formattedDuration)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )

                if entry.wasPasted {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: 5, height: 5)
                        Text("Pasted")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.green.opacity(0.7))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.08))
                    )
                }

                Spacer()

                // Why? button — only show if there are actual differences
                if entry.rawTranscript != displayedCleanedText {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showDiff.toggle()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: showDiff ? "chevron.up" : "questionmark.circle")
                                .font(.system(size: 9))
                            Text("Why?")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.purple.opacity(0.7))
                    }
                    .buttonStyle(.borderless)
                    .opacity(isHovered || showDiff ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: isHovered)
                }

                // Edit button
                Button {
                    if isEditing {
                        saveEdit()
                    } else {
                        editText = displayedCleanedText
                        isEditing = true
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isEditing ? "checkmark" : "pencil")
                            .font(.system(size: 10))
                        if isEditing {
                            Text("Done")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundColor(isEditing ? .green.opacity(0.8) : .white.opacity(0.3))
                }
                .buttonStyle(.borderless)
                .opacity(isHovered || isEditing ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: isHovered)

                // Copy button
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(displayedCleanedText, forType: .string)
                    withAnimation(.easeOut(duration: 0.15)) { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showCopied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        if showCopied {
                            Text("Copied")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundColor(showCopied ? .green.opacity(0.8) : .white.opacity(0.3))
                }
                .buttonStyle(.borderless)
                .opacity(isHovered || showCopied ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: isHovered)
            }

            // Dictation text — editable or static
            if isEditing {
                TextEditor(text: $editText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
            } else {
                Text(displayedCleanedText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }

            // Collapsible diff view
            if showDiff {
                diffSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isHovered ? 0.06 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(isHovered ? 0.1 : 0.05), lineWidth: 0.5)
                )
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            currentCleanedText = entry.cleanedText
        }
    }

    // MARK: - Diff Section

    private var diffSection: some View {
        let changes = DiffEngine.diff(original: entry.rawTranscript, edited: displayedCleanedText)
        let rules = (try? databaseManager.fetchRules()) ?? []
        let explanations = ChangeExplainer.explain(changes: changes, rules: rules)

        return DiffView(
            original: entry.rawTranscript,
            cleaned: displayedCleanedText,
            explanations: explanations,
            onUndo: { change in
                undoChange(change)
            }
        )
    }

    // MARK: - Helpers

    private var displayedCleanedText: String {
        currentCleanedText.isEmpty ? entry.cleanedText : currentCleanedText
    }

    private var formattedDuration: String {
        let totalSeconds = Int(entry.durationSeconds)
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if seconds == 0 {
            return "\(minutes)m"
        }
        return "\(minutes)m \(seconds)s"
    }

    // MARK: - Edit / Correction

    /// Save the edited text silently — no popup, no notification.
    /// Computes diff, stores each change as a CorrectionEntry, updates the database.
    private func saveEdit() {
        let oldText = displayedCleanedText
        let newText = editText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !newText.isEmpty, newText != oldText else {
            isEditing = false
            return
        }

        // Compute word-level changes for silent correction capture
        let changes = DiffEngine.diff(original: oldText, edited: newText)

        for change in changes {
            let correction = CorrectionEntry(
                beforeText: change.before,
                afterText: change.after
            )
            _ = try? databaseManager.insertCorrection(correction)
        }

        // Persist the updated cleaned text
        try? databaseManager.updateCleanedText(id: entry.id, cleanedText: newText)
        currentCleanedText = newText
        isEditing = false
    }

    /// Undo a single word change by replacing the `after` word back with the `before` word
    /// in the current cleaned text.
    private func undoChange(_ change: ExplainedChange) {
        var text = displayedCleanedText

        if change.before.isEmpty {
            // Word was added — remove it
            text = text.replacingFirstOccurrence(of: change.after, with: "")
        } else if change.after.isEmpty {
            // Word was removed — add it back
            text = text + " " + change.before
        } else {
            // Word was replaced — revert to original
            text = text.replacingFirstOccurrence(of: change.after, with: change.before)
        }

        // Clean up double spaces
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        try? databaseManager.updateCleanedText(id: entry.id, cleanedText: text)
        currentCleanedText = text
    }
}

// MARK: - String helper

private extension String {
    /// Replace only the first occurrence of a substring.
    func replacingFirstOccurrence(of target: String, with replacement: String) -> String {
        guard let range = self.range(of: target) else { return self }
        return self.replacingCharacters(in: range, with: replacement)
    }
}
