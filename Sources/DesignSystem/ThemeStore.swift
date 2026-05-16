import Foundation
import SwiftUI

// MARK: - Model

/// A theme set returned by `GET /api/theme-sets`. Mirrors the server's
/// `themeSets` table columns we expose publicly.
struct ThemeSet: Codable, Identifiable, Equatable {
    let slug: String
    let name: String
    let description: String?
    let sortOrder: Int

    var id: String { slug }
}

private struct ThemeSetsResponse: Codable {
    let sets: [ThemeSet]
}

// MARK: - Store

/// Fetches theme sets from the server and persists the user's selection
/// across app launches. Background-image rendering was removed; the
/// store now only tracks which theme slug is active so the picker UI
/// can reflect the user's preference.
private let autoSlug = "__auto__"

@MainActor
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published private(set) var sets: [ThemeSet] = []
    @Published private(set) var isLoading = false

    /// Current user pick. Can be `autoSlug` (rotate through the theme
    /// list), `"default"`, or a specific theme slug.
    @Published var selectedSlug: String {
        didSet {
            UserDefaults.standard.set(selectedSlug, forKey: Self.defaultsKey)
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
    @Published private(set) var activeSlug: String

    /// Interval between auto-rotation advances.
    static let rotationInterval: TimeInterval = 5 * 60

    private static let defaultsKey = "racecor.theme.slug"
    private var rotationTask: Task<Void, Never>?

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? autoSlug
        self.selectedSlug = stored
        self.activeSlug = stored == autoSlug ? "default" : stored
    }

    /// Current theme set chosen by the user, or nil if not yet loaded.
    var activeSet: ThemeSet? {
        sets.first(where: { $0.slug == activeSlug })
    }

    /// Whether auto-rotation is on.
    var isAutoMode: Bool { selectedSlug == autoSlug }

    /// Sentinel used by the picker UI to drive auto-rotation.
    static var auto: String { autoSlug }

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

            if isAutoMode {
                advanceRotation()
                scheduleRotation()
            } else if !sets.contains(where: { $0.slug == activeSlug }) {
                activeSlug = "default"
            }
        } catch {
            Log.error("ThemeStore: refresh failed: \(error)")
        }
    }

    /// Pick a random theme set and make it active. In auto mode this is
    /// called on load + periodically by the timer; pinning a theme
    /// cancels the timer.
    private func advanceRotation() {
        guard !sets.isEmpty else {
            activeSlug = "default"
            return
        }
        let choices = sets.count > 1 ? sets.filter { $0.slug != activeSlug } : sets
        if let next = choices.randomElement() {
            activeSlug = next.slug
        }
    }

    /// Start (or restart) the background rotation task.
    private func scheduleRotation() {
        rotationTask?.cancel()
        rotationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.rotationInterval * 1_000_000_000))
                await MainActor.run { self?.advanceRotation() }
            }
        }
    }
}

// MARK: - Picker

/// Menu-button theme picker. "Auto" cycles theme sets every few minutes
/// (default mode on first launch). Any specific theme pins it.
struct ThemePicker: View {
    @ObservedObject private var store: ThemeStore

    @MainActor
    init() {
        self.store = .shared
    }

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
