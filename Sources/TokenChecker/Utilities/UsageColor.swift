import SwiftUI

enum UsageLevel: Equatable {
    case normal
    case warning
    case critical

    static func level(for utilization: Double) -> UsageLevel {
        if utilization < 0.7 { return .normal }
        if utilization < 0.85 { return .warning }
        return .critical
    }
}

enum UsageColor {
    static func color(for utilization: Double) -> Color {
        switch UsageLevel.level(for: utilization) {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}
