import Foundation

final class APIClient {
    static let shared = APIClient()

    private var baseURL: URL {
        if let devURL = UserDefaults.standard.string(forKey: "racecor.dev.baseURL"),
           let url = URL(string: devURL) {
            return url
        }
        return URL(string: "https://prodrive.racecor.io")!
    }

    private let session = URLSession.shared
    private var accessToken: String?
    private let tokenStore = TokenStore()

    func setToken(_ token: String) {
        accessToken = token
    }

    func clearToken() {
        accessToken = nil
    }

    func me() async throws -> Me {
        return try await request(endpoint: "/api/v1/me")
    }

    func sessions(limit: Int = 50, offset: Int = 0, category: String = "all") async throws -> SessionListResponse {
        let query = "limit=\(limit)&offset=\(offset)&category=\(category)"
        return try await request(endpoint: "/api/v1/sessions?\(query)")
    }

    func session(id: String) async throws -> SessionDetail {
        return try await request(endpoint: "/api/v1/sessions/\(id)")
    }

    func dashboard(
        context: DashboardContext = .race,
        license: DashboardLicense = .all,
    ) async throws -> Dashboard {
        // Pass the device's IANA timezone so the server buckets the
        // returned WhenProfile.byHour / rankedSlots in the user's
        // local hour-of-week. Without this, the server defaults to
        // UTC and rankedSlots[localHour] returns the wrong bucket of
        // sessions.
        let tz = TimeZone.current.identifier
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            ?? "UTC"

        // Context + license carry the user's dashboard view prefs.
        // Defaults match the server's defaults (`race` + `all`) so a
        // caller that omits them gets backward-compat behavior.
        var endpoint = "/api/v1/dashboard?tz=\(tz)"
        endpoint += "&context=\(context.rawValue)"
        endpoint += "&license=\(license.rawValue)"
        return try await request(endpoint: endpoint)
    }

    func tokensNative(format: String = "swift") async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/tokens/native"))
        request.url?.append(queryItems: [URLQueryItem(name: "format", value: format)])

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        try handleResponse(response)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func request<T: Decodable>(endpoint: String) async throws -> T {
        // String-concat instead of `appendingPathComponent`: the
        // latter percent-encodes the `?` query separator into `%3F`,
        // so endpoints like `/api/v1/dashboard?tz=America/Denver`
        // become `/api/v1/dashboard%3Ftz=America/Denver` — a literal
        // path with `?` baked in, not a URL with a query string.
        // Server then 404s the bogus path and the dashboard renders
        // empty. iOS's APIClient already uses raw concat; this
        // brings mac into line.
        guard let url = URL(string: baseURL.absoluteString + endpoint) else {
            throw APIError.invalidURL
        }
        var urlRequest = URLRequest(url: url)

        if let token = accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)

        if (response as? HTTPURLResponse)?.statusCode == 401 {
            // Attempt refresh, then retry once
            if try await refreshToken() {
                return try await self.request(endpoint: endpoint)
            } else {
                throw APIError.unauthorized
            }
        }

        try handleResponse(response)

        return try JSONDecoder.racecor.decode(T.self, from: data)
    }

    private func refreshToken() async throws -> Bool {
        guard let tokens = tokenStore.load() else {
            return false
        }

        let url = baseURL.appendingPathComponent("/api/plugin-auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RefreshTokenRequest(grant_type: "refresh_token", refresh_token: tokens.refreshToken)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            tokenStore.delete()
            return false
        }

        let tokenResponse = try JSONDecoder.racecor.decode(TokenResponse.self, from: data)

        tokenStore.save(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token,
            expiresAt: tokenResponse.expires_at
        )
        setToken(tokenResponse.access_token)

        return true
    }

    private func handleResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}

enum APIError: Error {
    case invalidURL
    case unauthorized
    case notFound
    case serverError(statusCode: Int)
}

private struct RefreshTokenRequest: Codable {
    let grant_type: String
    let refresh_token: String
}

private struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let token_type: String
    let expires_at: Date
}

extension JSONDecoder {
    /// Shared decoder for all server responses. Uses a custom date strategy
    /// because the server serializes `Date` via `JSON.stringify`, which
    /// emits fractional seconds (e.g. `2026-04-23T18:30:00.123Z`). Swift's
    /// built-in `.iso8601` strategy rejects fractional seconds, which broke
    /// `/api/plugin-auth/token` parsing. This decoder accepts both forms.
    static let racecor: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let fmtMs = ISO8601DateFormatter()
            fmtMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmtMs.date(from: raw) { return d }
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime]
            if let d = fmt.date(from: raw) { return d }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO8601 date (with or without fractional seconds), got: \(raw)"
            )
        }
        return decoder
    }()
}
