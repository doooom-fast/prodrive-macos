import Foundation

// MARK: - Wire-shaped request / response DTOs for /api/v1/calc/*
//
// Spec: prodrive-server/docs/native-app-integration.md
//
// Conventions:
// - All `createdAt` / time fields are ISO-8601 strings on the wire; route
//   handlers hydrate to Date internally. Swift uses Date with .iso8601 in
//   the encoder/decoder so callers work with Date values.
// - Heavily nested or evolving response shapes (TrackMastery, WhenProfile,
//   ComposureReport, IRacingSchedule, ScoreBreakdown) are kept as
//   `JSONValue` so additive server changes don't require a client release.
//   Cast at the call site if you need stronger typing.

// MARK: - 1. Driver DNA

struct DnaSession: Codable {
    var finishPosition: Int?
    var incidentCount: Int?
    var metadata: JSONValue?
    var carModel: String
    var trackName: String?
    var gameName: String?
    var createdAt: Date
}

struct DnaRating: Codable {
    var iRating: Double
    var prevIRating: Double?
    var createdAt: Date
}

struct DnaRequest: Encodable {
    var sessions: [DnaSession]
    var ratings: [DnaRating]
}

struct DriverDnaResponse: Codable {
    var dna: DriverDnaScores
    var archetype: DriverDnaArchetype
    var insights: [DriverDnaInsight]
    var sampleSize: Int
    var confidence: Double
}

struct DriverDnaScores: Codable {
    var consistency: Double
    var racecraft: Double
    var cleanness: Double
    var endurance: Double
    var adaptability: Double
    var improvement: Double
    var wetWeather: Double
    var experience: Double
}

struct DriverDnaArchetype: Codable {
    var major: String
    var variant: String
    var majorDescription: String
    var variantDescription: String
}

struct DriverDnaInsight: Codable {
    var dimension: String
    var label: String
    var value: Double
    var description: String
    var trend: String  // "improving" | "declining" | "stable"
}

// MARK: - 2. Mastery

struct MasterySession: Codable {
    var id: String
    var carModel: String
    var manufacturer: String
    var trackName: String
    var finishPosition: Int?
    var incidentCount: Int
    var metadata: JSONValue?
    var createdAt: Date
    var gameName: String
}

struct MasteryRequest: Encodable {
    var sessions: [MasterySession]
}

struct MasteryResponse: Codable {
    /// TrackMastery shape — large + additive; opaque to client. Cast to a
    /// strong type at the call site if you need it. See
    /// `apps/web-api/src/calc/mastery.ts` for the canonical shape.
    var tracks: [JSONValue]
    /// CarAffinity shape — same caveat as `tracks`.
    var cars: [JSONValue]
}

// MARK: - 3. Moments

struct MomentSession: Codable {
    var id: String
    var carModel: String
    var trackName: String
    var finishPosition: Int?
    var incidentCount: Int
    var metadata: JSONValue?
    var createdAt: Date
    var gameName: String
    var sessionType: String
}

struct MomentRating: Codable {
    var iRating: Double
    var prevIRating: Double
    var prevLicense: String?
    var license: String
    var sessionType: String?
    var createdAt: Date
}

struct MomentsRequest: Encodable {
    var sessions: [MomentSession]
    var ratings: [MomentRating]
}

struct MomentsResponse: Codable {
    /// Moment union — `type`-tagged sub-shapes are additive on the server
    /// side; opaque to client. Decode `m["type"]` to dispatch.
    var moments: [JSONValue]
}

// MARK: - 4. Scatter buckets

struct ScatterSession: Codable {
    var date: Date
    var iRatingDelta: Double
    var srDelta: Double
    var incidents: Int
}

struct ScatterRequest: Encodable {
    var sessions: [ScatterSession]
    var timeZone: String?
}

struct ScatterResponse: Codable {
    var buckets: [ScatterBucket]
}

struct ScatterBucket: Codable {
    var day: Int       // 0=Sun, 6=Sat (JS convention)
    var hour: Int      // 0–23, in requested time zone
    var count: Int
    var irDeltaSum: Double
    var srDeltaSum: Double
    var incidentsSum: Int
    var avgIncidents: Double
}

// MARK: - 5. When-engine

struct WhenSession: Codable {
    var id: String
    var userId: String?
    var carModel: String
    var manufacturer: String?
    var category: String
    var gameName: String
    var trackName: String?
    var sessionType: String?
    var finishPosition: Int?
    var incidentCount: Int?
    var metadata: JSONValue?
    var createdAt: Date
}

struct WhenRating: Codable {
    var id: String?
    var userId: String?
    var iRating: Double
    var prevIRating: Double?
    var createdAt: Date
}

struct WhenRequest: Encodable {
    var sessions: [WhenSession]
    var ratings: [WhenRating]
    var timeZone: String?
}

struct WhenResponse: Codable {
    /// WhenProfile — large; kept opaque. See
    /// `apps/web-api/src/calc/when-engine.ts` for the canonical shape.
    var profile: JSONValue?
    var insights: [WhenInsight]
    var panel: WhenPanelView
}

struct WhenInsight: Codable {
    var type: String  // "positive" | "negative" | "neutral"
    var text: String
}

/// Pre-rendered Strengths / Watch Out panel. Native apps render verbatim —
/// no string formatting in Swift.
struct WhenPanelView: Codable {
    var strengths: WhenPanelSide?
    var watchOut: WhenPanelSide?
}

struct WhenPanelSide: Codable {
    var days: String
    var hours: String
    var avgIRatingDelta: Double?
    var paragraph: String
    var bullets: [WhenInsight]
}

// MARK: - 6. Race-Now verdict

/// Opaque WhenProfile — pass through whatever `whenEngine(...)` returned.
typealias WhenProfile = JSONValue

struct RaceNowSessionInput: Codable {
    var trackName: String?
    var carModel: String
    var category: String
    var incidentCount: Int?
    var completedLaps: Int?
}

struct RaceNowRequest: Encodable {
    var profile: WhenProfile?
    var now: Date?
    var timeZone: String?
    var sessions: [RaceNowSessionInput]?
}

struct RaceNowResponse: Codable {
    var evaluation: RaceNowEvaluation?
    var alternatives: [RaceNowAlternative]
}

struct RaceNowEvaluation: Codable {
    var verdict: String  // "good" | "marginal" | "risky" | "insufficient"
    /// Short verdict text for the chip itself, e.g. "Risky window".
    /// Required field per `apps/web-api/src/calc/race-now-verdict.ts` —
    /// missing this caused the macOS panel to fail with "data couldn't
    /// be read because it is missing".
    var headline: String
    /// One-sentence explanation suitable for a subtitle, e.g.
    /// "7.8 inc/race near 4 PM (+1.5 vs your avg) • P16.5 avg finish".
    var detail: String
    /// Raw numbers exposed for a "details" panel — kept opaque since
    /// the server's stats shape is large + evolving (currentHour,
    /// hourSampleCount, hourAvgIncidents, dayAvgPosition, etc.).
    var stats: JSONValue
}

/// Server type: `PracticeAlternative` from
/// `apps/web-api/src/calc/race-now-verdict.ts`. Wire field names —
/// `kind`, `title`, `detail`, `trackName?`, `carModel?` — not the
/// `label`/`reason` placeholders the earlier scaffold used.
struct RaceNowAlternative: Codable {
    var kind: String        // "practice" | "time-trial" | "hot-lap"
    var title: String
    var detail: String
    var trackName: String?
    var carModel: String?
}

// MARK: - 7. Race summary

struct RaceSummaryRequest: Encodable {
    var session: WireSession
    var laps: [JSONValue]
    var behavior: JSONValue?
    var trackHistory: RaceSummaryTrackHistory?
    var ratingContext: RaceSummaryRatingContext
}

struct WireSession: Codable {
    var id: String
    var carModel: String
    var manufacturer: String?
    var trackName: String?
    var finishPosition: Int?
    var incidentCount: Int
    var sessionType: String?
    var category: String
    var metadata: JSONValue?
    var createdAt: Date
}

struct RaceSummaryTrackHistory: Codable {
    var sessions: [WireSession]
    var bestPosition: Int?
    var avgPosition: Double?
    var avgIncidents: Double
    var totalRaces: Int
}

struct RaceSummaryRatingContext: Codable {
    var preRaceIRating: Double?
    var postRaceIRating: Double?
    var preRaceSR: Double?
    var postRaceSR: Double?
    var irDelta: Double?
    var srDelta: Double?
}

struct RaceSummaryResponse: Codable {
    var summary: RaceSummary
}

struct RaceSummary: Codable {
    var headline: String
    var subheadline: String
    var overallVerdict: String  // "excellent" | "good" | "mixed" | "tough" | "learning"
    var strengths: [JSONValue]
    var improvements: [JSONValue]
    var lapAnalysis: JSONValue
    var composureReport: JSONValue?
    var trackContext: JSONValue?
    var ratingImpact: JSONValue?
}

// MARK: - 8. Next race ideas

struct NextRaceIdeasRequest: Encodable {
    var sessions: [JSONValue]
    var ratings: [JSONValue]
    var driverRatings: [DriverRating]
    var schedule: [JSONValue]
    var activeCategories: [String]?
    var timeZone: String?
}

struct DriverRating: Codable {
    var category: String     // "road" | "oval" | "dirt_oval" | "dirt_road" | "formula"
    var iRating: Double
    var safetyRating: String // e.g. "3.45"
    var license: String      // "A" | "B" | "C" | "D" | "R"
}

struct NextRaceIdeasResponse: Codable {
    var suggestions: [NextRaceIdea]
}

struct NextRaceIdea: Codable {
    var seriesName: String
    var trackName: String
    var trackConfig: String?
    var category: String
    var licenseClass: String
    var isOfficial: Bool
    var isFixed: Bool
    var score: Double
    var strategy: NextRaceStrategy
    var commentary: String
    var nextStartTime: Date
    var carClassNames: [String]
    var seasonId: Int
    var seriesId: Int
    var raceLapLimit: Int?
    var raceTimeLimit: Int?
    var scoreBreakdown: JSONValue
}

struct NextRaceStrategy: Codable {
    var type: String  // "pitlane" | "conservative" | "careful" | "form" | "steady"
}

// MARK: - JSONValue (opaque JSON for evolving server shapes)

/// Lightweight any-JSON container so request/response shapes can include
/// fields whose schema evolves server-side without breaking client decode.
/// Cast / drill in at the call site when you need to read specific keys.
enum JSONValue: Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: c.codingPath,
                                                               debugDescription: "unrecognised JSON value"))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}
