import Foundation
import Security

/// Speichert den Anthropic API-Schlüssel sicher im Schlüsselbund des iPhones.
struct APIKeyStore {
    var service = "ch.murtit.feins"
    var account = "anthropic-api-key"

    /// Schlüssel aus dem Schlüsselbund; beim Entwickeln alternativ über die Umgebungsvariable `ANTHROPIC_API_KEY` im Xcode-Schema.
    func load() -> String? {
        if let fromEnvironment = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !fromEnvironment.isEmpty {
            return fromEnvironment
        }
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    func save(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        SecItemDelete(baseQuery as CFDictionary)
        guard !trimmed.isEmpty else { return }
        var query = baseQuery
        query[kSecValueData as String] = Data(trimmed.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
