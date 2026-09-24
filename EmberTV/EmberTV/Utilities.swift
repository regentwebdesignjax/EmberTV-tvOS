import Foundation

extension Date {
    func formattedForEmber() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

/// A screening's "YYYY-MM-DD" date shown as e.g. "Sep 26, 2026".
/// Read in UTC so the calendar day never shifts with the TV's time zone.
func formattedScreeningDate(_ ymd: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = TimeZone(identifier: "UTC")
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: ymd) else { return ymd }
    let out = DateFormatter()
    out.timeZone = TimeZone(identifier: "UTC")
    out.dateStyle = .medium
    out.timeStyle = .none
    return out.string(from: date)
}
