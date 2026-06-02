import Foundation

/// `~/.config/github-copilot/{apps,hosts}.json` または `gh auth token` → Copilot 内部 quota API。
struct CopilotUsageProvider: UsageProvider {
    let tokenSource: GitHubCopilotTokenSource
    let api: GitHubCopilotAPIClient

    init(
        tokenSource: GitHubCopilotTokenSource = .init(),
        api: GitHubCopilotAPIClient = .init()
    ) {
        self.tokenSource = tokenSource
        self.api = api
    }

    func fetch() async throws -> ServiceUsage {
        let token = try await tokenSource.readAccessToken()
        let dto = try await api.fetch(accessToken: token)
        return Self.serviceUsage(from: dto)
    }

    /// DTO → ServiceUsage の純粋変換（ネットワーク非依存。テスト対象）。
    static func serviceUsage(from dto: CopilotUsageDTO) -> ServiceUsage {
        // quota_snapshots がある場合はそちらを優先（現行 API は Free / Paid とも返す）。
        // モデル側のスロット名 (fiveHour/weekly/weeklySonnet) を Copilot 用には
        // 「主指標 / サブ1 / サブ2」として再解釈する。
        if let snaps = dto.quotaSnapshots,
           (snaps.premiumInteractions != nil || snaps.chat != nil || snaps.completions != nil)
        {
            let premium = snaps.premiumInteractions?.toRateLimit(fallbackReset: dto.quotaResetDate)
            let chat = snaps.chat?.toRateLimit(fallbackReset: dto.quotaResetDate)
            let completions = snaps.completions?.toRateLimit(fallbackReset: dto.quotaResetDate)

            // premium_interactions が有効（entitlement > 0）なら Paid 表示: プレミアム要求を主、
            // チャット/補完を従にする。Free 等で premium が無効（entitlement 0 → nil）なら、
            // チャットを主・補完を従にした Free 表示へフォールバックする。
            if premium != nil {
                return ServiceUsage(fiveHour: premium, weekly: chat, weeklySonnet: completions)
            }
            return ServiceUsage(
                fiveHour: chat,
                weekly: completions,
                weeklySonnet: nil,
                copilotFreeMode: true
            )
        }

        // Free プラン: limited_user_quotas (= remaining) を monthly_quotas で割る。
        // premium request は無いので、主スロットには chat を入れて 2 段表示にする。
        let reset = Self.parseDate(dto.limitedUserResetDate ?? dto.quotaResetDate)
        let chat = makeRateLimit(
            remaining: dto.limitedUserQuotas?.chat,
            entitlement: dto.monthlyQuotas?.chat,
            reset: reset
        )
        let completions = makeRateLimit(
            remaining: dto.limitedUserQuotas?.completions,
            entitlement: dto.monthlyQuotas?.completions,
            reset: reset
        )
        return ServiceUsage(
            fiveHour: chat,
            weekly: completions,
            weeklySonnet: nil,
            copilotFreeMode: true
        )
    }

    private static func makeRateLimit(remaining: Double?, entitlement: Double?, reset: Date?) -> RateLimit? {
        guard let remaining, let entitlement, entitlement > 0, let reset else { return nil }
        let used = max(0, entitlement - remaining)
        let utilization = used / entitlement
        return RateLimit(utilization: utilization, resetsAt: reset)
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
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
