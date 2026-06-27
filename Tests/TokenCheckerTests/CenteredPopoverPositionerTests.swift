@testable import TokenChecker
import XCTest

final class CenteredPopoverPositionerTests: XCTestCase {
    func testCentersPopoverOnAnchorWhenItFitsVisibleFrame() {
        let current = CGRect(x: 0, y: 500, width: 500, height: 360)
        let anchor = CGRect(x: 700, y: 880, width: 60, height: 24)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let positioned = CenteredPopoverPositioner.positionedFrame(
            currentFrame: current,
            anchorFrame: anchor,
            visibleFrame: visible
        )

        XCTAssertEqual(positioned.midX, anchor.midX, accuracy: 0.001)
        XCTAssertEqual(positioned.origin.y, current.origin.y, accuracy: 0.001)
        XCTAssertEqual(positioned.size, current.size)
    }

    func testClampsPopoverToVisibleFrameWhenCenteredPositionWouldOverflow() {
        let current = CGRect(x: 0, y: 500, width: 500, height: 360)
        let anchor = CGRect(x: 1320, y: 880, width: 60, height: 24)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let positioned = CenteredPopoverPositioner.positionedFrame(
            currentFrame: current,
            anchorFrame: anchor,
            visibleFrame: visible
        )

        XCTAssertEqual(positioned.maxX, visible.maxX, accuracy: 0.001)
        XCTAssertEqual(positioned.origin.y, current.origin.y, accuracy: 0.001)
        XCTAssertEqual(positioned.size, current.size)
    }

    func testClampsPopoverBelowVisibleFrameTopWhenItWouldOverlapMenuBar() {
        let current = CGRect(x: 470, y: 610, width: 500, height: 320)
        let anchor = CGRect(x: 700, y: 880, width: 60, height: 24)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

        let positioned = CenteredPopoverPositioner.positionedFrame(
            currentFrame: current,
            anchorFrame: anchor,
            visibleFrame: visible
        )

        XCTAssertLessThanOrEqual(positioned.maxY, visible.maxY)
        XCTAssertEqual(positioned.origin.y, 555, accuracy: 0.001)
        XCTAssertEqual(positioned.size, current.size)
    }
}
