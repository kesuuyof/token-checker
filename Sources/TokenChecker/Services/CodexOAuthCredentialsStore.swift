import Foundation
import Darwin

struct CodexOAuthCredentials: Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accountId: String?
    let lastRefresh: Date?

    func needsRefresh(now: Date = Date()) -> Bool {
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) > 8 * 24 * 60 * 60
    }
}

enum CodexOAuthError: Error, Equatable, Sendable {
    case credentialsMissing
    case credentialsMalformed
    case tokensMissing
    case tokenExpired
    case tokenRevoked
    case tokenReused
    case unauthorized
    case httpStatus(Int)
    case invalidResponse
    case network(String)

    var allowsAppServerFallback: Bool {
        switch self {
        case .credentialsMissing, .credentialsMalformed, .tokensMissing,
             .tokenExpired, .tokenRevoked, .tokenReused, .unauthorized:
            true
        case .httpStatus, .invalidResponse, .network:
            false
        }
    }
}

struct CodexOAuthCredentialsStore: Sendable {
    let homeURL: URL

    init(homeURL: URL = Self.defaultHomeURL()) {
        self.homeURL = homeURL
    }

    func load() throws -> CodexOAuthCredentials {
        let authURL = homeURL.appendingPathComponent("auth.json")
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            throw CodexOAuthError.credentialsMissing
        }

        let data: Data
        do {
            data = try Data(contentsOf: authURL)
        } catch {
            throw CodexOAuthError.credentialsMalformed
        }

        let document: AuthDocument
        do {
            document = try JSONDecoder().decode(AuthDocument.self, from: data)
        } catch {
            throw CodexOAuthError.credentialsMalformed
        }

        guard let tokens = document.tokens,
              let accessToken = tokens.accessToken,
              let refreshToken = tokens.refreshToken,
              !accessToken.isEmpty,
              !refreshToken.isEmpty
        else {
            throw CodexOAuthError.tokensMissing
        }

        return CodexOAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accountId: tokens.accountId,
            lastRefresh: document.lastRefresh
        )
    }

    func save(_ credentials: CodexOAuthCredentials) throws {
        let authURL = homeURL.appendingPathComponent("auth.json")
        var document: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: authURL.path) {
            do {
                let existing = try Data(contentsOf: authURL)
                guard let json = try JSONSerialization.jsonObject(with: existing) as? [String: Any] else {
                    throw CodexOAuthError.credentialsMalformed
                }
                document = json
            } catch let error as CodexOAuthError {
                throw error
            } catch {
                throw CodexOAuthError.credentialsMalformed
            }
        }

        var tokens: [String: Any] = [
            "access_token": credentials.accessToken,
            "refresh_token": credentials.refreshToken,
        ]
        if let accountId = credentials.accountId {
            tokens["account_id"] = accountId
        }
        document["tokens"] = tokens
        document["last_refresh"] = ISO8601DateFormatter.standard.string(from: credentials.lastRefresh ?? Date())

        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
        } catch {
            throw CodexOAuthError.credentialsMalformed
        }

        try FileManager.default.createDirectory(at: homeURL, withIntermediateDirectories: true)
        try writePrivateFile(data, replacing: authURL)
    }

    private func writePrivateFile(_ data: Data, replacing destination: URL) throws {
        let staged = destination.deletingLastPathComponent().appendingPathComponent(
            ".auth.json.token-checker-staged-\(UUID().uuidString)"
        )
        let descriptor = staged.path.withCString { open($0, O_WRONLY | O_CREAT | O_EXCL, 0o600) }
        guard descriptor >= 0 else { throw CodexOAuthError.credentialsMalformed }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            guard fchmod(descriptor, 0o600) == 0 else { throw CodexOAuthError.credentialsMalformed }
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            let renameResult = staged.path.withCString { source in
                destination.path.withCString { target in rename(source, target) }
            }
            guard renameResult == 0 else { throw CodexOAuthError.credentialsMalformed }
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: staged)
            throw error
        }
    }

    private static func defaultHomeURL() -> URL {
        if let value = ProcessInfo.processInfo.environment["CODEX_HOME"], !value.isEmpty {
            return URL(fileURLWithPath: value)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }
}

struct CodexTokenRefresher: Sendable {
    private static let endpoint = URL(string: "https://auth.openai.com/oauth/token")!
    private static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    let transport: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    init(transport: (@Sendable (URLRequest) async throws -> (Data, HTTPURLResponse))? = nil) {
        self.transport = transport ?? Self.defaultTransport
    }

    func refresh(_ credentials: CodexOAuthCredentials) async throws -> CodexOAuthCredentials {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": Self.clientID,
            "grant_type": "refresh_token",
            "refresh_token": credentials.refreshToken,
            "scope": "openid profile email",
        ])

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport(request)
        } catch {
            throw CodexOAuthError.network(error.localizedDescription)
        }

        guard response.statusCode == 200 else {
            throw Self.error(for: response.statusCode, data: data)
        }

        let payload: RefreshResponse
        do {
            payload = try JSONDecoder().decode(RefreshResponse.self, from: data)
        } catch {
            throw CodexOAuthError.invalidResponse
        }

        guard let accessToken = payload.accessToken, !accessToken.isEmpty else {
            throw CodexOAuthError.invalidResponse
        }
        return CodexOAuthCredentials(
            accessToken: accessToken,
            refreshToken: payload.refreshToken ?? credentials.refreshToken,
            accountId: payload.accountId ?? credentials.accountId,
            lastRefresh: Date()
        )
    }

    private static func error(for status: Int, data: Data) -> CodexOAuthError {
        if let payload = try? JSONDecoder().decode(RefreshErrorResponse.self, from: data) {
            switch payload.error {
            case "refresh_token_expired": return .tokenExpired
            case "refresh_token_reused": return .tokenReused
            case "invalid_grant", "refresh_token_invalidated": return .tokenRevoked
            default: break
            }
        }
        return status == 401 ? .tokenExpired : .httpStatus(status)
    }

    private static let defaultTransport: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse) = { request in
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        let session = URLSession(configuration: config, delegate: CodexOAuthNoRedirectDelegate(), delegateQueue: nil)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CodexOAuthError.invalidResponse }
        return (data, http)
    }

    private struct RefreshResponse: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let accountId: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case accountId = "account_id"
        }
    }

    private struct RefreshErrorResponse: Decodable {
        let error: String?
    }
}

private final class CodexOAuthNoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
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

private struct AuthDocument: Decodable {
    let tokens: Tokens?
    let lastRefresh: Date?

    enum CodingKeys: String, CodingKey {
        case tokens
        case lastRefresh = "last_refresh"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokens = try container.decodeIfPresent(Tokens.self, forKey: .tokens)
        if let raw = try container.decodeIfPresent(String.self, forKey: .lastRefresh) {
            lastRefresh = ISO8601DateFormatter.standard.date(from: raw)
                ?? ISO8601DateFormatter.withFractional.date(from: raw)
        } else {
            lastRefresh = nil
        }
    }

    struct Tokens: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let accountId: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accessTokenCamel = "accessToken"
            case refreshToken = "refresh_token"
            case refreshTokenCamel = "refreshToken"
            case accountId = "account_id"
            case accountIdCamel = "accountId"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
                ?? container.decodeIfPresent(String.self, forKey: .accessTokenCamel)
            refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
                ?? container.decodeIfPresent(String.self, forKey: .refreshTokenCamel)
            accountId = try container.decodeIfPresent(String.self, forKey: .accountId)
                ?? container.decodeIfPresent(String.self, forKey: .accountIdCamel)
        }
    }
}
