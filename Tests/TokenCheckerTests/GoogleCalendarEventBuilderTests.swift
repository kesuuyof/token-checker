@testable import TokenChecker
import XCTest

final class GoogleCalendarEventBuilderTests: XCTestCase {
    func testEventStartsTwelveHoursBeforeResetAndEndsThirtyMinutesLater() throws {
        let reset = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-30T00:00:00Z"))

        let url = try XCTUnwrap(GoogleCalendarEventBuilder.eventURL(
            serviceName: "Claude Code",
            resetDate: reset,
            now: now,
            language: .english,
            timeZone: TimeZone(secondsFromGMT: 0)!
        ))

        let items = try queryItems(from: url)
        XCTAssertEqual(items["dates"], "20260701T000000Z/20260701T003000Z")
    }

    func testEventTitleAndDetailsAreEncoded() throws {
        let reset = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-30T00:00:00Z"))

        let url = try XCTUnwrap(GoogleCalendarEventBuilder.eventURL(
            serviceName: "Claude Code",
            resetDate: reset,
            now: now,
            language: .english,
            timeZone: TimeZone(secondsFromGMT: 0)!
        ))

        let items = try queryItems(from: url)
        XCTAssertEqual(items["action"], "TEMPLATE")
        XCTAssertEqual(items["text"], "Claude Code weekly reset reminder")
        XCTAssertEqual(
            items["details"]?.normalizedSpaces(),
            "Claude Code weekly reset: Jul 1, 2026 at 12:00 PM"
        )
    }

    func testPastReminderReturnsNil() throws {
        let reset = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-01T00:00:01Z"))

        XCTAssertNil(GoogleCalendarEventBuilder.eventURL(
            serviceName: "Codex",
            resetDate: reset,
            now: now,
            language: .english,
            timeZone: TimeZone(secondsFromGMT: 0)!
        ))
    }

    private func queryItems(from url: URL) throws -> [String: String] {
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = try XCTUnwrap(components.queryItems)
        return Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }
}

private extension String {
    func normalizedSpaces() -> String {
        replacingOccurrences(of: "\u{202F}", with: " ")
    }
}
