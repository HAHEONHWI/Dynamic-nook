import Foundation

struct CalendarSourceItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let colorHex: String
}

enum CalendarRange: String, CaseIterable, Identifiable, Sendable {
    case today
    case next24Hours
    case threeDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .next24Hours: "Next 24 Hours"
        case .threeDays: "Next 3 Days"
        }
    }
}
