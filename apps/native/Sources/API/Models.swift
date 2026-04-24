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
/// The server's aggregate has richer structure than the native app consumes
/// today — we only decode the fields the macOS UI actually shows, and leave
/// the rest as arbitrary JSON via `_unused` sinks so future additions don't
/// break decoding. `recentSessions` is NOT part of this payload — fetch it
/// separately via `APIClient.sessions()`.
struct Dashboard: Codable {
    struct Stats: Codable {
        let totalRaces: Int
        let totalLaps: Int
        let uniqueTracks: Int
        let uniqueCars: Int
        let careerSpanDays: Int
    }

    let stats: Stats
    let pluginConnected: Bool

    // Flat convenience accessors so existing UI code compiles unchanged.
    var totalRaces: Int { stats.totalRaces }
    var totalTracks: Int { stats.uniqueTracks }
    var totalCars: Int { stats.uniqueCars }
    var careerSpanDays: Int? { stats.careerSpanDays > 0 ? stats.careerSpanDays : nil }
}
