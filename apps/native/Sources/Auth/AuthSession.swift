import AppKit
import Foundation

/// Browser-handoff helper for the macOS native app's sign-in flow.
///
/// Sign-in opens `https://prodrive.racecor.io/api/plugin-auth/authorize?…`
/// in the user's default browser. Our server requires a NextAuth session
/// and forwards unauthenticated users through the standard web Discord
/// OAuth flow (the one that already works). After sign-in it redirects to
/// `racecor-native://auth?code=…&state=…`, which macOS routes back into
/// the app via onOpenURL → AuthManager.handleOAuthCallback.
public enum AuthSession {
    public struct AuthError: Error, LocalizedError {
        public let message: String
        public var errorDescription: String? { message }
    }

    @MainActor
    public static func launch(url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}
