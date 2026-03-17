import SwiftUI

struct HistoryRowView: View {
    let entry: DictationEntry

    @State private var isHovered = false
    @State private var showCopied = false

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

                // Copy button
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.cleanedText, forType: .string)
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

            // Dictation text
            Text(entry.cleanedText)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
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
}
