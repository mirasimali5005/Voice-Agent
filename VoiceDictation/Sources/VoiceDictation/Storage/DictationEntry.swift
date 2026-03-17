import Foundation
import GRDB

struct DictationEntry: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    let timestamp: Date
    let durationSeconds: Double
    let rawTranscript: String
    var cleanedText: String
    let wasPasted: Bool

    static let databaseTableName = "dictations"
}
