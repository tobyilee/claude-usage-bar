import Foundation

enum AnthropicError: Error, LocalizedError {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case http(Int, String)
    case decoding(String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "401 unauthorized"
        case .rateLimited(let retry):
            if let r = retry, r >= 60 {
                return "Rate limited — retry in \(Int((r / 60).rounded(.up)))m"
            } else if let r = retry, r > 0 {
                return "Rate limited — retry in \(Int(r))s"
            } else {
                return "Rate limited — backing off"
            }
        case .http(let code, let body): return "HTTP \(code): \(body.prefix(200))"
        case .decoding(let m): return "Decode error: \(m)"
        case .network(let e): return "Network error: \(e.localizedDescription)"
        }
    }
}

actor AnthropicClient {
    static let shared = AnthropicClient()

    /// Public client_id used by the official Claude Code CLI for OAuth token refresh.
    static let oauthClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 10
        cfg.timeoutIntervalForResource = 15
        return URLSession(configuration: cfg)
    }()

    func fetchUsage(token: String) async throws -> UsageResponse {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        return try await send(req)
    }

    func fetchProfile(token: String) async throws -> ProfileResponse {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/profile")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        return try await send(req)
    }

    func refreshTokens(refreshToken: String) async throws -> TokenRefreshResponse {
        var req = URLRequest(url: URL(string: "https://console.anthropic.com/v1/oauth/token")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.oauthClientID,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(req)
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw AnthropicError.network(error)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw AnthropicError.decoding("non-HTTP response")
        }
        if http.statusCode == 401 { throw AnthropicError.unauthorized }
        if http.statusCode == 420 || http.statusCode == 429 {
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }
            throw AnthropicError.rateLimited(retryAfter: retry)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AnthropicError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder.flexible.decode(T.self, from: data)
        } catch {
            throw AnthropicError.decoding("\(error)")
        }
    }
}
