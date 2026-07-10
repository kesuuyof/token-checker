@testable import TokenChecker
import XCTest

final class CodexUsageProviderTests: XCTestCase {
    private let oauthUsage = ServiceUsage(
        fiveHour: RateLimit(utilization: 0.25, resetsAt: .distantFuture),
        weekly: RateLimit(utilization: 0.5, resetsAt: .distantFuture),
        weeklySonnet: nil
    )

    func testFetchUsesOAuthResultWithoutCallingFallback() async throws {
        let fallback = FallbackRecorder(result: .success(makeUsage(utilization: 0.9)))
        let provider = CodexUsageProvider(
            fetchOAuth: { self.oauthUsage },
            fetchFallback: { try await fallback.fetch() }
        )

        let usage = try await provider.fetch()
        let count = await fallback.fetchCount()
        XCTAssertEqual(usage, oauthUsage)
        XCTAssertEqual(count, 0)
    }

    func testFetchFallsBackForUnauthorizedOAuth() async throws {
        let fallbackUsage = makeUsage(utilization: 0.9)
        let fallback = FallbackRecorder(result: .success(fallbackUsage))
        let provider = CodexUsageProvider(
            fetchOAuth: { throw CodexOAuthError.unauthorized },
            fetchFallback: { try await fallback.fetch() }
        )

        let usage = try await provider.fetch()
        let count = await fallback.fetchCount()
        XCTAssertEqual(usage, fallbackUsage)
        XCTAssertEqual(count, 1)
    }

    func testFetchDoesNotFallBackForOAuthServerFailure() async {
        let fallback = FallbackRecorder(result: .success(makeUsage(utilization: 0.9)))
        let provider = CodexUsageProvider(
            fetchOAuth: { throw CodexOAuthError.httpStatus(500) },
            fetchFallback: { try await fallback.fetch() }
        )

        do {
            _ = try await provider.fetch()
            XCTFail("Expected OAuth server failure")
        } catch {
            XCTAssertEqual(error as? CodexOAuthError, .httpStatus(500))
        }
        let count = await fallback.fetchCount()
        XCTAssertEqual(count, 0)
    }

    private func makeUsage(utilization: Double) -> ServiceUsage {
        ServiceUsage(
            fiveHour: RateLimit(utilization: utilization, resetsAt: .distantFuture),
            weekly: nil,
            weeklySonnet: nil
        )
    }
}

private actor FallbackRecorder {
    private let result: Result<ServiceUsage, Error>
    private(set) var count = 0

    init(result: Result<ServiceUsage, Error>) {
        self.result = result
    }

    func fetch() throws -> ServiceUsage {
        count += 1
        return try result.get()
    }

    func fetchCount() -> Int {
        count
    }
}
