import AppKit

@MainActor
final class NookPanel: NSPanel {
    var onScroll: ((NSEvent) -> Bool)?
    var onPrimaryClick: (() -> Void)?
    var shouldHandlePrimaryClick: ((CGPoint, CGSize) -> Bool)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isMovableByWindowBackground = false
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .none
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown,
           shouldHandlePrimaryClick?(event.locationInWindow, frame.size) == true {
            onPrimaryClick?()
            return
        }
        super.sendEvent(event)
    }

    override func scrollWheel(with event: NSEvent) {
        if onScroll?(event) == true { return }
        super.scrollWheel(with: event)
    }
}
