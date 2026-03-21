import Foundation
import Combine

/// Manages bidirectional sync between local SQLite and the Spring Boot backend.
final class SyncManager: ObservableObject {

    // MARK: - Published State

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?

    // MARK: - Dependencies

    private let apiClient: APIClient
    private let databaseManager: DatabaseManager
    private let userId: String

    private var syncTimer: Timer?

    // MARK: - Init

    init(apiClient: APIClient, databaseManager: DatabaseManager, userId: String) {
        self.apiClient = apiClient
        self.databaseManager = databaseManager
        self.userId = userId
    }

    deinit {
        syncTimer?.invalidate()
    }

    // MARK: - Sync Corrections

    /// Fetches unsynced corrections from local DB, POSTs them to the API, and marks them synced.
    func syncCorrections() async {
        do {
            let unsynced = try databaseManager.fetchUnsyncedCorrections()
            guard !unsynced.isEmpty else { return }

            let dtos = unsynced.map { entry in
                APICorrectionDTO(
                    userId: userId,
                    beforeText: entry.beforeText,
                    afterText: entry.afterText,
                    context: entry.context,
                    mode: entry.mode,
                    count: entry.count
                )
            }

            _ = try await apiClient.post(path: "/api/corrections", body: dtos)

            let ids = unsynced.compactMap { $0.id }
            try databaseManager.markCorrectionsSynced(ids: ids)
        } catch {
            print("[SyncManager] syncCorrections failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch Rules

    /// GETs compressed rules from the API and stores them locally. Returns the rules string.
    @discardableResult
    func fetchRules() async -> String? {
        do {
            let data = try await apiClient.get(
                path: "/api/rules",
                params: ["userId": userId]
            )

            let decoded = try JSONDecoder().decode(APIRuleResponse.self, from: data)
            try databaseManager.setSetting("syncedRules", value: decoded.rules)
            return decoded.rules
        } catch {
            print("[SyncManager] fetchRules failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Sync Settings

    /// POSTs each setting individually to the API.
    func syncSettings(customPrompt: String, mode: String) async {
        let settings: [(key: String, value: String)] = [
            ("customPrompt", customPrompt),
            ("mode", mode),
        ]

        for setting in settings {
            let dto = APISettingsDTO(userId: userId, key: setting.key, value: setting.value)
            do {
                _ = try await apiClient.post(path: "/api/settings", body: dto)
            } catch {
                print("[SyncManager] syncSettings(\(setting.key)) failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Full Sync

    /// Runs a complete sync cycle: corrections, rules, then settings.
    func fullSync() async {
        guard apiClient.authToken != nil else { return }

        await MainActor.run { isSyncing = true }

        await syncCorrections()
        await fetchRules()

        // Sync current settings from local storage
        let customPrompt = (try? databaseManager.getSetting("customPrompt")) ?? ""
        let mode = (try? databaseManager.getSetting("dictationMode")) ?? "casual"
        await syncSettings(customPrompt: customPrompt, mode: mode)

        await MainActor.run {
            lastSyncDate = Date()
            isSyncing = false
        }
    }

    // MARK: - Periodic Sync

    /// Starts a repeating timer that triggers `fullSync()` at the given interval.
    /// Only syncs when the user is authenticated (authToken is set).
    func startPeriodicSync(interval: TimeInterval = 300) {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.apiClient.authToken != nil else { return }
            Task {
                await self.fullSync()
            }
        }
    }

    /// Stops the periodic sync timer.
    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
}
