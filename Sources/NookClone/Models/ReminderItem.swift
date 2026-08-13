import Foundation

struct ReminderItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let dueDate: Date
    let listTitle: String
    let isOverdue: Bool
}

struct ReminderListItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let colorHex: String
}

enum ReminderDateLogic {
    static func displayWindow(now: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: .distantPast, end: end)
    }

    static func sort(_ items: [ReminderItem]) -> [ReminderItem] {
        items.sorted {
            if $0.isOverdue != $1.isOverdue { return $0.isOverdue && !$1.isOverdue }
            if $0.dueDate != $1.dueDate { return $0.dueDate < $1.dueDate }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
}
