import Foundation
import SwiftUI

/// Sign-in driver for the macOS native app.
///
/// Flow: signIn() generates PKCE, opens
/// `https://prodrive.racecor.io/api/plugin-auth/authorize?…` in the default
/// browser via NSWorkspace. The server requires a NextAuth session;
/// unauthenticated users get forwarded through the standard web Discord
/// OAuth flow (known-good, uses the already-registered
/// /api/auth/callback/discord redirect). After sign-in, the server mints
/// an auth code bound to our PKCE challenge and redirects to
/// `racecor-native://auth?code=…&state=…`. macOS routes that URL back
/// into the app via onOpenURL → handleOAuthCallback, which exchanges code +
/// verifier at /api/plugin-auth/token. The PKCE verifier is held in
/// `pendingVerifier` across the out-of-app gap — regenerating it inside
/// exchangeCode() would break the challenge match.
///
/// Earlier iteration attempted a "Discord-direct" flow that opened
/// discord.com OAuth URLs directly from the native app. Discord's AASA
/// explicitly excludes /oauth2/authorize URLs from Universal Links, so the
/// Discord app hand-off never worked, and the registered redirect URI for
/// that flow was not honored by Discord's OAuth validator despite showing
/// in the portal UI. That flow (native-init + discord-native-callback) is
/// removed in favor of reusing the proven-working web path.
@MainActor
final class AuthManager: ObservableObject {
    enum State {
        case loggedOut
        case authenticating
        case authenticated(user: Me)
    }

    @Published var state: State = .loggedOut

    private var pendingVerifier: String?
    private var pendingState: String?

    // UserDefaults keys for cross-process PKCE handoff. If Launch Services
    // ever decides to spawn a fresh instance to handle the OAuth callback
    // URL, the receiving process reads the pending verifier + state from
    // here instead of an empty in-memory property. The window is narrow
    // (written in signIn(), deleted in handleOAuthCallback) and gated by
    // the PKCE `state` nonce.
    private static let defaultsVerifierKey = "racecor.pendingOAuth.verifier"
    private static let defaultsStateKey = "racecor.pendingOAuth.state"

    private let tokenStore = TokenStore()
    private let apiClient: APIClient

    private let clientId = "racing.k10motorsports.prodrive.racecor.mac"
    // Uses `racecor-native://` (not `racecor-prodrive://`) to avoid colliding
    // with the Electron shell at Launch Services: the shell's dev mode
    // registers its node_modules Electron as the `racecor-prodrive://`
    // handler, which then catches the native app's OAuth callback and shows
    // Electron's default welcome page instead of routing to this app.
    private let redirectUri = "racecor-native://auth"

    init() {
        apiClient = APIClient.shared
        Task { await restore() }
    }

    func signIn() {
        Task {
            self.state = .authenticating

            let (verifier, challenge) = PKCEChallenge.make()
            let nativeState = UUID().uuidString
            self.pendingVerifier = verifier
            self.pendingState = nativeState
            // Mirror to UserDefaults so any process (including one newly
            // spawned by Launch Services to handle the callback URL) can
            // resume the exchange. See defaultsVerifierKey comment.
            UserDefaults.standard.set(verifier, forKey: Self.defaultsVerifierKey)
            UserDefaults.standard.set(nativeState, forKey: Self.defaultsStateKey)

            // Open the server's existing /api/plugin-auth/authorize endpoint
            // directly. That endpoint requires a NextAuth session; if the
            // user isn't signed in yet it forwards them through the WEB
            // Discord OAuth flow (which uses /api/auth/callback/discord —
            // a redirect URI Discord already accepts). After sign-in, the
            // server generates a plugin auth code bound to our PKCE
            // challenge and redirects to `racecor-native://auth?code=...`.
            //
            // This reuses the proven-working web auth path. No Discord
            // portal config for native callbacks is needed.
            var components = URLComponents(string: "https://prodrive.racecor.io/api/plugin-auth/authorize")!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "redirect_uri", value: redirectUri),
                URLQueryItem(name: "state", value: nativeState),
            ]
            guard let authorizeUrl = components.url else {
                Log.error("Failed to build authorize URL")
                self.resetPending()
                self.state = .loggedOut
                return
            }
            Log.info("[AUTH] Opening authorize URL: \(authorizeUrl.absoluteString)")
            let launched = AuthSession.launch(url: authorizeUrl)
            if !launched {
                Log.error("Failed to open authorize URL in default browser")
                self.resetPending()
                self.state = .loggedOut
            }
            // Wait for onOpenURL → handleOAuthCallback.
        }
    }

    func signOut() {
        tokenStore.delete()
        apiClient.clearToken()
        state = .loggedOut
    }

    func restore() async {
        do {
            guard let tokens = tokenStore.load() else { return }
            apiClient.setToken(tokens.accessToken)
            let user = try await apiClient.me()
            self.state = .authenticated(user: user)
        } catch {
            Log.error("Restore failed: \(error)")
            signOut()
        }
    }

    func handleOAuthCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            resetPending()
            state = .loggedOut
            return
        }
        let qs = components.queryItems ?? []
        let code = qs.first(where: { $0.name == "code" })?.value
        let oauthState = qs.first(where: { $0.name == "state" })?.value

        guard let code else {
            Log.error("OAuth callback missing code")
            resetPending()
            state = .loggedOut
            return
        }

        // Accept either in-memory pending state or UserDefaults-mirrored state —
        // the latter handles the case where Launch Services spawned a fresh
        // process to receive the callback URL.
        let storedState = pendingState ?? UserDefaults.standard.string(forKey: Self.defaultsStateKey)
        guard let oauthState, oauthState == storedState else {
            Log.error("OAuth callback state mismatch (expected=\(storedState ?? "nil") got=\(oauthState ?? "nil"))")
            resetPending()
            state = .loggedOut
            return
        }

        let storedVerifier = pendingVerifier ?? UserDefaults.standard.string(forKey: Self.defaultsVerifierKey)
        guard let verifier = storedVerifier else {
            Log.error("OAuth callback with no pending verifier — did signIn() run?")
            resetPending()
            state = .loggedOut
            return
        }

        do {
            let (accessToken, refreshToken, expiresAt) = try await exchangeCode(code: code, verifier: verifier)
            tokenStore.save(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
            apiClient.setToken(accessToken)
            let user = try await apiClient.me()
            self.state = .authenticated(user: user)
        } catch {
            Log.error("OAuth callback exchange failed: \(error)")
            self.state = .loggedOut
        }
        resetPending()
    }

    func cancelPendingSignIn() {
        guard case .authenticating = state else { return }
        resetPending()
        state = .loggedOut
    }

    private func resetPending() {
        pendingVerifier = nil
        pendingState = nil
        UserDefaults.standard.removeObject(forKey: Self.defaultsVerifierKey)
        UserDefaults.standard.removeObject(forKey: Self.defaultsStateKey)
    }

    private func exchangeCode(code: String, verifier: String) async throws -> (accessToken: String, refreshToken: String, expiresAt: Date) {
        let request = TokenExchangeRequest(
            grant_type: "authorization_code",
            code: code,
            code_verifier: verifier,
        )

        let (data, response) = try await URLSession.shared.data(for: URLRequest(
            method: "POST",
            url: URL(string: "https://prodrive.racecor.io/api/plugin-auth/token")!,
            body: request,
        ))

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Uses JSONDecoder.racecor (defined in APIClient.swift) to handle
        // fractional-second ISO8601 dates — Swift's built-in `.iso8601`
        // strategy rejects them, which is what produced the
        // `Expected date string to be ISO8601-formatted` failure here.
        let tokenResponse = try JSONDecoder.racecor.decode(TokenResponse.self, from: data)

        return (
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token,
            expiresAt: tokenResponse.expires_at,
        )
    }
}

private struct TokenExchangeRequest: Codable {
    let grant_type: String
    let code: String
    let code_verifier: String
}

private struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let token_type: String
    let expires_at: Date
}

extension URLRequest {
    init<T: Encodable>(method: String, url: URL, body: T) throws {
        self.init(url: url)
        self.httpMethod = method
        self.httpBody = try JSONEncoder().encode(body)
        self.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
}
