import CoreGraphics
import Foundation
import Observation

enum FileDropTarget: Equatable, Sendable {
    case tray
    case airDrop
}

@MainActor
@Observable
final class AppStore {
    var nookState: NookState = .collapsed
    var activePage: NookPage = .nook1
    var activeWidget: WidgetType = .media
    var liveAction: LiveAction?
    var fileDropTarget: FileDropTarget?
    var isPointerOverCalendarDates = false
    var isMediaIslandManuallyHidden = false
    var activeDisplayID: CGDirectDisplayID?

    var isExpanded: Bool { nookState.isOpen }
    var isDraggingFile: Bool { fileDropTarget != nil }

    func toggle() {
        switch nookState {
        case .collapsed, .peeking:
            nookState = .expanded
        case .expanded, .tray:
            nookState = .collapsed
        }
    }

    func open(widget: WidgetType? = nil) {
        if let widget { activeWidget = widget }
        nookState = .expanded
    }

    func openTray() {
        nookState = .tray
    }

    func collapse() {
        fileDropTarget = nil
        isPointerOverCalendarDates = false
        nookState = .collapsed
    }

    func hideMediaIsland() {
        isMediaIslandManuallyHidden = true
        if nookState == .peeking {
            nookState = .collapsed
        }
    }

    func restoreMediaIsland() {
        isMediaIslandManuallyHidden = false
    }

    func selectPage(_ page: NookPage) {
        activePage = page
        nookState = .expanded
    }

    func selectAdjacentWidget(offset: Int, enabled: [WidgetType]) {
        guard !enabled.isEmpty else { return }
        guard let index = enabled.firstIndex(of: activeWidget) else {
            activeWidget = enabled[0]
            nookState = .expanded
            return
        }
        activeWidget = enabled[(index + offset + enabled.count) % enabled.count]
        nookState = .expanded
    }
}
