import Foundation

/// Owns the lifetime of the LAN-receive subsystem. Started when the user
/// signs in, stopped when they sign out (or the app quits).
///
/// Why a singleton: app-lifetime, side-effecting, owns sockets. SwiftUI
/// view-driven storage doesn't model that correctly — the receiver
/// would tear down when MainShell briefly unmounts during sign-out.
@MainActor
final class SharingCoordinator {

    static let shared = SharingCoordinator()

    private var receiver: ReceiverServer?
    private(set) var isRunning = false

    private init() {}

    /// Spin up the Bonjour-advertised receiver. Idempotent — calling start
    /// twice is a no-op. The shared key is derived lazily on each request
    /// from `APIClient.shared.currentAccessToken` so a token rotation
    /// (refresh) doesn't require restarting the listener.
    func start(userId: String?) {
        guard !isRunning else { return }

        let saveDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/RaceCor/sessions", isDirectory: true)

        let serviceName = makeServiceName()
        let txt: [String: String] = [
            "version":      "1",
            "userId":       userId ?? "anonymous",
            "capabilities": "receive",
        ]

        let receiver = ReceiverServer(
            saveDirectory: saveDir,
            sharedKeyProvider: { sharedKeyFromCurrentToken() }
        )
        do {
            try receiver.start(serviceName: serviceName, txtRecords: txt)
            self.receiver = receiver
            self.isRunning = true
            Log.info("[Sharing] receiver started — '\(serviceName)' on _prodrive._tcp")
        } catch {
            Log.error("[Sharing] receiver start failed: \(error)")
        }
    }

    func stop() {
        receiver?.stop()
        receiver = nil
        isRunning = false
        Log.info("[Sharing] receiver stopped")
    }

    private func makeServiceName() -> String {
        let host = Host.current().localizedName ?? "Mac"
        return "Prodrive Editor on \(host)"
    }
}

private func sharedKeyFromCurrentToken() -> Data? {
    guard let token = APIClient.shared.currentAccessToken else { return nil }
    return SharedKey.derive(bearerToken: token)
}
