@testable import TokenChecker
import XCTest

/// `copilot_internal/user` の現行仕様 (Free / Paid とも quota_snapshots を返す) に対する
/// デコード・解釈のリグレッションテスト。
final class CopilotUsageDecodingTests: XCTestCase {

    private func decode(_ json: String) throws -> CopilotUsageDTO {
        try JSONDecoder().decode(CopilotUsageDTO.self, from: Data(json.utf8))
    }

    /// Free プラン (free_limited_copilot) の実レスポンス。
    /// premium_interactions は entitlement 0 で返る。
    private let freeResponse = """
    {
      "login": "tester",
      "access_type_sku": "free_limited_copilot",
      "copilot_plan": "individual",
      "quota_snapshots": {
        "chat": {
          "percent_remaining": 99.8, "unlimited": false,
          "remaining": 199, "entitlement": 200
        },
        "completions": {
          "percent_remaining": 99.1, "unlimited": false,
          "remaining": 1982, "entitlement": 2000
        },
        "premium_interactions": {
          "percent_remaining": 0.0, "unlimited": false,
          "remaining": 0, "entitlement": 0
        }
      },
      "quota_reset_date": "2026-07-01"
    }
    """

    /// entitlement 0 の premium_interactions は「100% 使用」ではなく非表示 (nil)。
    func testEntitlementZeroBucketIsHidden() throws {
        let dto = try decode(freeResponse)
        XCTAssertNil(dto.quotaSnapshots?.premiumInteractions?.toRateLimit(fallbackReset: dto.quotaResetDate))
    }

    /// entitlement > 0 の枠は percent_remaining から正しい使用率を出す。
    func testActiveBucketUsesPercentRemaining() throws {
        let dto = try decode(freeResponse)
        let chat = try XCTUnwrap(dto.quotaSnapshots?.chat?.toRateLimit(fallbackReset: dto.quotaResetDate))
        XCTAssertEqual(chat.utilization, 0.002, accuracy: 0.0001) // 99.8% remaining → 0.2% used
    }

    /// Free アカウントは premium が無効なので chat 主・completions 従の Free 表示になる。
    func testFreePlanFallsBackToChatPrimary() throws {
        let dto = try decode(freeResponse)
        let usage = CopilotUsageProvider.serviceUsage(from: dto)

        XCTAssertTrue(usage.copilotFreeMode)
        XCTAssertNotNil(usage.fiveHour)   // chat
        XCTAssertNotNil(usage.weekly)     // completions
        XCTAssertNil(usage.weeklySonnet)
        // 主指標(chat)の使用率は 0.2%
        XCTAssertEqual(usage.fiveHour?.utilization ?? -1, 0.002, accuracy: 0.0001)
    }

    /// 使い切り (entitlement > 0, remaining 0, percent_remaining 0) は 100% 使用として表示する。
    func testExhaustedQuotaShowsFullUtilization() throws {
        let json = """
        { "quota_snapshots": { "premium_interactions": {
            "percent_remaining": 0.0, "unlimited": false,
            "remaining": 0, "entitlement": 300
        } }, "quota_reset_date": "2026-07-01" }
        """
        let dto = try decode(json)
        let premium = try XCTUnwrap(dto.quotaSnapshots?.premiumInteractions?.toRateLimit(fallbackReset: dto.quotaResetDate))
        XCTAssertEqual(premium.utilization, 1.0, accuracy: 0.0001)
    }

    /// Paid プラン (premium entitlement > 0) はプレミアム要求を主指標にする。
    func testPaidPlanUsesPremiumPrimary() throws {
        let json = """
        { "quota_snapshots": {
            "premium_interactions": { "percent_remaining": 50.0, "unlimited": false, "remaining": 150, "entitlement": 300 },
            "chat": { "percent_remaining": 90.0, "unlimited": false, "remaining": 900, "entitlement": 1000 },
            "completions": { "unlimited": true }
        }, "quota_reset_date": "2026-07-01" }
        """
        let dto = try decode(json)
        let usage = CopilotUsageProvider.serviceUsage(from: dto)
        XCTAssertFalse(usage.copilotFreeMode)
        XCTAssertEqual(usage.fiveHour?.utilization ?? -1, 0.5, accuracy: 0.0001) // premium
        XCTAssertNotNil(usage.weekly)        // chat
        XCTAssertNil(usage.weeklySonnet)     // completions unlimited → 非表示
    }
}
