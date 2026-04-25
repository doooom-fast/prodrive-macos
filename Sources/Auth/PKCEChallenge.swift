import Foundation
import CryptoKit

struct PKCEChallenge {
    static func make() -> (verifier: String, challenge: String) {
        let verifier = generateVerifier()
        let challenge = generateChallenge(from: verifier)
        return (verifier, challenge)
    }

    private static func generateVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            fatalError("Failed to generate random bytes")
        }
        return base64UrlEncode(Data(bytes))
    }

    private static func generateChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else {
            fatalError("Failed to encode verifier")
        }
        let digest = SHA256.hash(data: data)
        return base64UrlEncode(Data(digest))
    }

    private static func base64UrlEncode(_ data: Data) -> String {
        let base64 = data.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}
