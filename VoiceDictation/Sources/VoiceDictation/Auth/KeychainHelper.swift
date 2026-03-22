import Foundation
import Security

/// Lightweight wrapper around the macOS Keychain for storing auth credentials.
struct KeychainHelper {

    private static let serviceName = "com.voiceagent.app"

    // MARK: - Save

    /// Stores `data` in the Keychain under the given key, replacing any existing item.
    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        // Remove any existing item first to avoid errSecDuplicateItem
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Load

    /// Returns the data stored under `key`, or `nil` if not found.
    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - Delete

    /// Removes the item stored under `key`. Returns `true` if the item was deleted
    /// (or didn't exist in the first place).
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
