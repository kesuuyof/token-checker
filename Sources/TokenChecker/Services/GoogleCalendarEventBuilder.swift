import Foundation

enum GoogleCalendarEventBuilder {
    static func eventURL(
        serviceName: String,
        resetDate: Date,
        now: Date = Date(),
        language: AppLanguage,
        timeZone: TimeZone = .current
    ) -> URL? {
        let start = resetDate.addingTimeInterval(-12 * 60 * 60)
        guard start > now else { return nil }

        let end = start.addingTimeInterval(30 * 60)
        let resetText = localizedResetText(resetDate, language: language, timeZone: timeZone)
        let title = L10n.format("calendar.reset_reminder.title", language: language, serviceName)
        let details = L10n.format("calendar.reset_reminder.details", language: language, serviceName, resetText)

        var components = URLComponents()
        components.scheme = "https"
        components.host = "calendar.google.com"
        components.path = "/calendar/render"
        components.queryItems = [
            URLQueryItem(name: "action", value: "TEMPLATE"),
            URLQueryItem(name: "text", value: title),
            URLQueryItem(name: "dates", value: "\(calendarDate(start))/\(calendarDate(end))"),
            URLQueryItem(name: "details", value: details),
        ]
        return components.url
    }

    private static func calendarDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private static func localizedResetText(_ date: Date, language: AppLanguage, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
