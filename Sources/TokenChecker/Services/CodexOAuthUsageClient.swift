import Foundation

struct CodexOAuthUsageClient: Sendable {
    static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    let transport: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    init(transport: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse) = Self.defaultTransport) {
        self.transport = transport
    }

    func fetch(credentials: CodexOAuthCredentials) async throws -> ServiceUsage {
        var request = URLRequest(url: Self.usageURL, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("TokenChecker", forHTTPHeaderField: "User-Agent")
        if let accountId = credentials.accountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport(request)
        } catch let error as CodexOAuthError {
            throw error
        } catch {
            throw CodexOAuthError.network(error.localizedDescription)
        }

        switch response.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw CodexOAuthError.unauthorized
        default:
            throw CodexOAuthError.httpStatus(response.statusCode)
        }

        let payload: UsageResponse
        do {
            payload = try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            throw CodexOAuthError.invalidResponse
        }

        return ServiceUsage(
            fiveHour: payload.rateLimit?.rateLimit(windowDuration: 5 * 60 * 60),
            weekly: payload.rateLimit?.rateLimit(windowDuration: 7 * 24 * 60 * 60),
            weeklySonnet: nil
        )
    }

    private static let defaultTransport: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse) = { request in
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        let session = URLSession(configuration: config, delegate: CodexUsageNoRedirectDelegate(), delegateQueue: nil)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CodexOAuthError.invalidResponse }
        return (data, http)
    }
}

private struct UsageResponse: Decodable {
    let rateLimit: RateLimitDetails?

    enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
    }

    struct RateLimitDetails: Decodable {
        let primaryWindow: Window?
        let secondaryWindow: Window?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }

        func rateLimit(windowDuration: TimeInterval) -> RateLimit? {
            [primaryWindow, secondaryWindow]
                .compactMap { $0 }
                .first { $0.limitWindowSeconds == windowDuration }?
                .rateLimit
        }
    }

    struct Window: Decodable {
        let usedPercent: Double?
        let resetAt: TimeInterval?
        let limitWindowSeconds: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case resetAt = "reset_at"
            case limitWindowSeconds = "limit_window_seconds"
        }

        var rateLimit: RateLimit? {
            guard let usedPercent, let resetAt else { return nil }
            return RateLimit(
                utilization: max(0, usedPercent / 100),
                resetsAt: Date(timeIntervalSince1970: resetAt)
            )
        }
    }
}

private final class CodexUsageNoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
