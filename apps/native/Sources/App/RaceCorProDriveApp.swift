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
                    ZStack {
                        ThemedBackgroundView()
                        Palette.bgBase.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 12) {
                            Logomark(height: 56, tone: .color)
                            ProgressView()
                                .controlSize(.small)
                            Text("Opening browser…")
                                .font(.system(size: 12))
                                .foregroundColor(Palette.textDim)
                        }
                    }
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
            // Fetch themes at app launch (not just after sign-in) so the
            // login + authenticating screens already have a real
            // background image instead of the fallback gradient.
            .task {
                await ThemeStore.shared.refresh()
            }
            // Force dark appearance across the whole app. The dashboard
            // design is dark-first (matches the web product) and mixing
            // light system chrome with dark content looks broken.
            .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1200, height: 800)
        // `.hiddenTitleBar` drops the window's title text, and
        // `.unifiedCompact` toolbar style keeps the title-bar area slim
        // and merges toolbar items inline with the traffic lights.
        // Together they give us a compact native header where dashboard
        // tabs can sit at the same vertical level as the traffic-light
        // cluster (and flow around the sidebar-collapse button when the
        // sidebar is hidden).
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
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
