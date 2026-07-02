@testable import TokenChecker
import XCTest

final class WeeklyWindowSegmentsTests: XCTestCase {
    func testWindowStartHasNoFilledSegments() throws {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let now = reset.addingTimeInterval(-WeeklyWindowSegments.windowLength)

        XCTAssertEqual(
            WeeklyWindowSegments.fillFractions(resetsAt: reset, now: now),
            [0, 0, 0, 0, 0, 0, 0]
        )
    }

    func testRemainingTwoAndHalfDaysPartiallyFillsCurrentDay() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let now = reset.addingTimeInterval(-(2.5 * 24 * 60 * 60))

        let fractions = WeeklyWindowSegments.fillFractions(resetsAt: reset, now: now)

        XCTAssertEqual(fractions.count, 7)
        zip(fractions, [1, 1, 1, 1, 0.5, 0, 0]).forEach { actual, expected in
            XCTAssertEqual(actual, expected, accuracy: 1e-9)
        }
    }

    func testResetTimeAndPastResetFillEverySegment() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertEqual(
            WeeklyWindowSegments.fillFractions(resetsAt: reset, now: reset),
            [1, 1, 1, 1, 1, 1, 1]
        )
        XCTAssertEqual(
            WeeklyWindowSegments.fillFractions(resetsAt: reset, now: reset.addingTimeInterval(1)),
            [1, 1, 1, 1, 1, 1, 1]
        )
    }

    func testResetMoreThanSevenDaysAwayHasNoFilledSegments() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reset = now.addingTimeInterval(8 * 24 * 60 * 60)

        XCTAssertEqual(
            WeeklyWindowSegments.fillFractions(resetsAt: reset, now: now),
            [0, 0, 0, 0, 0, 0, 0]
        )
    }
}
