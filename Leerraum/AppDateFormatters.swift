import Foundation

enum AppDateFormatters {
    static let esMXLongWeekdayDayMonth: DateFormatter = makeFormatter("EEEE d MMMM")
    static let esMXShortDate: DateFormatter = makeFormatter("EEE d MMM yyyy")
    static let esMXTime12h: DateFormatter = makeFormatter("h:mm a")

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = format
        return formatter
    }
}
