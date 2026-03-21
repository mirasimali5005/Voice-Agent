import Foundation

/// DTO matching the Spring Boot CorrectionDTO format for syncing corrections.
struct APICorrectionDTO: Codable {
    let userId: String
    let beforeText: String
    let afterText: String
    let context: String?
    let mode: String?
    let count: Int
}

/// DTO for the rules response from the Spring Boot API.
struct APIRuleResponse: Codable {
    let rules: String
}

/// DTO for syncing individual settings to the Spring Boot API.
struct APISettingsDTO: Codable {
    let userId: String
    let key: String
    let value: String
}
