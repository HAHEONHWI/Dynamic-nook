import Foundation

enum LiveActionPriority: Int, Comparable, Sendable {
    case normal = 0
    case important = 1
    case critical = 2

    static func < (lhs: LiveActionPriority, rhs: LiveActionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct LiveAction: Identifiable, Equatable, Sendable {
    let id: UUID
    let icon: String
    let title: String
    let message: String?
    let duration: TimeInterval
    let priority: LiveActionPriority

    init(
        id: UUID = UUID(),
        icon: String,
        title: String,
        message: String? = nil,
        duration: TimeInterval = 2.2,
        priority: LiveActionPriority = .normal
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.message = message
        self.duration = duration
        self.priority = priority
    }
}
