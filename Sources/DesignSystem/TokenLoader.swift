import Foundation
import SwiftUI

/// Runtime-resolved design tokens, fetched from /api/v1/tokens/native?format=json.
///
/// Naming note: this type is `DesignTokenStore`, NOT `TokenStore`. The Auth
/// layer already has a `TokenStore` (a Keychain wrapper for OAuth Bearer
/// tokens); two classes with the same name in the same module collide.
///
/// Token JSON shape (from apps/web/src/lib/tokens/sd-native.ts):
/// ```
/// { "colors": { "bg": "#0a0a14", ... }, "typography": { ... },
///   "fontSize": { "xs": 10, ... }, "layout": { "headerHeight": 41, ... } }
/// ```
///
/// UI reads `DesignTokenStore.shared.resolved` or `@Environment(\.designTokens)`.
/// Compile-time `RaceCorTokens` in Tokens.swift remains the fallback.

public struct ResolvedTokens: Codable, Equatable, Sendable {
    public var colors: [String: String]
    public var typography: [String: String]
    public var fontSize: [String: Double]
    public var fontWeight: [String: Double]?
    public var lineHeight: [String: Double]?
    public var layout: [String: Double]

    /// Parse a token color string ( `#RRGGBB[AA]` or `rgba(r,g,b,a)` ) using the
    /// Color(hex:) / Color(rgba:) initializers provided in Tokens.swift.
    public func color(_ key: String, fallback: Color) -> Color {
        guard let raw = colors[key] else { return fallback }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") { return Color(hex: trimmed) }
        if trimmed.hasPrefix("rgb") { return Color(rgba: trimmed) }
        return fallback
    }

    public func size(_ key: String, fallback: CGFloat) -> CGFloat {
        if let v = fontSize[key] { return CGFloat(v) }
        if let v = layout[key] { return CGFloat(v) }
        return fallback
    }

    public func font(_ key: String, fallback: String) -> String {
        typography[key] ?? fallback
    }

    public static let empty = ResolvedTokens(
        colors: [:], typography: [:], fontSize: [:], fontWeight: [:], lineHeight: [:], layout: [:]
    )
}

@MainActor
public final class DesignTokenStore: ObservableObject {
    public static let shared = DesignTokenStore()

    @Published public private(set) var resolved: ResolvedTokens = .empty
    @Published public private(set) var source: TokenSource = .defaults
    @Published public private(set) var lastFetched: Date?

    public enum TokenSource: String, Sendable {
        case defaults
        case disk
        case network
    }

    private let cachePath: URL
    // Tokens endpoint is public (no Bearer needed) so this client doesn't
    // need setTokens() — we keep it local rather than depending on the
    // AuthManager's instance.
    private let apiClient = APIClient()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cachePath = appSupport.appendingPathComponent("racing.k10motorsports.prodrive.racecor.mac/tokens.json")
        loadFromDiskIfAvailable()
    }

    /// Call once on app launch (after auth restore). Fetches fresh tokens
    /// from the server; leaves compile-time defaults / disk cache untouched
    /// on failure so the UI always has something to render.
    public func loadOrFetch() async {
        do {
            let jsonString = try await apiClient.tokensNative(format: "json")
            guard let jsonData = jsonString.data(using: String.Encoding.utf8) else { return }
            let decoded = try JSONDecoder().decode(ResolvedTokens.self, from: jsonData)
            self.resolved = decoded
            self.source = .network
            self.lastFetched = Date()
            try? saveToDisk(data: jsonData)
            Log.info("Design tokens refreshed (colors=\(decoded.colors.count))")
        } catch {
            Log.error("Token fetch failed, using \(source.rawValue): \(error)")
        }
    }

    private func loadFromDiskIfAvailable() {
        guard FileManager.default.fileExists(atPath: cachePath.path) else { return }
        do {
            let data = try Data(contentsOf: cachePath)
            let decoded = try JSONDecoder().decode(ResolvedTokens.self, from: data)
            self.resolved = decoded
            self.source = .disk
            Log.info("Loaded cached design tokens (colors=\(decoded.colors.count))")
        } catch {
            Log.error("Failed to parse cached tokens: \(error)")
        }
    }

    private func saveToDisk(data: Data) throws {
        try FileManager.default.createDirectory(
            at: cachePath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Data.write takes a Data.WritingOptions set, not an `atomically:` Bool.
        try data.write(to: cachePath, options: [.atomic])
    }
}

/// Legacy entry point — old callers used TokenLoader.shared.loadOrFetch().
/// Kept as a thin forwarder so existing call sites compile unchanged.
final class TokenLoader {
    static let shared = TokenLoader()
    @MainActor
    func loadOrFetch() async { await DesignTokenStore.shared.loadOrFetch() }
}

// ── Environment injection ──────────────────────────────────────────────

private struct DesignTokensEnvironmentKey: EnvironmentKey {
    @MainActor
    static var defaultValue: DesignTokenStore { DesignTokenStore.shared }
}

public extension EnvironmentValues {
    var designTokens: DesignTokenStore {
        get { self[DesignTokensEnvironmentKey.self] }
        set { self[DesignTokensEnvironmentKey.self] = newValue }
    }
}
