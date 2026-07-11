import Foundation

enum WindowSegments {
    private static let hour: TimeInterval = 60 * 60
    private static let day: TimeInterval = 24 * hour
    static let weeklySegmentCount = 7

    static func fiveHourFillFractions(resetsAt: Date, now: Date = Date()) -> [Double] {
        fillFractions(
            segmentCount: 5,
            segmentDuration: hour,
            resetsAt: resetsAt,
            now: now
        )
    }

    static func weeklyFillFractions(resetsAt: Date, now: Date = Date()) -> [Double] {
        fillFractions(
            segmentCount: weeklySegmentCount,
            segmentDuration: day,
            resetsAt: resetsAt,
            now: now
        )
    }

    private static func fillFractions(
        segmentCount: Int,
        segmentDuration: TimeInterval,
        resetsAt: Date,
        now: Date
    ) -> [Double] {
        let windowLength = Double(segmentCount) * segmentDuration
        let windowStart = resetsAt.addingTimeInterval(-windowLength)
        let elapsedSegments = clamp(
            now.timeIntervalSince(windowStart) / segmentDuration,
            min: 0,
            max: Double(segmentCount)
        )

        return (0..<segmentCount).map { index in
            clamp(elapsedSegments - Double(index), min: 0, max: 1)
        }
    }

    private static func clamp(
        _ value: Double,
        min lowerBound: Double,
        max upperBound: Double
    ) -> Double {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
