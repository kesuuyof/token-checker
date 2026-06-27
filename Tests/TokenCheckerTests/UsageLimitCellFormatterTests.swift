@testable import TokenChecker
import XCTest

final class UsageLimitCellFormatterTests: XCTestCase {
    func testJapanesePresentationShowsPercentRemainingAndResetDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))

        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 28,
            hour: 0,
            minute: 8
        )))
        let reset = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 28,
            hour: 2,
            minute: 26
        )))

        let presentation = UsageLimitCellFormatter.presentation(
            for: RateLimit(utilization: 0.42, resetsAt: reset),
            now: now,
            language: .japanese,
            timeZone: calendar.timeZone
        )

        XCTAssertEqual(presentation.percentText, "42%")
        XCTAssertEqual(presentation.remainingText, "残り 2時間18分")
        XCTAssertEqual(presentation.resetText, "6/28(日) 02:26")
    }

    func testEnglishPresentationUsesCompactDateAndLeftLabel() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))

        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 28,
            hour: 0,
            minute: 8
        )))
        let reset = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 3,
            hour: 14,
            minute: 0
        )))

        let presentation = UsageLimitCellFormatter.presentation(
            for: RateLimit(utilization: 0.38, resetsAt: reset),
            now: now,
            language: .english,
            timeZone: calendar.timeZone
        )

        XCTAssertEqual(presentation.percentText, "38%")
        XCTAssertEqual(presentation.remainingText, "5d 13h left")
        XCTAssertEqual(presentation.resetText, "Jul 3, 14:00")
    }
}
