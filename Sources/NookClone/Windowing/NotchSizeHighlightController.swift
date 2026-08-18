import AppKit
import SwiftUI

enum NotchSizeHighlightKind: Equatable {
    case virtual
    case mediaMinimum
    case mediaMaximum
    case expandedWidth
    case expandedHeight
    case cornerRadius
}

struct NotchSizeHighlightGeometry: Equatable {
    let frame: CGRect
    let cornerRadius: CGFloat

    struct Values: Equatable, Sendable {
        let virtualWidth: CGFloat
        let minimumWidth: CGFloat
        let maximumWidth: CGFloat
        let expandedWidth: CGFloat
        let expandedHeight: CGFloat
        let cornerRadius: CGFloat
    }

    static func calculate(
        kind: NotchSizeHighlightKind,
        values: Values,
        screenFrame: CGRect,
        collapsedHeight: CGFloat
    ) -> Self {
        let maximumWidth = max(80, screenFrame.width - 24)
        let maximumHeight = max(40, screenFrame.height - 48)
        let width: CGFloat
        let height: CGFloat

        switch kind {
        case .virtual:
            width = values.virtualWidth
            height = max(collapsedHeight, 42)
        case .mediaMinimum:
            width = values.minimumWidth
            height = max(collapsedHeight, 48)
        case .mediaMaximum:
            width = values.maximumWidth
            height = max(collapsedHeight, 54)
        case .expandedWidth, .expandedHeight, .cornerRadius:
            width = values.expandedWidth
            height = values.expandedHeight
        }

        let size = CGSize(
            width: min(max(width, 80), maximumWidth),
            height: min(max(height, 40), maximumHeight)
        )
        return Self(
            frame: PanelPositioner.frame(panelSize: size, screenFrame: screenFrame),
            cornerRadius: kind == .cornerRadius || kind == .expandedWidth || kind == .expandedHeight
                ? values.cornerRadius
                : min(values.cornerRadius, 18)
        )
    }
}

@MainActor
final class NotchSizeHighlightController {
    private let panel: NSPanel
    private var hideTask: Task<Void, Never>?
    private var presentationID = 0

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
    }

    func show(
        kind: NotchSizeHighlightKind,
        title: String,
        settings: SettingsStore,
        displayService: DisplayService
    ) {
        guard let screen = displayService.targetScreen(preference: settings.displayPreference) else { return }
        let collapsedHeight = displayService.geometry(
            for: screen,
            virtualWidth: settings.virtualNotchWidth
        ).collapsedSize.height
        let geometry = NotchSizeHighlightGeometry.calculate(
            kind: kind,
            values: .init(
                virtualWidth: settings.virtualNotchWidth,
                minimumWidth: settings.minimumNotchWidth,
                maximumWidth: settings.maximumNotchWidth,
                expandedWidth: settings.expandedWidth,
                expandedHeight: settings.expandedHeight,
                cornerRadius: settings.cornerRadius
            ),
            screenFrame: screen.frame,
            collapsedHeight: collapsedHeight
        )
        let value = displayedValue(for: kind, settings: settings)

        hideTask?.cancel()
        presentationID += 1
        panel.contentView = NSHostingView(
            rootView: NotchSizeHighlightView(
                title: title,
                value: value,
                cornerRadius: geometry.cornerRadius
            )
        )
        panel.setFrame(geometry.frame, display: true)
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                panel.animator().alphaValue = 1
            }
        } else {
            panel.orderFrontRegardless()
        }
        scheduleHide(after: .seconds(1.2))
    }

    func hide(after delay: Duration = .milliseconds(180)) {
        scheduleHide(after: delay)
    }

    private func scheduleHide(after delay: Duration) {
        hideTask?.cancel()
        let expectedPresentationID = presentationID
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled,
                  let self,
                  expectedPresentationID == presentationID else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                panel.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self, expectedPresentationID == self.presentationID else { return }
                    self.panel.orderOut(nil)
                }
            }
        }
    }

    private func displayedValue(for kind: NotchSizeHighlightKind, settings: SettingsStore) -> String {
        let value = switch kind {
        case .virtual: settings.virtualNotchWidth
        case .mediaMinimum: settings.minimumNotchWidth
        case .mediaMaximum: settings.maximumNotchWidth
        case .expandedWidth: settings.expandedWidth
        case .expandedHeight: settings.expandedHeight
        case .cornerRadius: settings.cornerRadius
        }
        return "\(Int(value.rounded())) pt"
    }
}

private struct NotchSizeHighlightView: View {
    let title: String
    let value: String
    let cornerRadius: CGFloat

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(Color.accentColor.opacity(0.3))
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: cornerRadius,
                bottomTrailingRadius: cornerRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
            .stroke(Color.cyan.opacity(0.95), lineWidth: 2)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.left.and.right")
                Text(title).lineLimit(1)
                Text(value).monospacedDigit().fontWeight(.bold)
            }
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.black.opacity(0.72), in: Capsule())
            .padding(.bottom, 6)
        }
        .shadow(color: .cyan.opacity(0.55), radius: 10)
        .padding(.horizontal, 1)
        .padding(.bottom, 1)
    }
}
