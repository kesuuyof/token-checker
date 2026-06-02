import Foundation

/// GitHub Copilot の内部 quota エンドポイントを叩いて生 DTO を返す。
///
/// 公式 IDE 拡張 / Copilot CLI が叩く非公開エンドポイントで、ドキュメント化されていないため
/// レスポンス構造は将来変わる可能性がある。`Editor-Version` ヘッダが無いと 400 を返す挙動が
/// 観測されているので必ず付与する。
struct GitHubCopilotAPIClient: Sendable {
    static let usageURL = URL(string: "https://api.github.com/copilot_internal/user")!
    static let editorIdentifier = "TokenChecker/0.1"

    /// Anthropic 側と同様に、Bearer トークンを抱えたままリダイレクトに追従しないよう
    /// 専用 URLSession を用意する。
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(
            configuration: config,
            delegate: CopilotNoRedirectDelegate.shared,
            delegateQueue: nil
        )
    }()

    func fetch(accessToken: String) async throws -> CopilotUsageDTO {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("token \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.editorIdentifier, forHTTPHeaderField: "Editor-Version")
        request.setValue(Self.editorIdentifier, forHTTPHeaderField: "Editor-Plugin-Version")
        request.setValue(Self.editorIdentifier, forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch {
            throw DomainError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw DomainError.network("Invalid response")
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw DomainError.copilotUnauthorized
        case 404:
            // Copilot のサブスクリプションが無いアカウントは 404 を返す。
            throw DomainError.copilotNotSubscribed
        case 429:
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")
                              ?? http.value(forHTTPHeaderField: "retry-after"))
                .flatMap(TimeInterval.init)
            throw DomainError.copilotRateLimited(retryAfter: retryAfter)
        default:
            throw DomainError.copilotHTTP(status: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(CopilotUsageDTO.self, from: data)
        } catch {
            throw DomainError.decoding("Copilot usage: \(error.localizedDescription)")
        }
    }
}

private final class CopilotNoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = CopilotNoRedirectDelegate()

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

// MARK: - DTO

/// `copilot_internal/user` のレスポンス。
///
/// - 現行 API: Free / Paid とも `quota_snapshots` に `premium_interactions` / `chat` /
///   `completions` が並ぶ。各 bucket は `entitlement` / `remaining` / `percent_remaining` を持つ。
///   Free プランは premium_interactions を `entitlement: 0`（= 枠なし）で返す。
/// - 旧 API（フォールバックとして残置）: Free は `limited_user_quotas` (= remaining)、
///   `monthly_quotas` (= entitlement)、`limited_user_reset_date` のセットで返していた。
struct CopilotUsageDTO: Decodable, Sendable {
    // Paid
    let quotaSnapshots: Snapshots?
    let quotaResetDate: String?

    // Free
    let limitedUserQuotas: SimpleQuota?
    let monthlyQuotas: SimpleQuota?
    let limitedUserResetDate: String?

    let copilotPlan: String?
    let accessTypeSku: String?

    enum CodingKeys: String, CodingKey {
        case quotaSnapshots = "quota_snapshots"
        case quotaResetDate = "quota_reset_date"
        case limitedUserQuotas = "limited_user_quotas"
        case monthlyQuotas = "monthly_quotas"
        case limitedUserResetDate = "limited_user_reset_date"
        case copilotPlan = "copilot_plan"
        case accessTypeSku = "access_type_sku"
    }

    struct Snapshots: Decodable, Sendable {
        let premiumInteractions: Bucket?
        let chat: Bucket?
        let completions: Bucket?

        enum CodingKeys: String, CodingKey {
            case premiumInteractions = "premium_interactions"
            case chat
            case completions
        }
    }

    struct Bucket: Decodable, Sendable {
        let entitlement: Double?
        let remaining: Double?
        let percentRemaining: Double?
        let unlimited: Bool?
        let resetDate: String?

        enum CodingKeys: String, CodingKey {
            case entitlement
            case remaining
            case percentRemaining = "percent_remaining"
            case unlimited
            case resetDate = "reset_date"
        }
    }

    /// Free プラン用の単純な数値。`chat` / `completions` の 2 種類が返る。
    struct SimpleQuota: Decodable, Sendable {
        let chat: Double?
        let completions: Double?
    }
}

extension CopilotUsageDTO.Bucket {
    /// 使用率に意味が無い枠は nil を返す（UI 側で非表示）:
    ///   - `unlimited == true`: 上限なし。
    ///   - `entitlement == 0`: そのプランに存在しない枠（例: Free の premium_interactions）。
    ///     現行 API は Free でも premium_interactions を entitlement 0 / percent_remaining 0 で
    ///     返すため、これを除外しないと「100% 使用」と誤表示される。
    ///     ※ entitlement > 0 で remaining 0（= 使い切り）は 100% 使用として正しく表示する。
    func toRateLimit(fallbackReset: String?) -> RateLimit? {
        if unlimited == true { return nil }
        if let ent = entitlement, ent == 0 { return nil }

        let utilization: Double?
        if let pct = percentRemaining {
            utilization = max(0.0, (100.0 - pct) / 100.0)
        } else if let ent = entitlement, ent > 0, let rem = remaining {
            utilization = max(0.0, (ent - rem) / ent)
        } else {
            utilization = nil
        }
        guard let u = utilization else { return nil }

        let rawDate = resetDate ?? fallbackReset
        guard let date = rawDate.flatMap(Self.parseReset) else { return nil }
        return RateLimit(utilization: u, resetsAt: date)
    }

    /// Copilot の reset_date は ISO8601 (`2026-06-01T00:00:00Z`) と date-only (`2026-06-01`) の
    /// 両方が観測されているので両方サポートする。
    private static func parseReset(_ raw: String) -> Date? {
        if let d = ISO8601DateFormatter.standard.date(from: raw) { return d }
        if let d = ISO8601DateFormatter.withFractional.date(from: raw) { return d }
        let dateOnly = DateFormatter()
        dateOnly.calendar = Calendar(identifier: .gregorian)
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.timeZone = TimeZone(identifier: "UTC")
        dateOnly.dateFormat = "yyyy-MM-dd"
        return dateOnly.date(from: raw)
    }
}
