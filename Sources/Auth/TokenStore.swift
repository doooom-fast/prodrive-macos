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
/// Disk-backed token persistence.
///
/// Earlier this used the macOS keychain. Two problems hit in that order:
///   1. The file-backed login keychain prompts 20+ times per sign-in because
///      ad-hoc-signed dev builds change code signature every rebuild, and
///      each SecItem operation against an existing item requires re-auth.
///   2. Switching to the data-protection keychain
///      (`kSecUseDataProtectionKeychain: true`) eliminated the prompts but
///      returned `errSecMissingEntitlement` (status=-34018) because that
///      keychain requires an `application-identifier` entitlement only
///      provisioned by Apple Developer signing.
///
/// Both paths fail for ad-hoc dev builds. Writing a JSON file under
/// Application Support works with zero signing requirements, is sandboxed
/// to this app's container on signed builds, and is trivial to swap back
/// to the keychain later once there's a real Developer ID signature. The
/// OAuth tokens it stores are short-lived and refreshable, so the reduced
/// confidentiality vs. keychain is acceptable for a logged-in-user context.
final class TokenStore {
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("racing.k10motorsports.prodrive.racecor.mac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("tokens.json")
    }

    func save(accessToken: String, refreshToken: String, expiresAt: Date) {
        let token = Token(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
        do {
            let data = try JSONEncoder().encode(token)
            try data.write(to: fileURL, options: [.atomic])
            // Best-effort POSIX permissions so other users on a shared Mac
            // can't read the file. Signed sandboxed builds get per-app
            // container isolation for free; this is insurance for dev.
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        } catch {
            Log.error("TokenStore save failed: \(error)")
        }
    }

    func load() -> Token? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder.racecor.decode(Token.self, from: data)
        } catch {
            Log.error("TokenStore load failed: \(error)")
            return nil
        }
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
