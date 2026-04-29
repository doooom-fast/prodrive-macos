import Foundation
import CryptoKit

/// Derives the LAN-transfer shared key from a Pro Drive bearer token.
/// Both Mac (receiver) and Windows (sender) compute the same key from
/// their own bearer token because both devices are signed in as the
/// same user. The key never travels over the wire — only HMACs do.
///
/// Spec: agents/skills/bundle-transfer/SKILL.md (LAN auth section).
enum SharedKey {

    /// Salt string keeps the key namespaced — bumping it forces a
    /// re-derivation if the protocol ever changes shape.
    static let salt = "prodrive-lan-v1"

    /// SHA256(bearerToken || ":" || salt). Matches the C# derivation in
    /// `prodrive-windows/Sharing/SharedKey.cs`.
    static func derive(bearerToken: String) -> Data {
        let input = "\(bearerToken):\(salt)"
        return Data(SHA256.hash(data: Data(input.utf8)))
    }

    /// HMAC-SHA256 over `bundleId || ":" || timestamp` proves the sender
    /// knows the shared key without revealing it.
    static func sign(bundleId: String, timestamp: Int64, key: Data) -> String {
        let payload = Data("\(bundleId):\(timestamp)".utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: payload, using: SymmetricKey(data: key))
        return Data(mac).base64EncodedString()
    }

    /// Constant-time HMAC verification with a 30-second freshness window.
    static func verify(
        bundleId: String,
        timestamp: Int64,
        signature: String,
        key: Data,
        nowMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> Bool {
        // 30-second window in either direction (clock skew tolerance).
        let skew: Int64 = 30_000
        guard abs(nowMillis - timestamp) <= skew else { return false }

        let expected = sign(bundleId: bundleId, timestamp: timestamp, key: key)
        return constantTimeEquals(expected, signature)
    }

    private static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        guard aBytes.count == bBytes.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<aBytes.count { diff |= aBytes[i] ^ bBytes[i] }
        return diff == 0
    }
}
