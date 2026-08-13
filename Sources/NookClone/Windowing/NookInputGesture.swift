import CoreGraphics

enum NookFileDropRouting {
    static func target(locationX: CGFloat, panelWidth: CGFloat, canAirDrop: Bool) -> FileDropTarget {
        guard canAirDrop, panelWidth > 0, locationX > panelWidth / 2 else { return .tray }
        return .airDrop
    }
}

enum NookScrollPhase: Sendable {
    case began
    case changed
    case ended
    case cancelled
    case none
}

struct NookScrollSample: Sendable {
    let horizontal: CGFloat
    let vertical: CGFloat
    let isDirectionInverted: Bool
    let isPrecise: Bool
    let phase: NookScrollPhase
    let isMomentum: Bool
}

enum NookGestureDirection: Equatable, Sendable {
    case up
    case down
    case left
    case right
}

enum CompactMediaSwipeAction: Equatable, Sendable {
    case hide
    case restore
}

struct NookScrollGestureAccumulator: Sendable {
    private(set) var horizontalTotal: CGFloat = 0
    private(set) var verticalTotal: CGFloat = 0
    private var didTrigger = false
    let threshold: CGFloat

    init(threshold: CGFloat = 32) {
        self.threshold = threshold
    }

    mutating func process(_ sample: NookScrollSample) -> NookGestureDirection? {
        if sample.phase == .began {
            reset()
        }

        if sample.phase == .ended || sample.phase == .cancelled {
            reset()
            return nil
        }

        guard sample.isPrecise, !sample.isMomentum, !didTrigger else { return nil }

        // NSEvent deltas already follow Natural Scrolling. Undo that inversion so
        // physical two-finger direction stays stable across user preferences.
        let directionMultiplier: CGFloat = sample.isDirectionInverted ? -1 : 1
        horizontalTotal += sample.horizontal * directionMultiplier
        verticalTotal += sample.vertical * directionMultiplier

        let horizontalMagnitude = abs(horizontalTotal)
        let verticalMagnitude = abs(verticalTotal)
        guard max(horizontalMagnitude, verticalMagnitude) >= threshold else { return nil }

        let direction: NookGestureDirection
        if verticalMagnitude > horizontalMagnitude * 1.15 {
            direction = verticalTotal < 0 ? .down : .up
        } else if horizontalMagnitude > verticalMagnitude * 1.15 {
            direction = horizontalTotal < 0 ? .left : .right
        } else {
            return nil
        }

        didTrigger = true
        return direction
    }

    mutating func reset() {
        horizontalTotal = 0
        verticalTotal = 0
        didTrigger = false
    }
}

enum NookPanelInteractionPolicy {
    static func compactMediaSwipeAction(
        direction: NookGestureDirection,
        state: NookState,
        hasMedia: Bool,
        isMediaHidden: Bool,
        isMediaIslandEnabled: Bool,
        hasLiveAction: Bool
    ) -> CompactMediaSwipeAction? {
        guard state == .collapsed || state == .peeking,
              hasMedia,
              isMediaIslandEnabled,
              !hasLiveAction else { return nil }

        switch (direction, isMediaHidden) {
        case (.left, false): return .hide
        case (.right, true): return .restore
        default: return nil
        }
    }

    static func shouldPreserveCalendarDateScroll(
        horizontalDelta: CGFloat,
        verticalDelta: CGFloat,
        isPointerOverCalendarDates: Bool
    ) -> Bool {
        isPointerOverCalendarDates && (horizontalDelta != 0 || verticalDelta != 0)
    }

    static func shouldToggleForClick(
        state: NookState,
        location: CGPoint,
        panelSize: CGSize,
        notchWidth: CGFloat,
        headerHeight: CGFloat = 24,
        hasInteractiveMediaControls: Bool = false,
        isEnabled: Bool
    ) -> Bool {
        guard isEnabled else { return false }

        switch state {
        case .collapsed:
            return true
        case .peeking:
            if !hasInteractiveMediaControls { return true }
            let hitWidth = min(notchWidth, panelSize.width)
            let isInsideHeader = location.y >= panelSize.height - headerHeight
            let isInsideNotchWidth = abs(location.x - panelSize.width / 2) <= hitWidth / 2
            return isInsideHeader && isInsideNotchWidth
        case .expanded, .tray:
            let hitWidth = min(notchWidth, panelSize.width)
            let isInsideHeader = location.y >= panelSize.height - headerHeight
            let isInsideNotchWidth = abs(location.x - panelSize.width / 2) <= hitWidth / 2
            return isInsideHeader && isInsideNotchWidth
        }
    }
}
