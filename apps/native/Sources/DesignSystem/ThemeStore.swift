import Foundation
import SwiftUI

// MARK: - Model

/// A theme set returned by `GET /api/theme-sets`. Mirrors the server's
/// `themeSets` table columns we expose publicly.
struct ThemeSet: Codable, Identifiable, Equatable {
    let slug: String
    let name: String
    let description: String?
    let liveryImage: String?
    let sortOrder: Int

    var id: String { slug }
}

private struct ThemeSetsResponse: Codable {
    let sets: [ThemeSet]
}

// MARK: - Store

/// Fetches theme sets from the server, persists the user's selection
/// across app launches, and publishes the active livery image URL so
/// `ThemedBackgroundView` (and anything else) can react.
///
/// Mirrors the web's flow: a `racecor-theme-set` cookie stores the slug
/// between sessions; DashboardBackground reads it and uses the matching
/// livery image. Here we use UserDefaults instead of cookies but the
/// shape is the same — slug-in, livery-image-out.
/// Sentinel slug meaning "rotate through all themes that have an image".
/// Not a real theme set — intercepted by the store to drive auto-rotation.
private let autoSlug = "__auto__"

@MainActor
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published private(set) var sets: [ThemeSet] = []
    @Published private(set) var isLoading = false

    /// Current user pick. Can be `autoSlug` (rotate), `"default"` (no
    /// theme → `Palette.bgBase` backdrop), or a specific theme slug.
    @Published var selectedSlug: String {
        didSet {
            UserDefaults.standard.set(selectedSlug, forKey: Self.defaultsKey)
            // Flipping modes resets the rotation to the head of the pool
            // so the user sees a visible change, and prevents stale
            // activeSlug from lingering if they just un-pinned a theme.
            if selectedSlug == autoSlug {
                advanceRotation()
                scheduleRotation()
            } else {
                rotationTask?.cancel()
                activeSlug = selectedSlug
            }
        }
    }

    /// The actually-displayed theme slug. Equal to `selectedSlug` when a
    /// specific theme is pinned; advances through all sets in auto mode.
    @Published private(set) var activeSlug: String {
        didSet { refreshImage() }
    }

    /// Resolved background image URL for the active theme. Updated when
    /// `activeSlug` changes — either directly from `themeSets.liveryImage`
    /// if the DB has one, or via `/api/unsplash/background?brand=…` as
    /// the web does. `nil` means "show `Palette.bgBase` alone".
    @Published private(set) var activeImageURL: URL?

    /// Interval between auto-rotation advances. 5 minutes is long enough
    /// to not feel twitchy during use but short enough to feel "alive"
    /// over a working session. Tunable via `Self.rotationInterval`.
    static let rotationInterval: TimeInterval = 5 * 60

    private static let defaultsKey = "racecor.theme.slug"
    private var rotationTask: Task<Void, Never>?
    /// Cache keyed by slug so we don't re-hit Unsplash every time the
    /// user flips between themes.
    private var imageCache: [String: URL] = [:]
    private var pendingImageTask: Task<Void, Never>?

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? autoSlug
        self.selectedSlug = stored
        self.activeSlug = stored == autoSlug ? "default" : stored
    }

    /// Current theme set chosen by the user, or nil if not yet loaded.
    /// In auto mode this follows `activeSlug`, which advances over time.
    var activeSet: ThemeSet? {
        sets.first(where: { $0.slug == activeSlug })
    }

    /// Whether auto-rotation is on.
    var isAutoMode: Bool { selectedSlug == autoSlug }

    /// Sentinel used by the picker UI to drive auto-rotation.
    static var auto: String { autoSlug }

    /// All theme sets are eligible for rotation — even those without a
    /// liveryImage, because we can resolve an image per-slug via the
    /// Unsplash backend. Previously filtered to liveryImage-only sets,
    /// which left rotation empty when the DB column was unpopulated.
    private var rotatable: [ThemeSet] {
        sets
    }

    /// Pull the theme-set list from the server. Safe to call on every app
    /// launch; the server response is cached 5 minutes.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let url = URL(string: "https://prodrive.racecor.io/api/theme-sets")!
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                Log.error("ThemeStore: theme-sets fetch returned non-200")
                return
            }
            let decoded = try JSONDecoder.racecor.decode(ThemeSetsResponse.self, from: data)
            self.sets = decoded.sets

            // Now that we have the list, kick off rotation if we're in
            // auto mode. If we're not, make sure `activeSlug` still
            // resolves to a real set (pinned slug may have been deleted).
            if isAutoMode {
                advanceRotation()
                scheduleRotation()
            } else if !sets.contains(where: { $0.slug == activeSlug }) {
                activeSlug = "default"
            }
            // Resolve the image for whichever slug is now active. The
            // didSet on activeSlug handles this for transitions, but
            // the first successful refresh after app launch may land on
            // the same slug we initialized to — need an explicit kick.
            refreshImage()
        } catch {
            Log.error("ThemeStore: refresh failed: \(error)")
        }
    }

    /// Pick a random theme set with a livery image and make it active.
    /// In auto mode this is called on load + periodically by the timer;
    /// pinning a theme cancels the timer.
    private func advanceRotation() {
        let pool = rotatable
        guard !pool.isEmpty else {
            activeSlug = "default"
            return
        }
        // Prefer a *different* theme than the current one so the user
        // sees a visible change.
        let choices = pool.count > 1 ? pool.filter { $0.slug != activeSlug } : pool
        if let next = choices.randomElement() {
            activeSlug = next.slug
        }
    }

    /// Start (or restart) the background rotation task. Cancelled when
    /// the user pins a theme or the store deinits.
    private func scheduleRotation() {
        rotationTask?.cancel()
        rotationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.rotationInterval * 1_000_000_000))
                await MainActor.run { self?.advanceRotation() }
            }
        }
    }

    /// Resolves the image for the current `activeSlug` and publishes
    /// it to `activeImageURL`. Resolution order:
    ///   1. Cache hit for this slug → use immediately.
    ///   2. The matching ThemeSet has a populated `liveryImage` → use it.
    ///   3. Call `/api/unsplash/background?brand=<slug>&theme=dark` the
    ///      same way the web's `DashboardBackground` does.
    /// Cancels any in-flight previous resolve so rapid rotation doesn't
    /// race.
    private func refreshImage() {
        pendingImageTask?.cancel()

        // Cache hit — instant.
        if let cached = imageCache[activeSlug] {
            activeImageURL = cached
            return
        }

        // DB-backed livery image → fastest real-image path.
        if let livery = activeSet?.liveryImage,
           !livery.isEmpty,
           let url = URL(string: livery) {
            imageCache[activeSlug] = url
            activeImageURL = url
            return
        }

        // Otherwise ask the server to pick an Unsplash match for this
        // theme the same way the web does. Resolving async; until it
        // returns we keep the previous image visible (no flash-to-blank).
        let slug = activeSlug
        pendingImageTask = Task { [weak self] in
            guard let url = await Self.fetchUnsplashBackground(brand: slug) else { return }
            await MainActor.run {
                guard let self else { return }
                self.imageCache[slug] = url
                // Only apply if the active slug hasn't rotated past us.
                if self.activeSlug == slug {
                    self.activeImageURL = url
                }
            }
        }
    }

    /// Calls `GET /api/unsplash/background?brand=<slug>&theme=dark` and
    /// returns the resolved image URL, or nil on any failure. Parses the
    /// same response shape the web's component consumes.
    private static func fetchUnsplashBackground(brand: String) async -> URL? {
        guard var comps = URLComponents(string: "https://prodrive.racecor.io/api/unsplash/background") else {
            return nil
        }
        comps.queryItems = [
            URLQueryItem(name: "brand", value: brand),
            URLQueryItem(name: "theme", value: "dark"),
        ]
        guard let url = comps.url else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            // Server returns { url, photographer, photographerUrl }.
            struct BgResponse: Decodable { let url: String }
            let decoded = try JSONDecoder().decode(BgResponse.self, from: data)
            return URL(string: decoded.url)
        } catch {
            return nil
        }
    }
}

// MARK: - Background

/// Renders the active theme set's livery image as a blurred, low-opacity
/// backdrop. Mirrors the web's `DashboardBackground` component precisely:
/// full-bleed fixed image, ~16px blur, 25% opacity on the dark palette,
/// behind all foreground content.
///
/// Use at the root of a view hierarchy with a ZStack:
///
///     ZStack {
///         ThemedBackgroundView()
///         DashboardContent()
///     }
struct ThemedBackgroundView: View {
    @ObservedObject private var store: ThemeStore

    init(store: ThemeStore = .shared) {
        self.store = store
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Palette.bgBase
                if let url = store.activeImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width + 20,
                                       height: geo.size.height + 20)
                                .offset(x: -10, y: -10)
                                .blur(radius: 6)
                                .opacity(0.7)
                                .transition(.opacity)
                        default:
                            EmptyView()
                        }
                    }
                } else {
                    // No resolved image yet. Neutral dark gradient —
                    // previous version used a red glow here which
                    // bled through the login card and misrepresented
                    // the brand before any theme had loaded.
                    LinearGradient(
                        colors: [
                            Palette.bgBase,
                            Color(hex: "#14142a"),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                // Gentle bottom shade only — helps text legibility at the
                // foot of the view without hiding the image.
                LinearGradient(
                    colors: [Color.clear, Palette.bgBase.opacity(0.3)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: store.activeSlug)
        }
    }
}

// MARK: - Picker

/// Menu-button theme picker. "Auto" cycles the livery image every few
/// minutes (default mode on first launch). Any specific theme pins it.
struct ThemePicker: View {
    @ObservedObject private var store: ThemeStore = .shared

    private var currentLabel: String {
        if store.isAutoMode { return "Auto" }
        return store.activeSet?.name ?? "Theme"
    }

    var body: some View {
        Menu {
            Button {
                store.selectedSlug = ThemeStore.auto
            } label: {
                HStack {
                    Image(systemName: "shuffle")
                    Text("Auto-rotate")
                    if store.isAutoMode {
                        Image(systemName: "checkmark")
                    }
                }
            }
            Divider()
            ForEach(store.sets) { set in
                Button {
                    store.selectedSlug = set.slug
                } label: {
                    HStack {
                        Text(set.name)
                        if !store.isAutoMode && set.slug == store.activeSlug {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            if store.sets.isEmpty {
                Text("Loading themes…").disabled(true)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: store.isAutoMode ? "shuffle" : "paintpalette")
                    .font(.system(size: 11))
                Text(currentLabel)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(Palette.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .task {
            if store.sets.isEmpty {
                await store.refresh()
            }
        }
    }
}
