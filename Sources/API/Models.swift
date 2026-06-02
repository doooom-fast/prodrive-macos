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
        /// Individual car models grouped under this affinity entry.
        /// Category brands like "F4" / "GT3" surface the *specific*
        /// chassis here (e.g. "Tatuus F4 T-014"), which is what
        /// resolves against the `lookups.cars` table — matching
        /// against the bare `manufacturer` would miss for every
        /// category-level brand.
        struct CarEntry: Codable {
            let carModel: String
            let gameName: String
            let sessionCount: Int
        }

        let manufacturer: String
        let brandKey: String
        let cars: [CarEntry]?
        let totalSessions: Int
        let totalLaps: Int
        let avgPosition: Double?
        let bestPosition: Int?
        let avgIncidents: Double
        let affinityScore: Double
        let trend: String

        var id: String { brandKey }
    }

    struct TemporalSlice: Codable {
        let label: String
        let sessionCount: Int
        let avgPosition: Double?
        let avgIRatingDelta: Double?
        let avgIncidents: Double
        let winRate: Double
        let podiumRate: Double
        let topTenRate: Double
    }

    struct WhenInsight: Codable, Identifiable {
        let type: String  // "positive" | "negative" | "neutral"
        let text: String
        var id: String { "\(type):\(text)" }
    }

    struct HeatmapCell: Codable, Identifiable {
        let day: Int    // 0..6 (Mon..Sun)
        let hour: Int   // 0..23
        let score: Double
        let count: Int
        var id: String { "\(day)-\(hour)" }
    }

    struct WhenProfile: Codable {
        let byHour: [TemporalSlice]          // 24 slots
        let byDayOfWeek: [TemporalSlice]     // 7 slots, Mon..Sun
        let bySessionLength: [TemporalSlice]
        let peakHours: String
        let peakDays: String
        let worstHours: String
        let worstDays: String
        let peakHourStart: Int
        let worstHourStart: Int
        let windowSize: Int
        let insights: [WhenInsight]
        let heatmapData: [HeatmapCell]
        /// Per-hour rank + tier for relative-to-self verdicts. Required
        /// — server's `evaluateRaceNow` looks up `rankedSlots[hour].tier`
        /// to decide the verdict. Without this on the wire, the server
        /// falls back to `insufficient` and native shows "Not enough data
        /// yet" while web shows the correct tier name. Server interface:
        /// `apps/web-api/src/calc/when-engine.ts` → `RankedSlot`.
        let rankedSlots: [RankedSlot]
    }

    /// Single hour-of-day slot tier-ranked within the user's own
    /// distribution. Mirrors server's `RankedSlot`. `tier` values are
    /// the six-way `SlotTier` strings.
    struct RankedSlot: Codable {
        let hour: Int                  // 0–23
        let rank: Int?                 // 0-based; null if below sample floor
        let percentile: Double?        // 100 = cleanest, 0 = messiest
        let tier: String               // "best" | "good" | "clean-side" | "messy-side" | "risky" | "insufficient"
        let sessionCount: Int
        let avgIncidents: Double
        let avgPosition: Double?
    }

    struct NextRaceIdeaEntry: Codable, Identifiable {
        let seriesName: String
        let trackName: String
        let trackConfig: String?
        let category: String
        let license: String
        let official: Bool
        let fixed: Bool
        let score: Double
        let strategy: String
        let commentary: String
        let startsAtUtc: String
        let carClassNames: [String]
        let seasonId: Int
        let seriesId: Int
        let raceLapLimit: Int?
        let raceTimeLimit: Int?
        /// Server-baked presentation strings + colors. Optional here
        /// so old server responses (pre-prodrive-server PR #31) decode
        /// without error; renderer falls back to local formatters
        /// when nil. Once server is deployed, every response
        /// populates this and clients render verbatim with no drift.
        let viewModel: NextRaceIdeaViewModel?

        var id: String { "\(seriesId)-\(seasonId)-\(startsAtUtc)" }
    }

    /// Mirrors `RaceSuggestion.viewModel` on the server side
    /// (`apps/web-api/src/calc/next-race-ideas.ts`). Native renders
    /// these strings verbatim — no client-side score-color
    /// thresholding, no client-side countdown formatting, no
    /// per-platform "Pit lane" vs "Pitlane" drift.
    struct NextRaceIdeaViewModel: Codable {
        let scoreColorHex: String
        let scoreTierLabel: String
        let startsInLabel: String
        /// Compact countdown for the time chip ("15m" / "2h 30m" /
        /// "Starting now" / weekday-short / "Apr 28"). The native time
        /// chip renders this verbatim — no client-side date math.
        ///
        /// Optional on the wire so legacy server responses (pre-PR
        /// shipping `startsInShortLabel`) still decode. Renderer
        /// falls back to `startsInLabel` when missing.
        let startsInShortLabel: String?
        let durationLabel: String?
        let strategyLabel: String
        let strategyColorHex: String
        /// Pre-resolved track display label. Server post-processing in
        /// `getDashboardData()` builds this via the lookups bundle.
        /// Optional — legacy responses don't carry it; renderer falls
        /// back to the `Lookups.track(for:)` displayName plus a manual
        /// trackConfig concat.
        let trackLabel: String?
        /// Single canonical key for the lookups bundle. Optional for
        /// the same backwards-compat reason as `trackLabel`. Renderer
        /// falls back to a case-folded raw track name when nil.
        let trackLookupKey: String?
    }

    /// Server-pre-computed view-model for the Strengths / Watch Out
    /// panel. Native renders this verbatim — the computation lives in
    /// `apps/web/src/lib/when-panel-view.ts` on the server, same lib
    /// the web component uses. No Swift re-implementation.
    struct WhenPanelSide: Codable {
        let days: String
        let hours: String
        let avgIRatingDelta: Double?
        let paragraph: String
        let bullets: [WhenInsight]
    }

    struct WhenPanelView: Codable {
        let strengths: WhenPanelSide?
        let watchOut: WhenPanelSide?
    }

    /// 8-axis Driver DNA computed server-side by `computeDriverDNA`.
    struct DriverDNAData: Codable {
        let consistency: Double
        let racecraft: Double
        let cleanness: Double
        let endurance: Double
        let adaptability: Double
        let improvement: Double
        let wetWeather: Double
        let experience: Double
    }

    /// Archetype label (primary + variant) from `getDriverArchetype`.
    /// Matches the web exactly — "The Chameleon" / "The Renaissance Driver".
    struct DriverArchetypeData: Codable {
        let major: String
        let variant: String
        let majorDescription: String?
        let variantDescription: String?
    }

    /// One entry in the 8-axis DNA insight card grid. Server emits
    /// label / value (0–100) / description / trend already; native
    /// renders these verbatim with no client-side string assembly.
    /// Source: `apps/web-api/src/calc/driver-dna.ts → DNAInsight`.
    struct DNAInsight: Codable, Identifiable {
        /// Internal axis key — `consistency` / `racecraft` /
        /// `cleanness` / `endurance` / `adaptability` /
        /// `improvement` / `wetWeather` / `experience`. Drives the
        /// SF Symbol icon mapping client-side; never displayed.
        let dimension: String
        /// Human-readable axis name ("Consistency", "Wet Weather", …).
        let label: String
        let value: Double
        let description: String
        /// "improving" | "declining" | "stable" — drives the trend
        /// chip color + label.
        let trend: String

        var id: String { dimension }
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
    /// Track silhouette + image lookups bundled with every dashboard
    /// response. Server collects these from topTracks, nextRaceIdeas,
    /// moments, and sessions' referenced tracks. Keyed by case-folded
    /// track name — use `lookups.track(for:)`.
    struct TrackLookup: Codable {
        let key: String
        let displayName: String
        let svgPath: String?
        let logoSvg: String?
        let imageUrl: String?
    }

    /// Car brand logo + photo for each referenced car model.
    struct CarLookup: Codable {
        let key: String
        let brandKey: String?
        let manufacturer: String?
        let logoSvg: String?
        let logoPng: String?
        let color: String?
        let imageUrl: String?
    }

    struct Lookups: Codable {
        let tracks: [TrackLookup]
        let cars: [CarLookup]

        /// Look up a track by the server-baked `viewModel.trackLookupKey`.
        /// Preferred over `track(for:)` — the key has already been
        /// synonym-folded server-side via `resolveIRacingTrackId`, so
        /// this is a single direct-key match with no client-side
        /// resolution.
        func trackByKey(_ key: String?) -> TrackLookup? {
            guard let key, !key.isEmpty else { return nil }
            return tracks.first(where: { $0.key == key })
        }

        /// Legacy accessor — does a naïve case-folded match against
        /// the raw track name. Prefer `trackByKey(viewModel.trackLookupKey)`
        /// on cards that come from a server-baked view model. Kept
        /// for the calendar heatmap and other places that don't yet
        /// have a viewModel.
        func track(for name: String?) -> TrackLookup? {
            guard let name, !name.isEmpty else { return nil }
            let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return tracks.first(where: { $0.key == key })
        }

        func car(for model: String?) -> CarLookup? {
            guard let model, !model.isEmpty else { return nil }
            let key = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return cars.first(where: { $0.key == key })
                ?? cars.first(where: { key.contains($0.brandKey ?? "") })
        }
    }

    let when: WhenProfile?
    let whenPanel: WhenPanelView?
    let nextRaceIdeas: [NextRaceIdeaEntry]?
    /// Pre-bucketed Race Schedule scatter data from the server —
    /// matches `@/lib/scatter-view` in the web repo. Each bucket is
    /// a (day-of-week, hour) aggregation with session count, summed
    /// deltas, and avgIncidents. Native renders these verbatim.
    struct ScatterBucket: Codable, Identifiable {
        let day: Int           // 0 = Sunday … 6 = Saturday (JS convention)
        let hour: Int          // 0 … 23
        let count: Int
        let irDeltaSum: Double
        let srDeltaSum: Double
        let incidentsSum: Double
        let avgIncidents: Double
        var id: String { "\(day)-\(hour)" }
    }

    let driverDNA: DriverDNAData?
    let driverArchetype: DriverArchetypeData?
    /// Per-axis DNA insight cards. Optional on the wire so older
    /// server responses still decode; the DNA detail view falls back
    /// to a "collecting data" empty state when nil/empty.
    let dnaInsights: [DNAInsight]?
    let lookups: Lookups?
    let scatterBuckets: [ScatterBucket]?

    /// Sessions bundled into the dashboard payload so native apps
    /// don't need a second `/api/v1/sessions` fetch. Up to 200 most
    /// recent. Drives the Race Calendar heatmap; Previous Races tab
    /// now consumes `previousRaces` (server-baked card list) instead.
    struct RecentSession: Codable, Identifiable {
        let id: String
        let subsessionId: Int
        let seriesName: String
        let trackName: String
        let startTime: Date
        let duration: Int?
        let finishPosition: Int?
        let lapsCompleted: Int?
        let category: String
        let carModel: String?
        let incidentCount: Int?
    }
    let recentSessions: [RecentSession]?

    // MARK: - Previous Races (server-baked card list)

    /// Single session payload bundled into a Previous Races card —
    /// matches the wire shape produced by
    /// `apps/web-api/src/calc/previous-races.ts`. Field set is the
    /// minimum the renderer needs (track + car + position +
    /// best lap + field size + completed laps); everything else is
    /// pre-formatted into `viewModel`.
    struct PreviousRaceSession: Codable, Identifiable {
        let id: String
        let carModel: String
        let manufacturer: String?
        let trackName: String?
        let trackConfig: String?
        let finishPosition: Int?
        let incidentCount: Int?
        /// Best lap in seconds (decimal). `nil` when unknown.
        let bestLapTime: Double?
        let fieldSize: Int?
        let completedLaps: Int?
        let gameName: String?
        let sessionType: String?
        let category: String
        /// ISO 8601 UTC timestamp — the calc emits a strings, not
        /// `Date`, so we keep the raw form here. `viewModel.dateLabel`
        /// already has the formatted display copy.
        let createdAt: String
    }

    /// Server-baked presentation strings for a Previous Races card.
    /// Native renders these verbatim — the calc resolves position
    /// label + color, "of N" copy, formatted best lap, humanised
    /// session label, etc. so web and native can't drift.
    /// Source: `apps/web-api/src/calc/previous-races.ts`.
    struct PreviousRaceViewModel: Codable {
        /// "races" | "practices" | "time_trials" — drives the
        /// session-type tab grouping in the Previous Races tab.
        let sessionTypeTab: String
        /// "P1".."P40" / "DNF" / "TT" / "—" / nil-when-practice.
        let positionDisplay: String?
        let positionColorHex: String?
        let fieldSizeLabel: String?
        let bestLapLabel: String
        let practiceBestLapLabel: String?
        let qualifyingBestLapLabel: String?
        let qualifyingPositionLabel: String?
        let dateLabel: String
        let sessionLabel: String
        let incidentsLabel: String?
        let practiceIncidentsLabel: String?
        let gameLabel: String
        let trackLabel: String
        /// Single canonical key for the lookups bundle — populated by
        /// `getDashboardData()` post-processing via `resolveIRacingTrackId`.
        /// Optional on the wire for backwards-compat with server
        /// responses that predate the post-processing step. Renderer
        /// falls back to `trackByKey(session.trackName.lowercased())`.
        let trackLookupKey: String?
    }

    /// One Previous Races card. The calc has already paired the
    /// "headline" race with its sibling practice / qualifying inside
    /// an 8-hour window on the same track — we just render them.
    struct PreviousRaceCard: Codable, Identifiable {
        let session: PreviousRaceSession
        let practiceSession: PreviousRaceSession?
        let qualifyingSession: PreviousRaceSession?
        let viewModel: PreviousRaceViewModel

        var id: String { session.id }
    }

    let previousRaces: [PreviousRaceCard]?

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
