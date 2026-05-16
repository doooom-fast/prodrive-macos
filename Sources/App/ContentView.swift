import SwiftUI

/// Top-level destinations. Matches the web `/drive` app's horizontal
/// icon nav exactly: Dashboard, DNA, When, Tracks, Cars, Moments.
///
/// Previous iteration also surfaced Races, Safety, Composure, Debrief,
/// Settings — but those aren't top-level routes on the web. Races
/// lives as the "Previous Races" tab on the Dashboard; Safety /
/// Composure / Debrief are dashboard sub-panels; Settings is reached
/// via ⌘, (standard macOS) rather than a sidebar item.
/// Top-level destinations. Moments is intentionally NOT in this list
/// even though the web has a `/drive/moments` route — moments are
/// surfaced as a slide-in drawer from a dedicated bottom-left button
/// rather than as a switchable detail view, mirroring the web's
/// `MomentsDrawer` UX rather than the full-page route.
enum Destination: String, CaseIterable {
    case dashboard = "Dashboard"
    case dna = "DNA"
    case tracks = "Tracks"
    case cars = "Cars"
    case library = "Library"

    /// Matches the web's lucide-react icon choice so the two platforms
    /// feel like one product. Rendered via `LucideIconView` — NOT SF
    /// Symbols — because SF's closest equivalents drift too far from
    /// what the web presents (e.g. the built-in `calendar` glyph looks
    /// nothing like lucide's `calendar-clock`).
    ///
    /// Some destinations (e.g. Library) are native-only and don't have a
    /// web counterpart — those use SF Symbols via `iconSource`. Lucide
    /// translation pending if/when the web grows the same surface.
    var iconSource: RailIconSource {
        switch self {
        case .dashboard: return .lucide(.dashboard)
        case .dna:       return .lucide(.dna)
        case .tracks:    return .lucide(.tracks)
        case .cars:      return .lucide(.cars)
        case .library:   return .systemImage("film.stack")
        }
    }
}

/// Signed-in chrome. A vertical icon-only rail on the left (iOS-style:
/// one glyph per destination, no inline labels) with the theme picker
/// and account avatar pinned to the bottom of the same rail. Hover
/// tooltips surface the full destination name; the selected item gets
/// a subtle filled pill so the active page is obvious at a glance.
///
/// Deliberately NOT using `NavigationSplitView` / `List(selection:)`:
/// the sidebar on macOS applies an NSVisualEffectView backdrop SwiftUI
/// can't override, which fights the themed background behind the rail.
/// A hand-rolled rail also lets us make each row a perfectly square
/// icon target without fighting the sidebar list's padding heuristics.
struct ContentView: View {
    @State private var selectedDestination: Destination = .dashboard
    /// Whether the Moments slide-in drawer is currently visible.
    /// The Moments rail item toggles this instead of switching the
    /// detail view — moments are a peek, not a full page.
    @State private var showMomentsDrawer = false
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var themeStore: ThemeStore
    /// Shared dashboard poller — ContentView reads `recentMoments` +
    /// `lookups` for the Moments drawer overlay; the Dashboard view
    /// reads the same publisher independently.
    @ObservedObject private var poller: DashboardPoller
    let user: Me

    /// Rail width — narrow enough to read as a decoration, wide enough
    /// for a 36pt icon target with breathing room on both sides.
    private static let railWidth: CGFloat = 56

    @MainActor
    init(user: Me) {
        self.user = user
        self.themeStore = .shared
        self.poller = .shared
    }

    var body: some View {
        ZStack {
            Palette.bgBase.ignoresSafeArea()

            HStack(spacing: 0) {
                // Left column holds two stacked elements: the
                // destinations rail at the TOP (under the traffic
                // lights), and a single Moments-trigger button
                // pinned at the BOTTOM. A Spacer between them lets
                // both anchor to their own edge cleanly.
                VStack(spacing: 0) {
                    rail
                    Spacer(minLength: 0)
                    momentsTrigger
                }
                .frame(width: Self.railWidth)
                .frame(maxHeight: .infinity)

                detailView(for: selectedDestination)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Moments slide-in drawer overlays everything. Always in
            // the view tree so the slide animation has a stable
            // transition target; only renders its panel + backdrop
            // when `showMomentsDrawer == true`.
            MomentsDrawer(
                isOpen: $showMomentsDrawer,
                moments: poller.latest?.recentMoments ?? [],
                lookups: poller.latest?.lookups
            )
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    // MARK: - Rail

    /// Short, floating glass rail. Hugs its content vertically, sits
    /// centered in the window, and uses `liquidGlassBackground` —
    /// real Liquid Glass on macOS 26 Tahoe, `.ultraThinMaterial`
    /// fallback on older OSes — so the themed background photo shows
    /// through. Theme + profile sit directly below the destinations —
    /// no spacer, no full-height column, just a compact pill of icons.
    @ViewBuilder
    private var rail: some View {
        VStack(spacing: 6) {
            ForEach(Destination.allCases, id: \.self) { dest in
                RailIconButton(
                    icon: dest.iconSource,
                    tooltip: dest.rawValue,
                    isActive: selectedDestination == dest,
                    action: {
                        selectedDestination = dest
                        // Close the moments drawer when navigating
                        // away — leaving it hovering over an unrelated
                        // detail page is jarring.
                        if showMomentsDrawer {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showMomentsDrawer = false
                            }
                        }
                    }
                )
            }

            themeRailItem
            profileRailItem
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .liquidGlassBackground(cornerRadius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
        // Clear the traffic-light cluster. The window title bar is
        // ~28pt tall; 38pt of top padding gives the rail a breath of
        // space below the close/minimize/zoom row.
        .padding(.top, 38)
        .padding(.leading, 12)
    }

    // MARK: - Moments trigger (bottom-left)

    /// Stand-alone Moments button pinned to the bottom-left corner
    /// of the window. Lives outside the destinations rail because
    /// Moments doesn't switch the detail view — it pops the slide-in
    /// drawer. Putting the button on its own makes that interaction
    /// model legible at a glance: rail items navigate, this one
    /// peeks. Same 36×36 cell footprint and active-pill styling as
    /// the destination buttons so the two read as one design system.
    @ViewBuilder
    private var momentsTrigger: some View {
        VStack(spacing: 0) {
            RailIconButton(
                icon: .lucide(.moments),
                tooltip: "Moments",
                isActive: showMomentsDrawer,
                action: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showMomentsDrawer.toggle()
                    }
                }
            )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .liquidGlassBackground(cornerRadius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
        .padding(.bottom, 12)
        .padding(.leading, 12)
    }

    // MARK: - Theme

    @State private var showThemePopover = false

    /// Theme row — a plain `RailIconButton` (same primitive as the
    /// destinations) that toggles a popover. Earlier iterations used
    /// `Menu`; even with `.menuStyle(.borderlessButton)`, fixedSize,
    /// and external frame clamps, the menu's button body added a few
    /// pixels of internal padding that broke alignment with the
    /// destination buttons. Popover gives us total control.
    private var themeRailItem: some View {
        RailIconButton(
            icon: .systemImage(themeStore.isAutoMode ? "shuffle" : "paintpalette.fill"),
            tooltip: themeStore.isAutoMode ? "Theme: Auto-rotate"
                                           : "Theme: \(themeStore.activeSet?.name ?? "Default")",
            isActive: false,
            action: { showThemePopover.toggle() }
        )
        .popover(isPresented: $showThemePopover, arrowEdge: .leading) {
            VStack(alignment: .leading, spacing: 2) {
                popoverButton(
                    "Auto-rotate",
                    icon: "shuffle",
                    checked: themeStore.isAutoMode
                ) {
                    themeStore.selectedSlug = ThemeStore.auto
                    showThemePopover = false
                }
                Divider().padding(.vertical, 4)
                ForEach(themeStore.sets) { set in
                    popoverButton(
                        set.name,
                        icon: nil,
                        checked: !themeStore.isAutoMode && set.slug == themeStore.activeSlug
                    ) {
                        themeStore.selectedSlug = set.slug
                        showThemePopover = false
                    }
                }
            }
            .padding(8)
            .frame(minWidth: 180)
        }
    }

    // MARK: - Profile

    @State private var showProfilePopover = false

    /// Profile row — same Button-based pattern as theme so the rail's
    /// vertical rhythm stays uniform top to bottom. `Menu` was the
    /// natural fit semantically but its rendered cell never quite
    /// matched a Button's, even with frame clamps.
    private var profileRailItem: some View {
        RailIconButton(
            icon: .systemImage("person.fill"),
            tooltip: user.displayName,
            isActive: false,
            action: { showProfilePopover.toggle() }
        )
        .popover(isPresented: $showProfilePopover, arrowEdge: .leading) {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                if let email = user.email {
                    Text(email)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.textDim)
                }
                Divider().padding(.vertical, 4)
                popoverButton("Sign Out", icon: "arrow.right.square", checked: false) {
                    showProfilePopover = false
                    authManager.signOut()
                }
            }
            .padding(10)
            .frame(minWidth: 200)
        }
    }

    /// Standardized popover row — keeps the theme and profile menus
    /// visually consistent: leading icon (optional), title, trailing
    /// checkmark for selected state.
    private func popoverButton(
        _ title: String,
        icon: String?,
        checked: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.textSecondary)
                        .frame(width: 14)
                }
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.textPrimary)
                Spacer(minLength: 8)
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Palette.brand)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    @ViewBuilder
    func detailView(for destination: Destination) -> some View {
        switch destination {
        case .dashboard:
            DashboardView()
        case .dna:
            DriverDNAView()
        case .tracks:
            TracksView()
        case .cars:
            CarsView()
        case .library:
            LibraryView()
        }
    }
}

/// Source of the glyph rendered inside a rail cell. Lucide icons drive
/// the six top-level destinations so they match the web exactly; SF
/// Symbols still back the theme + profile slots where web doesn't
/// ship a counterpart.
enum RailIconSource {
    case lucide(LucideIcon)
    case systemImage(String)
}

/// Shared 36×36 glyph cell used by both tap-to-select destinations
/// (`RailIconButton`) and tap-to-open-menu slots (theme, profile).
/// Keeping both flavors on the same label is what makes the whole
/// rail read as one consistent strip of icons.
struct RailIconLabel: View {
    let icon: RailIconSource
    let isActive: Bool
    let isHovered: Bool

    var body: some View {
        glyph
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        isActive ? Palette.borderAccent : Color.clear,
                        lineWidth: 1)
            )
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var glyph: some View {
        switch icon {
        case .lucide(let lucide):
            // Render at ~22pt inside the 36×36 cell — matches the web
            // nav's 24px icon at the density the rail wants.
            LucideIconView(icon: lucide, size: 22, color: iconColor)
        case .systemImage(let name):
            Image(systemName: name)
                .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                .foregroundColor(iconColor)
        }
    }

    private var iconColor: Color {
        if isActive || isHovered { return Palette.textPrimary }
        return Palette.textSecondary
    }

    private var backgroundFill: Color {
        if isActive { return Palette.brand.opacity(0.18) }
        if isHovered { return Palette.bgElevated.opacity(0.5) }
        return Color.clear
    }
}

/// Single icon button on the vertical rail. 36pt square target, subtle
/// filled-pill indicator for the active destination, tooltip via
/// `.help()` so hovering reveals the full name without permanently
/// spending horizontal rail width on a label.
struct RailIconButton: View {
    let icon: RailIconSource
    let tooltip: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            RailIconLabel(icon: icon, isActive: isActive, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tooltip)
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
