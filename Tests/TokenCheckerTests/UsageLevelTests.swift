@testable import TokenChecker
import XCTest

final class UsageLevelTests: XCTestCase {
    func testLevelThresholdsMatchUsageColorRules() {
        XCTAssertEqual(UsageLevel.level(for: 0), .normal)
        XCTAssertEqual(UsageLevel.level(for: 0.699), .normal)
        XCTAssertEqual(UsageLevel.level(for: 0.7), .warning)
        XCTAssertEqual(UsageLevel.level(for: 0.849), .warning)
        XCTAssertEqual(UsageLevel.level(for: 0.85), .critical)
        XCTAssertEqual(UsageLevel.level(for: 1.2), .critical)
    }
}
