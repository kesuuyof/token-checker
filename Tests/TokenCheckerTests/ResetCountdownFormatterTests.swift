@testable import TokenChecker
import XCTest

final class ResetCountdownFormatterTests: XCTestCase {
    func testWeeklyResetUsesDaysAndHours() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reset = now.addingTimeInterval((6 * 24 * 60 * 60) + (23 * 60 * 60) + (30 * 60))

        let label = ResetCountdownFormatter.label(
            until: reset,
            now: now,
            language: .english,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(label, "6d 23h remaining (7:30 AM reset)")
    }

    func testPastResetUsesSoonLabel() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let label = ResetCountdownFormatter.label(
            until: now.addingTimeInterval(-1),
            now: now,
            language: .english,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(label, "Reset soon")
    }
}
