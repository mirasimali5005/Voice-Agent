import SwiftUI

struct HistoryView: View {
    @ObservedObject var appState: AppState
    let databaseManager: DatabaseManager

    @StateObject private var lmModelManager = LMStudioModelManager.shared
    @State private var entries: [DictationEntry] = []
    @State private var searchText: String = ""

    private let bgColor = Color(nsColor: NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1))

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Divider()
                    .background(Color.white.opacity(0.06))

                if !appState.statusMessage.isEmpty {
                    statusToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(entries) { entry in
                                HistoryRowView(entry: entry, databaseManager: databaseManager)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 560, minHeight: 420)
        .onAppear { refreshEntries() }
        .onChange(of: appState.lastDictation) { refreshEntries() }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: "waveform")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Voice Agent")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(entries.count) dictation\(entries.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            // Active LLM model pill
            HStack(spacing: 4) {
                Circle()
                    .fill(lmModelManager.loadedModelName == "None" ? Color.orange : Color.green)
                    .frame(width: 5, height: 5)
                Text(lmModelManager.loadedModelName == "None" ? "No model" : lmModelManager.loadedModelName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.04))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5))
            )

            if appState.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                        .shadow(color: .red.opacity(0.6), radius: 4)
                    Text("REC")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.red.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.12))
                        .overlay(Capsule().strokeBorder(Color.red.opacity(0.25), lineWidth: 1))
                )
            }

            searchField
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.35))
                .font(.system(size: 12))
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .font(.system(size: 12))
                .onSubmit { refreshEntries() }
                .onChange(of: searchText) { refreshEntries() }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.3))
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    // MARK: - Status Toast

    private var statusToast: some View {
        HStack(spacing: 8) {
            let isError = appState.statusMessage.lowercased().contains("error") || appState.statusMessage.contains("LM Studio:")
            let isRecording = appState.statusMessage == "Recording..."
            let isProcessing = appState.statusMessage.contains("Processing") || appState.statusMessage.contains("cleaning up")

            Group {
                if isError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                } else if isRecording {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                } else if isProcessing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green.opacity(0.8))
                }
            }
            .font(.system(size: 12))

            Text(appState.statusMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.03))
                        .frame(width: 80, height: 80)
                    Image(systemName: "waveform")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.15))
                }

                VStack(spacing: 6) {
                    Text("No dictations yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                    Text("Hold the Fn key to start dictating")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.2))
                }

                HStack(spacing: 4) {
                    Text("fn")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    Text("hold to record")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.top, 4)
            }
            Spacer()
        }
    }

    private func refreshEntries() {
        do {
            if searchText.isEmpty {
                entries = try databaseManager.fetchAll()
            } else {
                entries = try databaseManager.search(searchText)
            }
        } catch {
            entries = []
        }
    }
}
