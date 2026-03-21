import Foundation
import GRDB

struct CorrectionEntry: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    let beforeText: String
    let afterText: String
    var context: String?
    var mode: String?
    var count: Int
    var autoRule: Bool
    var synced: Bool
    var createdAt: String?

    static let databaseTableName = "corrections"

    enum CodingKeys: String, CodingKey {
        case id
        case beforeText = "before_text"
        case afterText = "after_text"
        case context
        case mode
        case count
        case autoRule = "auto_rule"
        case synced
        case createdAt = "created_at"
    }

    init(
        id: Int64? = nil,
        beforeText: String,
        afterText: String,
        context: String? = nil,
        mode: String? = nil,
        count: Int = 1,
        autoRule: Bool = false,
        synced: Bool = false,
        createdAt: String? = nil
    ) {
        self.id = id
        self.beforeText = beforeText
        self.afterText = afterText
        self.context = context
        self.mode = mode
        self.count = count
        self.autoRule = autoRule
        self.synced = synced
        self.createdAt = createdAt
    }
}
