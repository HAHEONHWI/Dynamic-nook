import Foundation

struct CalendarEventItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let colorHex: String
}
