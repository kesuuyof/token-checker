@testable import TokenChecker
import XCTest

final class CodexOAuthUsageClientTests: XCTestCase {
    func testFetchSendsOAuthHeadersAndMapsBothWindows() async throws {
        let recorder = RequestRecorder()
        let client = CodexOAuthUsageClient { request in
            await recorder.record(request)
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (
                Data(
                    #"{"rate_limit":{"primary_window":{"used_percent":25,"reset_at":1800000000,"limit_window_seconds":18000},"secondary_window":{"used_percent":50,"reset_at":1800600000,"limit_window_seconds":604800}}}"#.utf8
                ),
                response
            )
        }

        let usage = try await client.fetch(
            credentials: CodexOAuthCredentials(
                accessToken: "access", refreshToken: "refresh", accountId: "acct_123", lastRefresh: nil
            )
        )

        let request = await recorder.request
        XCTAssertEqual(request?.url?.absoluteString, "https://chatgpt.com/backend-api/wham/usage")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer access")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "acct_123")
        XCTAssertEqual(usage.fiveHour?.utilization, 0.25)
        XCTAssertEqual(usage.weekly?.utilization, 0.5)
        XCTAssertEqual(usage.fiveHour?.resetsAt.timeIntervalSince1970, 1_800_000_000)
    }

    func testFetchMapsPrimaryWeeklyWindowAndLeavesFiveHourNilWhenFiveHourIsOmitted() async throws {
        let client = CodexOAuthUsageClient { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (
                Data(
                    #"{"rate_limit":{"primary_window":{"used_percent":6,"reset_at":1800000000,"limit_window_seconds":604800},"secondary_window":null}}"#.utf8
                ),
                response
            )
        }

        let usage = try await client.fetch(
            credentials: CodexOAuthCredentials(
                accessToken: "access", refreshToken: "refresh", accountId: nil, lastRefresh: nil
            )
        )

        XCTAssertNil(usage.fiveHour)
        XCTAssertEqual(usage.weekly?.utilization, 0.06)
        XCTAssertEqual(usage.weekly?.resetsAt.timeIntervalSince1970, 1_800_000_000)
    }

    func testFetchIgnoresWindowsWithUnsupportedDuration() async throws {
        let client = CodexOAuthUsageClient { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (
                Data(
                    #"{"rate_limit":{"primary_window":{"used_percent":50,"reset_at":1800000000,"limit_window_seconds":3600},"secondary_window":null}}"#.utf8
                ),
                response
            )
        }

        let usage = try await client.fetch(
            credentials: CodexOAuthCredentials(
                accessToken: "access", refreshToken: "refresh", accountId: nil, lastRefresh: nil
            )
        )

        XCTAssertNil(usage.fiveHour)
        XCTAssertNil(usage.weekly)
    }
}

private actor RequestRecorder {
    private(set) var request: URLRequest?

    func record(_ request: URLRequest) {
        self.request = request
    }
}
