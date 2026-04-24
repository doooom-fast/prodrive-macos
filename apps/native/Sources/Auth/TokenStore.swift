import Foundation

struct Token: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

/// Persists OAuth tokens to the macOS **data-protection keychain**.
///
/// Why the data-protection keychain specifically:
///   The default macOS keychain is the file-backed "login" keychain, which
///   gates access on the app's code signature. In a dev build, the
///   signature changes every rebuild (ad-hoc signing re-generates it),
///   which produces the "RaceCorProDrive wants to use your confidential
///   information stored in 'racing.k10motorsports.prodrive.racecor.mac' in
///   your keychain" prompt — once per keychain item per access. With 3
///   items × a few ops per sign-in that's 20+ prompts.
///
///   `kSecUseDataProtectionKeychain: true` makes SecItem APIs use the
///   iOS-style keychain backing that's bound by bundle ID + entitlement,
///   not file-keychain ACL, so there's no login keychain unlock prompt.
///
/// Why one item (not three):
///   Collapsing (accessToken, refreshToken, expiresAt) into a single
///   JSON-encoded keychain entry halves the number of SecItem calls. Even
///   if something ever forced a prompt, it would be 1 prompt, not 3.
final class TokenStore {
    private let service = "racing.k10motorsports.prodrive.racecor.mac"
    private let account = "tokens.v1"

    func save(accessToken: String, refreshToken: String, expiresAt: Date) {
        let token = Token(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
        guard let data = try? JSONEncoder().encode(token) else {
            Log.error("TokenStore save: failed to encode token JSON")
            return
        }

        // Delete then add — SecItemAdd rejects duplicates.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            Log.error("TokenStore save: SecItemAdd status=\(status)")
        }
    }

    func load() -> Token? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                Log.error("TokenStore load: SecItemCopyMatching status=\(status)")
            }
            return nil
        }

        return try? JSONDecoder.racecor.decode(Token.self, from: data)
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
