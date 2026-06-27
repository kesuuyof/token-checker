import Foundation

struct UsageLimitCellPresentation: Equatable {
    let percentText: String
    let remainingText: String
    let resetText: String
}

enum UsageLimitCellFormatter {
    static func presentation(
        for limit: RateLimit,
        now: Date = Date(),
        language: AppLanguage,
        timeZone: TimeZone = .current
    ) -> UsageLimitCellPresentation {
        UsageLimitCellPresentation(
            percentText: "\(limit.percent)%",
            remainingText: remainingText(until: limit.resetsAt, now: now, language: language, timeZone: timeZone),
            resetText: resetText(for: limit.resetsAt, language: language, timeZone: timeZone)
        )
    }

    private static func remainingText(
        until date: Date,
        now: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> String {
        if date <= now { return L10n.tr("reset.soon", language: language) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = language.locale
        calendar.timeZone = timeZone

        let raw = calendar.dateComponents([.day, .hour, .minute], from: now, to: date)
        let relative = compactRelativeText(from: raw, language: language)
        return L10n.format("usage.remaining.compact", language: language, relative)
    }

    private static func compactRelativeText(from raw: DateComponents, language: AppLanguage) -> String {
        let days = max(raw.day ?? 0, 0)
        let hours = max(raw.hour ?? 0, 0)
        let minutes = max(raw.minute ?? 0, 0)

        if days > 0 {
            if hours > 0 {
                return format(days: days, hours: hours, language: language)
            }
            return format(days: days, language: language)
        }

        if hours > 0 {
            if minutes > 0 {
                return format(hours: hours, minutes: minutes, language: language)
            }
            return format(hours: hours, language: language)
        }

        return format(minutes: max(minutes, 1), language: language)
    }

    private static func resetText(for date: Date, language: AppLanguage, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = timeZone
        formatter.dateFormat = resetDateFormat(for: language)
        return formatter.string(from: date).replacingOccurrences(of: "\u{202f}", with: " ")
    }

    private static func resetDateFormat(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "MMM d, HH:mm"
        case .japanese, .simplifiedChinese:
            return "M/d(E) HH:mm"
        }
    }

    private static func format(days: Int, hours: Int, language: AppLanguage) -> String {
        switch language {
        case .english:
            return "\(days)d \(hours)h"
        case .japanese:
            return "\(days)日\(hours)時間"
        case .simplifiedChinese:
            return "\(days)天\(hours)小时"
        }
    }

    private static func format(days: Int, language: AppLanguage) -> String {
        switch language {
        case .english:
            return "\(days)d"
        case .japanese:
            return "\(days)日"
        case .simplifiedChinese:
            return "\(days)天"
        }
    }

    private static func format(hours: Int, minutes: Int, language: AppLanguage) -> String {
        switch language {
        case .english:
            return "\(hours)h \(minutes)m"
        case .japanese:
            return "\(hours)時間\(minutes)分"
        case .simplifiedChinese:
            return "\(hours)小时\(minutes)分钟"
        }
    }

    private static func format(hours: Int, language: AppLanguage) -> String {
        switch language {
        case .english:
            return "\(hours)h"
        case .japanese:
            return "\(hours)時間"
        case .simplifiedChinese:
            return "\(hours)小时"
        }
    }

    private static func format(minutes: Int, language: AppLanguage) -> String {
        switch language {
        case .english:
            return "\(minutes)m"
        case .japanese:
            return "\(minutes)分"
        case .simplifiedChinese:
            return "\(minutes)分钟"
        }
    }
}
