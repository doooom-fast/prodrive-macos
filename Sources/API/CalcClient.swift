import Foundation

/// Wraps the eight web-api `/api/v1/calc/*` endpoints.
///
/// Spec: `prodrive-server/docs/native-app-integration.md`. Per-screen REST
/// (`prodrive.racecor.io/api/v1/*`, served by `APIClient.shared`) is the
/// default for fetching user-scoped data; this client is the escape hatch
/// for what-if flows — windowed DNA, scoped Mastery, race-summary against
/// a session not yet in the DB, etc.
///
/// Auth: the Phase 9b plan is to gate calc behind the same Bearer the
/// per-screen surface uses. We send it prophylactically today (web-api
/// ignores it for now) so when the gate flips on, no client release is
/// needed. `AuthManager` should call `setBearerToken(_:)` here whenever
/// it calls `APIClient.shared.setTokens(_:)` — same JWT, two surfaces.
actor CalcClient {
    static let shared = CalcClient()

    // Apex host, NOT an `api.` subdomain: the zone cert covers `racecor.io`
    // and `*.racecor.io` only (one label deep), so `api.prodrive.racecor.io`
    // (two deep) fails the TLS handshake and every calc call throws. Same
    // origin `APIClient.shared` uses. Keep on the apex unless a cert covering
    // the api subdomain is provisioned (Cloudflare ACM / Total TLS).
    private let baseURL = "https://prodrive.racecor.io"
    private let session: URLSession
    private var bearerToken: String?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func setBearerToken(_ token: String?) {
        self.bearerToken = token
    }

    // MARK: - 1. Driver DNA

    func driverDna(sessions: [DnaSession], ratings: [DnaRating]) async throws -> DriverDnaResponse {
        try await post("/api/v1/calc/dna", body: DnaRequest(sessions: sessions, ratings: ratings))
    }

    // MARK: - 2. Mastery

    func mastery(sessions: [MasterySession]) async throws -> MasteryResponse {
        try await post("/api/v1/calc/mastery", body: MasteryRequest(sessions: sessions))
    }

    // MARK: - 3. Moments

    func moments(sessions: [MomentSession], ratings: [MomentRating]) async throws -> MomentsResponse {
        try await post("/api/v1/calc/moments", body: MomentsRequest(sessions: sessions, ratings: ratings))
    }

    // MARK: - 4. Scatter buckets

    func scatter(sessions: [ScatterSession], timeZone: String? = nil) async throws -> ScatterResponse {
        try await post("/api/v1/calc/scatter", body: ScatterRequest(sessions: sessions, timeZone: timeZone))
    }

    // MARK: - 5. When-engine

    func whenEngine(
        sessions: [WhenSession],
        ratings: [WhenRating],
        timeZone: String? = nil
    ) async throws -> WhenResponse {
        try await post("/api/v1/calc/when",
                       body: WhenRequest(sessions: sessions, ratings: ratings, timeZone: timeZone))
    }

    // MARK: - 6. Race-Now verdict
    //
    // Recommended cadence: once on app start, then once every 5–10 min (or
    // on hour rollover via a Timer aligned to the next hour boundary).
    // The verdict only changes on hour boundaries — faster polling burns
    // the user's data plan for nothing.

    func raceNow(
        profile: WhenProfile? = nil,
        now: Date? = nil,
        timeZone: String? = nil,
        sessions: [RaceNowSessionInput]? = nil
    ) async throws -> RaceNowResponse {
        try await post("/api/v1/calc/race-now",
                       body: RaceNowRequest(profile: profile, now: now, timeZone: timeZone, sessions: sessions))
    }

    // MARK: - 7. Race summary

    func raceSummary(_ request: RaceSummaryRequest) async throws -> RaceSummaryResponse {
        try await post("/api/v1/calc/race-summary", body: request)
    }

    // MARK: - 8. Next race ideas

    func nextRaceIdeas(_ request: NextRaceIdeasRequest) async throws -> NextRaceIdeasResponse {
        try await post("/api/v1/calc/next-race-ideas", body: request)
    }

    // MARK: - Core POST helper

    private func post<Req: Encodable, Resp: Decodable>(
        _ path: String,
        body: Req
    ) async throws -> Resp {
        guard let url = URL(string: baseURL + path) else { throw CalcError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            request.httpBody = try JSONEncoder.racecorWire.encode(body)
        } catch {
            throw CalcError.encodingFailed(error)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CalcError.networkFailed(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CalcError.networkFailed(NSError(domain: "calc", code: -1))
        }
        if http.statusCode == 401 { throw CalcError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw CalcError.serverError(statusCode: http.statusCode, data: data)
        }

        do {
            return try JSONDecoder.racecor.decode(Resp.self, from: data)
        } catch {
            throw CalcError.decodingFailed(error)
        }
    }
}

/// Self-contained error enum so CalcClient is portable across the four
/// native repos regardless of each repo's local `APIError` shape.
public enum CalcError: LocalizedError {
    case invalidURL
    case encodingFailed(Error)
    case networkFailed(Error)
    case unauthorized
    case serverError(statusCode: Int, data: Data)
    case decodingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:                          return "Invalid calc API URL"
        case .encodingFailed(let e):               return "Calc request encode failed: \(e.localizedDescription)"
        case .networkFailed(let e):                return "Calc network error: \(e.localizedDescription)"
        case .unauthorized:                        return "Calc API unauthorized"
        case .serverError(let code, _):            return "Calc API \(code)"
        case .decodingFailed(let e):               return "Calc response decode failed: \(e.localizedDescription)"
        }
    }
}

// MARK: - Wire encoder (camelCase + ISO-8601 dates on the wire)

extension JSONEncoder {
    static let racecorWire: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
