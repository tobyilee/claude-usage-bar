import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case notFound
    case decodingFailed(String)
    case osStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Keychain item 'Claude Code-credentials' not found. Run `claude` to log in."
        case .decodingFailed(let msg):
            return "Keychain JSON decode failed: \(msg)"
        case .osStatus(let s):
            return "Keychain OSStatus \(s)"
        }
    }
}

struct StoredCreds {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date?
    var subscriptionType: String?
    var account: String
}

enum KeychainCredentials {
    static let service = "Claude Code-credentials"

    static func read() throws -> StoredCreds {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
            kSecReturnAttributes: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.osStatus(status) }
        guard let dict = result as? [String: Any],
              let data = dict[kSecValueData as String] as? Data,
              let account = dict[kSecAttrAccount as String] as? String else {
            throw KeychainError.decodingFailed("missing kSecValueData or kSecAttrAccount")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String,
              let refreshToken = oauth["refreshToken"] as? String else {
            throw KeychainError.decodingFailed("claudeAiOauth shape unexpected")
        }
        var expires: Date?
        if let n = oauth["expiresAt"] as? Double {
            expires = decodeEpoch(n)
        } else if let s = oauth["expiresAt"] as? String, let n = Double(s) {
            expires = decodeEpoch(n)
        }
        let tier = oauth["subscriptionType"] as? String
        return StoredCreds(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expires,
            subscriptionType: tier,
            account: account
        )
    }

    /// Write back an updated token triple, preserving any unknown fields in the existing JSON
    /// (e.g. `scopes`, `subscriptionType`) so Claude Code itself stays authenticated.
    static func update(accessToken: String, refreshToken: String, expiresAt: Date, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.osStatus(status)
        }
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var oauth = json["claudeAiOauth"] as? [String: Any] else {
            throw KeychainError.decodingFailed("update: claudeAiOauth missing")
        }
        oauth["accessToken"] = accessToken
        oauth["refreshToken"] = refreshToken
        oauth["expiresAt"] = Int(expiresAt.timeIntervalSince1970 * 1000)
        json["claudeAiOauth"] = oauth
        let newData = try JSONSerialization.data(withJSONObject: json)

        let updateQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let attrs: [CFString: Any] = [kSecValueData: newData]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attrs as CFDictionary)
        guard updateStatus == errSecSuccess else { throw KeychainError.osStatus(updateStatus) }
    }
}

private func decodeEpoch(_ n: Double) -> Date {
    n > 10_000_000_000 ? Date(timeIntervalSince1970: n / 1000) : Date(timeIntervalSince1970: n)
}
