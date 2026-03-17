import Foundation
import GRDB

final class DatabaseManager {
    private let dbQueue: DatabaseQueue

    init(inMemory: Bool = false) throws {
        if inMemory {
            dbQueue = try DatabaseQueue()
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!.appendingPathComponent("VoiceDictation")

            try FileManager.default.createDirectory(
                at: appSupport,
                withIntermediateDirectories: true
            )

            let dbPath = appSupport.appendingPathComponent("dictations.sqlite").path
            dbQueue = try DatabaseQueue(path: dbPath)
        }

        try migrate()
    }

    // MARK: - Migrations

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "dictations") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull()
                t.column("durationSeconds", .double).notNull()
                t.column("rawTranscript", .text).notNull()
                t.column("cleanedText", .text).notNull()
                t.column("wasPasted", .boolean).notNull()
            }
        }

        migrator.registerMigration("v1_settings") { db in
            try db.create(table: "settings") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Dictation CRUD

    @discardableResult
    func insert(_ entry: DictationEntry) throws -> DictationEntry {
        try dbQueue.write { db in
            var entry = entry
            try entry.insert(db)
            return entry
        }
    }

    func fetchAll(limit: Int = 100) throws -> [DictationEntry] {
        try dbQueue.read { db in
            try DictationEntry
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func search(_ query: String) throws -> [DictationEntry] {
        let pattern = "%\(query)%"
        return try dbQueue.read { db in
            try DictationEntry
                .filter(
                    Column("cleanedText").like(pattern)
                    || Column("rawTranscript").like(pattern)
                )
                .order(Column("timestamp").desc)
                .fetchAll(db)
        }
    }

    /// Update just the cleanedText for an entry (used when LLM cleanup finishes in background)
    func updateCleanedText(id: Int64?, cleanedText: String) throws {
        guard let id = id else { return }
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE dictations SET cleanedText = ? WHERE id = ?",
                arguments: [cleanedText, id]
            )
        }
    }

    // MARK: - Settings

    func getSetting(_ key: String) throws -> String? {
        try dbQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT value FROM settings WHERE key = ?",
                arguments: [key]
            )
        }
    }

    func setSetting(_ key: String, value: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
                arguments: [key, value]
            )
        }
    }
}
