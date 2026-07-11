@testable import TokenChecker
import XCTest

final class WindowSegmentsTests: XCTestCase {
    func testFiveHourWindowStartHasNoFilledSegments() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let now = reset.addingTimeInterval(-(5 * 60 * 60))

        XCTAssertEqual(
            WindowSegments.fiveHourFillFractions(resetsAt: reset, now: now),
            [0, 0, 0, 0, 0]
        )
    }

    func testFiveHourWindowPartiallyFillsCurrentHour() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let now = reset.addingTimeInterval(-(2.5 * 60 * 60))

        let fractions = WindowSegments.fiveHourFillFractions(resetsAt: reset, now: now)

        XCTAssertEqual(fractions.count, 5)
        zip(fractions, [1, 1, 0.5, 0, 0]).forEach { actual, expected in
            XCTAssertEqual(actual, expected, accuracy: 1e-9)
        }
    }

    func testFiveHourResetTimeAndPastResetFillEverySegment() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertEqual(
            WindowSegments.fiveHourFillFractions(resetsAt: reset, now: reset),
            [1, 1, 1, 1, 1]
        )
        XCTAssertEqual(
            WindowSegments.fiveHourFillFractions(resetsAt: reset, now: reset.addingTimeInterval(1)),
            [1, 1, 1, 1, 1]
        )
    }

    func testResetMoreThanFiveHoursAwayHasNoFilledSegments() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reset = now.addingTimeInterval(6 * 60 * 60)

        XCTAssertEqual(
            WindowSegments.fiveHourFillFractions(resetsAt: reset, now: now),
            [0, 0, 0, 0, 0]
        )
    }

    func testWeeklyWindowStartHasNoFilledSegments() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let now = reset.addingTimeInterval(-(7 * 24 * 60 * 60))

        XCTAssertEqual(
            WindowSegments.weeklyFillFractions(resetsAt: reset, now: now),
            [0, 0, 0, 0, 0, 0, 0]
        )
    }

    func testWeeklyWindowPartiallyFillsCurrentDay() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let now = reset.addingTimeInterval(-(2.5 * 24 * 60 * 60))

        let fractions = WindowSegments.weeklyFillFractions(resetsAt: reset, now: now)

        XCTAssertEqual(fractions.count, 7)
        zip(fractions, [1, 1, 1, 1, 0.5, 0, 0]).forEach { actual, expected in
            XCTAssertEqual(actual, expected, accuracy: 1e-9)
        }
    }

    func testWeeklyResetTimeAndPastResetFillEverySegment() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertEqual(
            WindowSegments.weeklyFillFractions(resetsAt: reset, now: reset),
            [1, 1, 1, 1, 1, 1, 1]
        )
        XCTAssertEqual(
            WindowSegments.weeklyFillFractions(resetsAt: reset, now: reset.addingTimeInterval(1)),
            [1, 1, 1, 1, 1, 1, 1]
        )
    }

    func testResetMoreThanSevenDaysAwayHasNoFilledSegments() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reset = now.addingTimeInterval(8 * 24 * 60 * 60)

        XCTAssertEqual(
            WindowSegments.weeklyFillFractions(resetsAt: reset, now: now),
            [0, 0, 0, 0, 0, 0, 0]
        )
    }
}
