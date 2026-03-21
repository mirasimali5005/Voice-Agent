import Foundation
import GRDB

struct RuleEntry: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    let ruleType: String
    let pattern: String
    var replacement: String?
    var context: String?
    var mode: String?
    var reasoning: String?
    var confidence: Double
    var createdAt: String?
    var updatedAt: String?

    static let databaseTableName = "rules"

    enum CodingKeys: String, CodingKey {
        case id
        case ruleType = "rule_type"
        case pattern
        case replacement
        case context
        case mode
        case reasoning
        case confidence
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: Int64? = nil,
        ruleType: String,
        pattern: String,
        replacement: String? = nil,
        context: String? = nil,
        mode: String? = nil,
        reasoning: String? = nil,
        confidence: Double = 1.0,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.ruleType = ruleType
        self.pattern = pattern
        self.replacement = replacement
        self.context = context
        self.mode = mode
        self.reasoning = reasoning
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
