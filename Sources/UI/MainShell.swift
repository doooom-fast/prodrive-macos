import SwiftUI

/// Signed-in root. Drives the two app-lifetime side effects that only
/// matter while logged in:
///   - `ThemeStore` refresh (fetches theme sets on entry).
///   - `DashboardPoller` start/stop — polls /api/v1/dashboard every
///     60s, publishes to views that observe it, and fires desktop
///     notifications when new moments/race results appear.
struct MainShell: View {
    @EnvironmentObject var authManager: AuthManager
    let user: Me

    var body: some View {
        ContentView(user: user)
            .task {
                await ThemeStore.shared.refresh()
                DashboardPoller.shared.start()
                // Advertise this Mac as a Bonjour-discoverable receiver
                // so the Windows app can ship `.rcpdv` bundles over the LAN.
                SharingCoordinator.shared.start(userId: "discord:\(user.discordId)")
            }
            .onDisappear {
                // onDisappear fires when the user signs out and the
                // MainShell is torn down. Stop the poller so we don't
                // keep hitting the server for a logged-out session
                // (which would 401 anyway, but still wasteful).
                DashboardPoller.shared.stop()
                SharingCoordinator.shared.stop()
            }
    }
}
