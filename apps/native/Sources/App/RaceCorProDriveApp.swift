import SwiftUI

@main
struct RaceCorProDriveApp: App {
    // `@StateObject` (not `@State`) because AuthManager is an
    // ObservableObject. With `@State` SwiftUI doesn't subscribe to
    // @Published changes, so state transitions (loggedOut → authenticating
    // → authenticated) don't cause body to re-evaluate and the LoginView
    // stays mounted during sign-in.
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        // `Window` (macOS 13+) rather than `WindowGroup`. WindowGroup is a
        // multi-window container — it opens a brand-new window whenever an
        // external event (like an incoming racecor-native:// URL) activates
        // the scene, which is why sign-in was producing a second window. A
        // single `Window` scene suppresses that: there is exactly one
        // window, URL events are delivered to its onOpenURL, and
        // File → New Window is disabled.
        Window("RaceCor Pro Drive", id: "main") {
            Group {
                switch authManager.state {
                case .loggedOut:
                    LoginView()
                        .environmentObject(authManager)
                case .authenticating:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .controlBackgroundColor))
                case .authenticated(let user):
                    MainShell(user: user)
                        .environmentObject(authManager)
                }
            }
            .onOpenURL { url in
                Task {
                    await authManager.handleOAuthCallback(url: url)
                }
            }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    // TODO: open settings window
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit RaceCor Pro Drive") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
