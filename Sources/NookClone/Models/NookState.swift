enum NookState: String, CaseIterable, Sendable {
    case collapsed
    case peeking
    case expanded
    case tray

    var isOpen: Bool { self != .collapsed }
    var isFullyExpanded: Bool { self == .expanded || self == .tray }
}
