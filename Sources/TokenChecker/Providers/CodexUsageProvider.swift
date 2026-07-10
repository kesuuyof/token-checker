import Foundation

/// 保存済み Codex OAuth セッションを優先して rate limit を取得し、
/// 認証状態を回復できない場合だけ `codex app-server` へフォールバックする。
final class CodexUsageProvider: UsageProvider, @unchecked Sendable {
    private let client: CodexAppServerClient?
    private let fetchOAuth: @Sendable () async throws -> ServiceUsage
    private let fetchFallback: @Sendable () async throws -> ServiceUsage

    init(
        client: CodexAppServerClient = .init(),
        credentialsStore: CodexOAuthCredentialsStore = .init(),
        tokenRefresher: CodexTokenRefresher = .init(),
        oauthClient: CodexOAuthUsageClient = .init()
    ) {
        self.client = client
        self.fetchOAuth = {
            var credentials = try credentialsStore.load()
            if credentials.needsRefresh() {
                credentials = try await tokenRefresher.refresh(credentials)
                try credentialsStore.save(credentials)
            }
            return try await oauthClient.fetch(credentials: credentials)
        }
        self.fetchFallback = {
            try await Self.fetchUsingAppServer(client)
        }
    }

    init(
        fetchOAuth: @escaping @Sendable () async throws -> ServiceUsage,
        fetchFallback: @escaping @Sendable () async throws -> ServiceUsage
    ) {
        self.client = nil
        self.fetchOAuth = fetchOAuth
        self.fetchFallback = fetchFallback
    }

    func fetch() async throws -> ServiceUsage {
        do {
            return try await fetchOAuth()
        } catch let error as CodexOAuthError where error.allowsAppServerFallback {
            return try await fetchFallback()
        }
    }

    private static func fetchUsingAppServer(_ client: CodexAppServerClient) async throws -> ServiceUsage {
        do {
            try await client.start()
            let dto = try await client.readRateLimits()
            return ServiceUsage(
                fiveHour: dto.fiveHourRateLimit(),
                weekly: dto.weeklyRateLimit(),
                weeklySonnet: nil
            )
        } catch DomainError.codexProcessExited {
            // 一度落ちていたら再起動して再試行
            await client.stop()
            try await client.start()
            let dto = try await client.readRateLimits()
            return ServiceUsage(
                fiveHour: dto.fiveHourRateLimit(),
                weekly: dto.weeklyRateLimit(),
                weeklySonnet: nil
            )
        }
    }

    func shutdown() async {
        await client?.stop()
    }
}
