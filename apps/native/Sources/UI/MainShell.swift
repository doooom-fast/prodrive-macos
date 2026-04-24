import SwiftUI

/// Signed-in root. Kept deliberately minimal — no toolbar chrome. The
/// theme picker + account menu now live at the bottom of the sidebar
/// (ContentView), not the window title bar, per product direction.
struct MainShell: View {
    @EnvironmentObject var authManager: AuthManager
    let user: Me

    var body: some View {
        ContentView(user: user)
            .task {
                await ThemeStore.shared.refresh()
            }
    }
}
