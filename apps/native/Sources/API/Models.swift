import Foundation

/// Matches the payload returned by `GET /api/v1/me` (see
/// `apps/web/src/lib/queries/me.ts` in the server repo):
/// `{ id, discordId, discordUsername, discordDisplayName, discordAvatar,
///    customLogoUrl, email, createdAt }`.
/// Everything except `id` can be nullable because the columns are nullable
/// in the users table and `email` may be absent for OAuth-only accounts.
struct Me: Codable {
    let id: String
    let discordId: String
    let discordUsername: String?
    let discordDisplayName: String?
    let discordAvatar: String?
    let customLogoUrl: String?
    let email: String?
    let createdAt: Date

    /// Convenience: prefer the Discord display name, fall back to the
    /// handle, then to email, then to a placeholder.
    var displayName: String {
        discordDisplayName ?? discordUsername ?? email ?? "Racer"
    }
}

struct SessionListResponse: Codable {
    let sessions: [SessionListItem]
    let total: Int
    let offset: Int
}

struct SessionListItem: Codable, Identifiable {
    let id: String
    let subsessionId: Int
    let seriesName: String
    let trackName: String
    let startTime: Date
    let duration: Int?
    let finishPosition: Int?
    let lapsCompleted: Int?
    let category: String
}

struct SessionDetail: Codable {
    let id: String
    let subsessionId: Int
    let seriesName: String
    let trackName: String
    let carName: String
    let startTime: Date
    let duration: Int?
    let finishPosition: Int?
    let startPosition: Int?
    let lapsCompleted: Int?
    let lapsLed: Int?
    let incidents: Int?
    let iRatingPre: Int?
    let iRatingPost: Int?
    let srPre: Double?
    let srPost: Double?
    let avgLapTime: Int?
    let bestLapTime: Int?
    let laps: [Lap]?
}

struct Lap: Codable, Identifiable {
    let id: String
    let lapNumber: Int
    let time: Int
    let isIncident: Bool
}

/// Matches `GET /api/v1/dashboard` (see `apps/web/src/lib/queries/dashboard.ts`).
///
/// This decodes the fields the macOS UI actively displays. Anything the
/// server adds later that we don't consume gets silently ignored by
/// JSONDecoder's default strategy. `recentSessions` is NOT part of this
/// payload — fetch via `APIClient.sessions()` when needed.
struct Dashboard: Codable {
    struct Stats: Codable {
        let totalRaces: Int
        let totalLaps: Int
        let uniqueTracks: Int
        let uniqueCars: Int
        let careerSpanDays: Int
    }

    struct IRatingData: Codable {
        struct Point: Codable {
            let t: String
            let value: Int
        }
        let current: Int?
        let trend: Int   // -1, 0, or 1
        let sparkline: [Point]
    }

    struct SafetyRatingData: Codable {
        let current: Double?
        let license: String?  // "R" | "D" | "C" | "B" | "A" | null
    }

    struct MomentEntry: Codable, Identifiable {
        let type: String
        let date: String
        let title: String
        let description: String
        let significance: Int
        let carModel: String?
        let trackName: String?
        let gameName: String?

        var id: String { "\(type)-\(date)-\(title)" }
    }

    struct TrackMasteryEntry: Codable, Identifiable {
        let trackName: String
        let familyKey: String
        let totalSessions: Int
        let totalLaps: Int
        let avgPosition: Double?
        let bestPosition: Int?
        let avgIncidents: Double
        let masteryScore: Double
        let masteryTier: String  // bronze | silver | gold | diamond
        let trend: String        // improving | declining | stable | new
        let lastRaced: String

        var id: String { familyKey }
    }

    struct CarAffinityEntry: Codable, Identifiable {
        let manufacturer: String
        let brandKey: String
        let totalSessions: Int
        let totalLaps: Int
        let avgPosition: Double?
        let bestPosition: Int?
        let avgIncidents: Double
        let affinityScore: Double
        let trend: String

        var id: String { brandKey }
    }

    let stats: Stats
    let pluginConnected: Bool
    // Server returns these as Record<category, …> — keep them as a
    // dictionary keyed by RatingCategory ("road", "oval", "dirt_road",
    // "dirt_oval", "formula").
    let iRating: [String: IRatingData]?
    let safetyRating: [String: SafetyRatingData]?
    let moments: [MomentEntry]?
    let recentMoments: [MomentEntry]?
    let topTracks: [TrackMasteryEntry]?
    let topCars: [CarAffinityEntry]?

    // Flat convenience accessors so existing UI code compiles unchanged.
    var totalRaces: Int { stats.totalRaces }
    var totalTracks: Int { stats.uniqueTracks }
    var totalCars: Int { stats.uniqueCars }
    var careerSpanDays: Int? { stats.careerSpanDays > 0 ? stats.careerSpanDays : nil }

    /// Rating categories that have a non-null `current` value, sorted in
    /// their canonical display order. The internal DB key stays `road`
    /// for backwards compat with existing rows, but the user-facing label
    /// is "Sports Car" — iRacing rebranded that category and the web
    /// already matches (see `CATEGORY_LABELS` in the server's constants).
    var activeCategories: [(key: String, label: String, rating: IRatingData)] {
        let order = ["road", "oval", "formula", "dirt_road", "dirt_oval"]
        let labels: [String: String] = RaceCategoryLabels.display
        guard let iRating else { return [] }
        return order.compactMap { key in
            guard let r = iRating[key], r.current != nil, r.current! > 0 else { return nil }
            return (key: key, label: labels[key] ?? key, rating: r)
        }
    }
}

/// Shared map of internal category keys → user-facing display names.
/// Canonical source: `apps/web/src/lib/constants.ts` in the server.
enum RaceCategoryLabels {
    static let display: [String: String] = [
        "road": "Sports Car",      // iRacing renamed this category (~2024)
        "oval": "Oval",
        "formula": "Formula",
        "dirt_road": "Dirt Road",
        "dirt_oval": "Dirt Oval",
    ]
}
