import SwiftUI

/// Top-level destinations. Matches the web `/drive` app's horizontal
/// icon nav exactly: Dashboard, DNA, When, Tracks, Cars, Moments.
///
/// Previous iteration also surfaced Races, Safety, Composure, Debrief,
/// Settings — but those aren't top-level routes on the web. Races
/// lives as the "Previous Races" tab on the Dashboard; Safety /
/// Composure / Debrief are dashboard sub-panels; Settings is reached
/// via ⌘, (standard macOS) rather than a sidebar item.
enum Destination: String, CaseIterable {
    case dashboard = "Dashboard"
    case dna = "DNA"
    case when = "When"
    case tracks = "Tracks"
    case cars = "Cars"
    case moments = "Moments"

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .dna: return "atom"
        case .when: return "calendar"
        case .tracks: return "map"
        case .cars: return "car.2"
        case .moments: return "sparkles"
        }
    }
}

/// Signed-in chrome. NavigationSplitView with the primary nav on the
/// left; theme picker + account menu pinned to the sidebar's bottom
/// rather than the window toolbar (per product direction — the title
/// bar is intentionally empty so the dashboard's content is the first
/// thing the eye lands on).
struct ContentView: View {
    @State private var selectedDestination: Destination? = .dashboard
    /// Binding the collapse state to real state (not `.constant(.all)`)
    /// is what makes the built-in sidebar toggle button actually work.
    /// Using `.constant` pins the visibility so the toggle is a no-op.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @EnvironmentObject var authManager: AuthManager
    // Observe the theme store so the sidebar theme row updates its
    // label when the active theme changes (auto-rotate ticks, or user
    // picks a different theme from the menu).
    @ObservedObject private var themeStore = ThemeStore.shared
    let user: Me

    var body: some View {
        ZStack {
            // ThemedBackgroundView fills the whole window. An earlier
            // version used NavigationSplitView, whose sidebar column
            // has a system-provided NSVisualEffectView backdrop that
            // SwiftUI can't override — that's why the photo kept
            // "sticking to the right" side of the window. A custom
            // HStack lets the image extend edge-to-edge.
            ThemedBackgroundView()

            HStack(spacing: 0) {
                if columnVisibility != .detailOnly {
                    sidebar
                        .frame(width: 220)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                detailView(for: selectedDestination ?? .dashboard)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.2), value: columnVisibility)
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    /// Toggle the sidebar visibility — called from a toolbar button.
    private func toggleSidebar() {
        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        // Floating-panel sidebar. Inset on all four sides so the panel
        // reads as its own surface hovering over the themed background
        // rather than an edge-to-edge column. Rounded corners + subtle
        // border match the dashboard's `.panel()` treatment — one
        // visual language across sidebar and content panels. The outer
        // `.padding(.top, 38)` clears the traffic-light cluster; inner
        // top padding is small since the panel itself starts below them.
        VStack(spacing: 0) {
            List(Destination.allCases, id: \.self, selection: $selectedDestination) { dest in
                NavigationLink(value: dest) {
                    Label(dest.rawValue, systemImage: dest.icon)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider().overlay(Palette.borderSubtle)

            sidebarFooter
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.bgBase.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 8)
        .padding(.top, 38)    // clear the traffic-light cluster
        .padding(.leading, 10)
        .padding(.bottom, 10)
    }

    /// Bottom-of-sidebar controls: theme picker + account menu. Both
    /// use the same `SidebarMenuRow` component so they render
    /// identically — eliminating the earlier inconsistency where the
    /// two rows had subtly different chrome because each Menu was
    /// hand-built.
    private var sidebarFooter: some View {
        VStack(spacing: 2) {
            SidebarMenuRow(
                title: themeStore.isAutoMode ? "Auto"
                    : (themeStore.activeSet?.name ?? "Theme"),
                systemImage: themeStore.isAutoMode ? "shuffle" : "paintpalette"
            ) {
                Button {
                    themeStore.selectedSlug = ThemeStore.auto
                } label: {
                    HStack {
                        Image(systemName: "shuffle")
                        Text("Auto-rotate")
                        if themeStore.isAutoMode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Divider()
                ForEach(themeStore.sets) { set in
                    Button {
                        themeStore.selectedSlug = set.slug
                    } label: {
                        HStack {
                            Text(set.name)
                            if !themeStore.isAutoMode
                                && set.slug == themeStore.activeSlug {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            SidebarMenuRow(
                title: user.displayName,
                systemImage: "person.circle"
            ) {
                Text(user.displayName).foregroundStyle(.secondary)
                if let email = user.email {
                    Text(email).foregroundStyle(.secondary)
                }
                Divider()
                Button("Sign Out") { authManager.signOut() }
            }
        }
        .padding(8)
    }

    // MARK: - Detail

    @ViewBuilder
    func detailView(for destination: Destination) -> some View {
        switch destination {
        case .dashboard:
            DashboardView()
        case .dna:
            PlaceholderView(title: "Driver DNA", subtitle: "8-axis performance radar coming soon")
        case .when:
            PlaceholderView(title: "When Engine", subtitle: "Time-of-day performance analysis coming soon")
        case .tracks:
            PlaceholderView(title: "Tracks", subtitle: "Track mastery library coming soon")
        case .cars:
            PlaceholderView(title: "Cars", subtitle: "Car affinity breakdown coming soon")
        case .moments:
            PlaceholderView(title: "Moments", subtitle: "Career highlights & milestones coming soon")
        }
    }
}

/// One-line dropdown menu styled for the sidebar footer. Consistent
/// chrome for the theme picker + account menu + anything else we add
/// down there later. Wraps a `Menu` with a hand-rolled label that
/// matches the sidebar list row metrics (icon → label → trailing
/// chevron hint) without relying on `List`'s selection styling.
struct SidebarMenuRow<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var menu: () -> Content

    var body: some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13))
                    .foregroundColor(Palette.textSecondary)
                    .frame(width: 18, alignment: .center)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Palette.textDim)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

struct PlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            BrandGlow(intensity: 0.08).frame(width: 500, height: 500)

            VStack(spacing: 14) {
                Logomark(height: 32, tone: .white)
                    .opacity(0.3)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Palette.textDim)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                Link(destination: URL(string: "https://prodrive.racecor.io")!) {
                    HStack(spacing: 6) {
                        Text("Open on the web")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Palette.brand)
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
