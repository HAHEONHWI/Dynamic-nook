import Foundation

public enum LicenseExpiration {
    public static func endOfDayTimestamp(
        for date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Int64 {
        let startToday = calendar.startOfDay(for: now)
        let selectedDay = calendar.startOfDay(for: date)
        guard selectedDay >= startToday,
              let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDay) else {
            throw LicenseValidationError.invalidExpirationDate
        }
        return Int64(nextDay.addingTimeInterval(-1).timeIntervalSince1970)
    }
}
