import Foundation

enum WeeklyWindowSegments {
    static let segmentCount = 7
    static let windowLength: TimeInterval = 7 * 24 * 60 * 60

    static func fillFractions(resetsAt: Date, now: Date = Date()) -> [Double] {
        let windowStart = resetsAt.addingTimeInterval(-windowLength)
        let elapsedDays = clamp(now.timeIntervalSince(windowStart) / (24 * 60 * 60), min: 0, max: 7)

        return (0..<segmentCount).map { index in
            clamp(elapsedDays - Double(index), min: 0, max: 1)
        }
    }

    private static func clamp(_ value: Double, min lowerBound: Double, max upperBound: Double) -> Double {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
