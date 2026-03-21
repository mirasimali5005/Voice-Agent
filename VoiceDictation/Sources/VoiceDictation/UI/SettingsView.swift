import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    let databaseManager: DatabaseManager
    var syncManager: SyncManager?

    var body: some View {
        TabView {
            GeneralTab(appState: appState)
                .tabItem { Label("General", systemImage: "gear") }

            ModelsTab()
                .tabItem { Label("Models", systemImage: "cpu") }

            PromptTab(databaseManager: databaseManager)
                .tabItem { Label("Prompt", systemImage: "text.quote") }

            WhisperTab(appState: appState)
                .tabItem { Label("Whisper", systemImage: "waveform") }

            SyncTab(appState: appState, syncManager: syncManager)
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 520, height: 420)
        .preferredColorScheme(.dark)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section {
                LabeledContent("Hotkey") {
                    Text("Hold Fn (Globe) key to record")
                        .foregroundColor(.secondary)
                }

                Toggle("Launch at login", isOn: $appState.launchAtLogin)
            }

            Section("LM Studio Connection") {
                TextField("Endpoint", text: $appState.lmStudioEndpoint)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Models Tab (LM Studio model switcher)

private struct ModelsTab: View {
    @StateObject private var modelManager = LMStudioModelManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Currently loaded model
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Loaded Model")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(modelManager.loadedModelName == "None" ? Color.orange : Color.green)
                            .frame(width: 7, height: 7)
                        Text(modelManager.loadedModelName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                Spacer()
                if modelManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                if modelManager.loadedModelName != "None" {
                    Button("Unload") {
                        modelManager.unloadAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.04))

            Divider()

            if let error = modelManager.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.08))
            }

            HStack {
                Text("Available Models")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    modelManager.refreshAvailableModels()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            if modelManager.availableModels.isEmpty {
                VStack(spacing: 8) {
                    Text("Click refresh to load model list")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(modelManager.availableModels) { model in
                            ModelRow(
                                model: model,
                                isLoaded: modelManager.loadedModelName.contains(
                                    model.id.components(separatedBy: "/").last ?? ""
                                ),
                                isLoading: modelManager.isLoading,
                                onLoad: {
                                    modelManager.loadModel(model.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .onAppear {
            modelManager.refreshAvailableModels()
            modelManager.refreshLoadedModel()
        }
    }
}

private struct ModelRow: View {
    let model: LMModel
    let isLoaded: Bool
    let isLoading: Bool
    let onLoad: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.id.components(separatedBy: "/").last ?? model.id)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(model.params)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.06)))

                    Text(model.arch)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(model.size)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isLoaded {
                Text("Loaded")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.green.opacity(0.1)))
            } else {
                Button("Load") {
                    onLoad()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLoading)
                .opacity(isHovered ? 1 : 0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(isHovered ? 0.05 : 0.02))
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Prompt Tab

private struct PromptTab: View {
    let databaseManager: DatabaseManager

    @State private var promptText: String = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("System Prompt")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if saved {
                    Text("Saved!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }

            Text("This prompt tells the LLM how to clean up your dictations. Edits take effect on the next recording.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextEditor(text: $promptText)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )

            HStack {
                Button("Reset to Default") {
                    promptText = TranscriptCleaner.defaultSystemPrompt
                    savePrompt()
                }
                .controlSize(.small)

                Spacer()

                Button("Save") {
                    savePrompt()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)
            }
        }
        .padding(16)
        .onAppear { loadPrompt() }
    }

    private func loadPrompt() {
        if let stored = try? databaseManager.getSetting("cleanupPrompt") {
            promptText = stored
        } else {
            promptText = TranscriptCleaner.defaultSystemPrompt
        }
    }

    private func savePrompt() {
        try? databaseManager.setSetting("cleanupPrompt", value: promptText)
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saved = false }
        }
    }
}

// MARK: - Whisper Tab

private struct WhisperTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section {
                Picker("Model", selection: $appState.whisperModelType) {
                    ForEach(WhisperModelType.allCases) { modelType in
                        Text(modelType.displayName).tag(modelType.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Sync Tab

private struct SyncTab: View {
    @ObservedObject var appState: AppState
    var syncManager: SyncManager?

    @State private var isSyncing = false
    @State private var lastSyncText = "Never"

    var body: some View {
        Form {
            Section("Backend Connection") {
                TextField("Backend URL", text: $appState.backendURL)
                    .textFieldStyle(.roundedBorder)

                LabeledContent("Status") {
                    if isSyncing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Syncing...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                            Text("Ready")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                LabeledContent("Last Sync") {
                    Text(lastSyncText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button {
                    guard let sm = syncManager else { return }
                    isSyncing = true
                    Task {
                        await sm.fullSync()
                        await MainActor.run {
                            isSyncing = false
                            updateLastSyncText()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                    }
                }
                .disabled(syncManager == nil || isSyncing)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            updateLastSyncText()
        }
    }

    private func updateLastSyncText() {
        if let date = syncManager?.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            lastSyncText = formatter.localizedString(for: date, relativeTo: Date())
        } else {
            lastSyncText = "Never"
        }
    }
}
