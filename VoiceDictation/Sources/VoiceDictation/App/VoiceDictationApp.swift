import SwiftUI
import AppKit

@main
struct VoiceDictationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var modelManager = WhisperModelManager.shared

    @State private var orchestrator: DictationOrchestrator?
    @State private var hotkeyListener: HotkeyListener?
    @State private var overlayPanel: RecordingOverlayPanel?
    @State private var databaseManager: DatabaseManager?
    @State private var syncManager: SyncManager?
    @State private var isReady: Bool = false
    @State private var setupError: String?
    @State private var needsModelDownload: Bool = false
    @State private var accessibilityRetryTimer: DispatchSourceTimer?

    var body: some Scene {
        WindowGroup("Voice Agent") {
            Group {
                if let error = setupError {
                    setupErrorView(error)
                } else if needsModelDownload {
                    ModelDownloadView(
                        modelManager: modelManager,
                        modelType: selectedModelType,
                        onComplete: {
                            needsModelDownload = false
                            Task { await setup() }
                        }
                    )
                } else if !isReady {
                    loadingView
                } else if let db = databaseManager {
                    MainTabView(
                        appState: appState,
                        databaseManager: db,
                        syncManager: syncManager
                    )
                }
            }
            .task { await setup() }
        }

        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: appState.isRecording ? "mic.fill" : "mic")
        }
    }

    // MARK: - Subviews

    private func setupErrorView(_ error: String) -> some View {
        ZStack {
            Color(nsColor: NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 72, height: 72)
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(.red.opacity(0.8))
                }
                Text("Setup Failed")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Text(error)
                    .foregroundColor(.white.opacity(0.45))
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                Button("Retry") {
                    setupError = nil
                    Task { await setup() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red.opacity(0.7))
                .controlSize(.large)
            }
            .padding(40)
        }
        .preferredColorScheme(.dark)
        .frame(width: 620, height: 460)
    }

    private var loadingView: some View {
        ZStack {
            Color(nsColor: NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.08))
                        .frame(width: 64, height: 64)
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.red.opacity(0.7))
                }
                VStack(spacing: 6) {
                    Text("Voice Agent")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Setting up...")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(width: 620, height: 460)
    }

    // MARK: - Computed

    private var selectedModelType: WhisperModelType {
        WhisperModelType(rawValue: appState.whisperModelType) ?? .largev3Turbo
    }

    // MARK: - Setup

    @MainActor
    private func setup() async {
        let db: DatabaseManager
        do {
            db = try DatabaseManager()
        } catch {
            setupError = "Failed to initialize database: \(error.localizedDescription)"
            return
        }
        self.databaseManager = db

        let modelType = selectedModelType
        guard modelManager.isModelAvailable(modelType) else {
            needsModelDownload = true
            return
        }

        let engine: WhisperEngine
        do {
            engine = try WhisperEngine(modelPath: modelManager.modelPath(for: modelType))
        } catch {
            setupError = "Failed to load Whisper model: \(error.localizedDescription)"
            return
        }

        let orch = DictationOrchestrator(appState: appState)
        orch.configure(whisperEngine: engine, databaseManager: db)

        // Set up SyncManager with backend URL from AppStorage
        let backendURL = appState.backendURL
        let apiClient = APIClient(baseURL: backendURL)

        // Check for saved auth token
        if let savedToken = try? db.getSetting("authToken"), !savedToken.isEmpty {
            apiClient.authToken = savedToken
        }

        let userId = appState.syncUserId.isEmpty ? UUID().uuidString : appState.syncUserId
        if appState.syncUserId.isEmpty {
            appState.syncUserId = userId
        }

        let sm = SyncManager(apiClient: apiClient, databaseManager: db, userId: userId)
        self.syncManager = sm
        orch.setSyncManager(sm)

        // Start periodic sync if user has an auth token
        if apiClient.authToken != nil {
            sm.startPeriodicSync()
        }

        self.orchestrator = orch

        let panel = RecordingOverlayPanel(appState: appState)
        self.overlayPanel = panel

        let listener = HotkeyListener()
        listener.onAction = { [weak orch] action in
            guard let orch = orch else { return }
            switch action {
            case .startRecording:
                orch.startRecording()
                DispatchQueue.main.async { panel.showWithAnimation() }
            case .stopRecording:
                orch.stopRecording()
                DispatchQueue.main.async { panel.hideWithAnimation() }
            case .cancelRecording:
                orch.cancelRecording()
                DispatchQueue.main.async { panel.hideWithAnimation() }
            case .none:
                break
            }
        }
        self.hotkeyListener = listener

        // Store listener in app delegate for cleanup on quit
        appDelegate.hotkeyListener = listener

        let started = listener.start()
        if !started {
            appState.statusMessage = "⚠️ Accessibility permission needed — go to System Settings > Privacy & Security > Accessibility, remove Voice Agent, re-add it, then restart the app."
            // Start polling — auto-retry every 3 seconds until permission is granted
            startAccessibilityRetry(listener: listener)
        } else {
            appState.statusMessage = ""
        }

        isReady = true
    }

    // MARK: - Accessibility Retry

    /// Polls every 3 seconds to retry creating the event tap.
    /// Once permission is granted, the tap succeeds and polling stops.
    private func startAccessibilityRetry(listener: HotkeyListener) {
        // Cancel any existing timer
        accessibilityRetryTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .seconds(3), repeating: .seconds(3))
        timer.setEventHandler { [weak listener] in
            guard let listener = listener else {
                self.accessibilityRetryTimer?.cancel()
                self.accessibilityRetryTimer = nil
                return
            }

            // Check if Accessibility is now trusted
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
            let trusted = AXIsProcessTrustedWithOptions(options)

            if trusted {
                let started = listener.start()
                if started {
                    self.appState.statusMessage = ""
                    self.accessibilityRetryTimer?.cancel()
                    self.accessibilityRetryTimer = nil
                }
            }
        }
        timer.resume()
        accessibilityRetryTimer = timer
    }
}

// MARK: - App Delegate for clean quit

class AppDelegate: NSObject, NSApplicationDelegate {
    var hotkeyListener: HotkeyListener?

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyListener?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Keep running in menu bar
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        hotkeyListener?.stop()
        return .terminateNow
    }
}
