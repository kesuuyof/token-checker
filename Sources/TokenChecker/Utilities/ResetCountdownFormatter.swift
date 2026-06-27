import Foundation

enum ResetCountdownFormatter {
    static func label(
        until date: Date,
        now: Date = Date(),
        language: AppLanguage,
        timeZone: TimeZone = .current
    ) -> String {
        if date <= now { return L10n.tr("reset.soon", language: language) }

        var calendar = Calendar.current
        calendar.locale = language.locale
        calendar.timeZone = timeZone

        let relative = relativeText(from: now, to: date, calendar: calendar)

        let absoluteFormatter = DateFormatter()
        absoluteFormatter.locale = language.locale
        absoluteFormatter.timeZone = timeZone
        absoluteFormatter.dateStyle = .none
        absoluteFormatter.timeStyle = .short
        let absolute = absoluteFormatter.string(from: date).replacingOccurrences(of: "\u{202f}", with: " ")

        return L10n.format("reset.remaining", language: language, relative, absolute)
    }

    private static func relativeText(from now: Date, to date: Date, calendar: Calendar) -> String {
        let raw = calendar.dateComponents([.day, .hour, .minute], from: now, to: date)
        var display = DateComponents()

        if let days = raw.day, days > 0 {
            display.day = days
            if let hours = raw.hour, hours > 0 {
                display.hour = hours
            }
        } else if let hours = raw.hour, hours > 0 {
            display.hour = hours
            if let minutes = raw.minute, minutes > 0 {
                display.minute = minutes
            }
        } else {
            display.minute = max(raw.minute ?? 0, 1)
        }

        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: display) ?? "-"
    }
}
