import AppKit
import Observation
import SwiftUI

enum MediaPresentationTransition: Equatable {
    case none
    case newMedia
    case ended

    static func resolve(previousIdentity: String?, currentIdentity: String?) -> Self {
        switch (previousIdentity, currentIdentity) {
        case (nil, .some):
            .newMedia
        case (.some, nil):
            .ended
        case let (.some(previous), .some(current)) where previous != current:
            .newMedia
        default:
            .none
        }
    }

    static func identity(for media: MediaInfo?) -> String? {
        guard let media else { return nil }
        return [
            media.playerBundleIdentifier ?? media.playerName,
            media.title,
            media.artist
        ].joined(separator: "\u{1F}")
    }
}

@MainActor
final class NookPanelController {
    private let panel: NookPanel
    private let appStore: AppStore
    private let settings: SettingsStore
    private let trayStore: TrayStore
    private let liveActions: LiveActionManager
    private let mediaStore: MediaStore
    private let displayService: DisplayService
    private let sharingService: SharingService
    private let haptics: HapticService
    private let licenseStore: LicenseStore
    private var hoverTask: Task<Void, Never>?
    private var mediaPreviewTask: Task<Void, Never>?
    private var dropExitTask: Task<Void, Never>?
    private var outsideClickGlobalMonitor: Any?
    private var outsideClickLocalMonitor: Any?
    private var pointerGlobalMonitor: Any?
    private var pointerLocalMonitor: Any?
    private var lastGestureDate = Date.distantPast
    private var lastPointerCheckDate = Date.distantPast
    private var lastMediaIdentity: String?
    private var isAutomaticMediaPreview = false
    private var isPointerInsidePanel = false
    private var scrollGesture = NookScrollGestureAccumulator()
    private var currentCollapsedWidth = AppConstants.virtualNotchSize.width
    private var wasLicensed = false

    init(environment: AppEnvironment) {
        panel = NookPanel()
        appStore = environment.appStore
        settings = environment.settings
        trayStore = environment.trayStore
        liveActions = environment.liveActions
        mediaStore = environment.mediaStore
        displayService = environment.displayService
        sharingService = environment.sharingService
        haptics = environment.haptics
        licenseStore = environment.licenseStore
        wasLicensed = licenseStore.isLicensed

        if !licenseStore.isLicensed {
            appStore.nookState = .expanded
        }

        let rootView = NookRootView(
            environment: environment,
            onHover: { [weak self] hovering in self?.handleHover(hovering) },
            onEscape: { [weak self] in self?.collapse() }
        )
        let hostingView = NookDropHostingView(rootView: rootView)
        hostingView.onFileDrag = { [weak self] location in
            self?.handleFileDrag(at: location) ?? []
        }
        hostingView.onFileDrop = { [weak self] urls, location in
            self?.handleFileDrop(urls, at: location) ?? false
        }
        panel.contentView = hostingView
        panel.onScroll = { [weak self] event in
            self?.handleScroll(event) ?? false
        }
        panel.onPrimaryClick = { [weak self] in
            self?.handleClick()
        }
        panel.shouldHandlePrimaryClick = { [weak self] location, panelSize in
            guard let self else { return false }
            return NookPanelInteractionPolicy.shouldToggleForClick(
                state: appStore.nookState,
                location: location,
                panelSize: panelSize,
                notchWidth: currentCollapsedWidth,
                hasInteractiveMediaControls: settings.showMediaIsland &&
                    !appStore.isMediaIslandManuallyHidden &&
                    mediaStore.info != nil,
                isEnabled: settings.clickToOpen
            )
        }
        displayService.onConfigurationChange = { [weak self] in
            self?.updatePanelFrame(animated: false)
        }
        installOutsideClickMonitors()
        installPointerMonitors()
        observeGeometryChanges()
        updatePanelFrame(animated: false)
        panel.orderFrontRegardless()
    }

    func open(widget: WidgetType? = nil) {
        guard licenseStore.isLicensed else {
            appStore.nookState = .expanded
            return
        }
        cancelAutomaticMediaPreview()
        preparePageForOpening()
        appStore.open(widget: widget)
        haptics.perform(enabled: settings.enableHaptics)
    }

    func openTray() {
        guard licenseStore.isLicensed else {
            appStore.nookState = .expanded
            return
        }
        cancelAutomaticMediaPreview()
        appStore.openTray()
        haptics.perform(enabled: settings.enableHaptics)
    }

    func toggle() {
        guard licenseStore.isLicensed else {
            appStore.toggle()
            return
        }
        cancelAutomaticMediaPreview()
        if appStore.nookState == .collapsed || appStore.nookState == .peeking {
            preparePageForOpening()
        }
        appStore.toggle()
        haptics.perform(enabled: settings.enableHaptics)
    }

    func collapse() {
        hoverTask?.cancel()
        cancelAutomaticMediaPreview()
        appStore.collapse()
    }

    func keepMediaControlsOpen() {
        cancelAutomaticMediaPreview()
    }

    func collapseMediaPreview() {
        cancelAutomaticMediaPreview()
        guard appStore.nookState == .peeking else { return }
        appStore.nookState = .collapsed
    }

    func shutdown() {
        hoverTask?.cancel()
        hoverTask = nil
        mediaPreviewTask?.cancel()
        mediaPreviewTask = nil
        dropExitTask?.cancel()
        dropExitTask = nil
        if let outsideClickGlobalMonitor {
            NSEvent.removeMonitor(outsideClickGlobalMonitor)
            self.outsideClickGlobalMonitor = nil
        }
        if let outsideClickLocalMonitor {
            NSEvent.removeMonitor(outsideClickLocalMonitor)
            self.outsideClickLocalMonitor = nil
        }
        if let pointerGlobalMonitor {
            NSEvent.removeMonitor(pointerGlobalMonitor)
            self.pointerGlobalMonitor = nil
        }
        if let pointerLocalMonitor {
            NSEvent.removeMonitor(pointerLocalMonitor)
            self.pointerLocalMonitor = nil
        }
        panel.orderOut(nil)
    }

    private func handleHover(_ hovering: Bool) {
        isPointerInsidePanel = hovering
        hoverTask?.cancel()
        guard settings.hoverToOpen else { return }

        if hovering, appStore.nookState == .collapsed {
            hoverTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(settings.hoverDelay))
                guard !Task.isCancelled else { return }
                appStore.nookState = .peeking
            }
        } else if !hovering,
                  settings.autoClose,
                  appStore.nookState == .peeking,
                  !appStore.isDraggingFile {
            hoverTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(settings.autoCloseDelay))
                guard !Task.isCancelled else { return }
                collapse()
            }
        } else if !hovering, settings.autoClose, appStore.nookState.isFullyExpanded, !appStore.isDraggingFile {
            hoverTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(settings.autoCloseDelay))
                guard !Task.isCancelled else { return }
                collapse()
            }
        }
    }

    private func handleClick() {
        guard settings.clickToOpen else { return }
        hoverTask?.cancel()
        hoverTask = nil
        cancelAutomaticMediaPreview()
        toggle()
    }

    private func preparePageForOpening() {
        appStore.activePage = settings.resolvedOpeningPage
    }

    private func handleScroll(_ event: NSEvent) -> Bool {
        if NookPanelInteractionPolicy.shouldPreserveCalendarDateScroll(
            horizontalDelta: event.scrollingDeltaX,
            verticalDelta: event.scrollingDeltaY,
            isPointerOverCalendarDates: appStore.isPointerOverCalendarDates
        ) {
            scrollGesture.reset()
            return false
        }

        let phase: NookScrollPhase
        if event.phase.contains(.began) {
            phase = .began
        } else if event.phase.contains(.ended) {
            phase = .ended
        } else if event.phase.contains(.cancelled) {
            phase = .cancelled
        } else if event.phase.contains(.changed) {
            phase = .changed
        } else {
            phase = .none
        }

        guard let direction = scrollGesture.process(
            NookScrollSample(
                horizontal: event.scrollingDeltaX,
                vertical: event.scrollingDeltaY,
                isDirectionInverted: event.isDirectionInvertedFromDevice,
                isPrecise: event.hasPreciseScrollingDeltas,
                phase: phase,
                isMomentum: !event.momentumPhase.isEmpty
            )
        ) else { return false }

        guard Date().timeIntervalSince(lastGestureDate) > 0.25 else { return false }

        if let mediaAction = NookPanelInteractionPolicy.compactMediaSwipeAction(
            direction: direction,
            state: appStore.nookState,
            hasMedia: mediaStore.info != nil,
            isMediaHidden: appStore.isMediaIslandManuallyHidden,
            isMediaIslandEnabled: settings.showMediaIsland,
            hasLiveAction: liveActions.currentAction != nil
        ) {
            cancelAutomaticMediaPreview()
            switch mediaAction {
            case .hide:
                appStore.hideMediaIsland()
            case .restore:
                appStore.restoreMediaIsland()
            }
            haptics.perform(enabled: settings.enableHaptics)
            lastGestureDate = Date()
            return true
        }

        let location = event.locationInWindow
        let isInNotchHeader = location.y >= panel.frame.height - 28 &&
            abs(location.x - panel.frame.width / 2) <= currentCollapsedWidth / 2

        switch direction {
        case .down where settings.swipeDownToOpen && (appStore.nookState == .collapsed || appStore.nookState == .peeking):
            hoverTask?.cancel()
            hoverTask = nil
            open()
        case .up where settings.swipeUpToClose && appStore.nookState.isFullyExpanded && isInNotchHeader:
            collapse()
        case .up where appStore.nookState == .peeking &&
                settings.showMediaIsland &&
                !appStore.isMediaIslandManuallyHidden &&
                mediaStore.info != nil:
            collapseMediaPreview()
        case .left where settings.swipeBetweenWidgets && appStore.nookState == .expanded:
            appStore.selectAdjacentWidget(offset: 1, enabled: settings.enabledWidgets)
            haptics.perform(enabled: settings.enableHaptics)
        case .right where settings.swipeBetweenWidgets && appStore.nookState == .expanded:
            appStore.selectAdjacentWidget(offset: -1, enabled: settings.enabledWidgets)
            haptics.perform(enabled: settings.enableHaptics)
        default:
            return false
        }

        lastGestureDate = Date()
        return true
    }

    private func handleDrop(_ urls: [URL]) -> Bool {
        let count = trayStore.add(urls: urls, maximum: settings.maximumTrayItems)
        appStore.fileDropTarget = nil
        guard count > 0 else { return false }
        appStore.openTray()
        liveActions.enqueue(
            LiveAction(
                icon: "tray.and.arrow.down.fill",
                title: "\(count) \(settings.localized(count == 1 ? "file added" : "files added"))"
            )
        )
        haptics.perform(enabled: settings.enableHaptics, pattern: .levelChange)
        return true
    }

    private func handleFileDrag(at location: CGPoint?) -> NSDragOperation {
        dropExitTask?.cancel()

        guard let location else {
            dropExitTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                self?.appStore.fileDropTarget = nil
            }
            return []
        }

        appStore.fileDropTarget = NookFileDropRouting.target(
            locationX: location.x,
            panelWidth: panel.frame.width,
            canAirDrop: settings.enableAirDrop && sharingService.canAirDrop
        )
        hoverTask?.cancel()
        if settings.automaticallySwitchToTray, appStore.nookState != .tray {
            appStore.openTray()
        }
        return .copy
    }

    private func handleFileDrop(_ urls: [URL], at location: CGPoint) -> Bool {
        dropExitTask?.cancel()
        let target = NookFileDropRouting.target(
            locationX: location.x,
            panelWidth: panel.frame.width,
            canAirDrop: settings.enableAirDrop && sharingService.canAirDrop
        )

        if target == .airDrop {
            appStore.fileDropTarget = nil
            liveActions.enqueue(
                LiveAction(
                    icon: "airplayaudio",
                    title: settings.localized("Preparing AirDrop…"),
                    priority: .important
                )
            )
            sharingService.shareViaAirDrop(urls: urls)
            return true
        }

        return handleDrop(urls)
    }

    private func installOutsideClickMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor in self?.closeForOutsideClickIfNeeded() }
        }
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.closeForOutsideClickIfNeeded()
            return event
        }
    }

    private func installPointerMonitors() {
        pointerGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor in self?.updateForPointerDisplayIfNeeded() }
        }
        pointerLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.updateForPointerDisplayIfNeeded()
            return event
        }
    }

    private func updateForPointerDisplayIfNeeded() {
        guard settings.displayPreference == .underPointer,
              Date().timeIntervalSince(lastPointerCheckDate) >= 0.2 else { return }
        lastPointerCheckDate = Date()
        guard let targetID = displayService.targetScreen(preference: .underPointer)?.displayID,
              targetID != appStore.activeDisplayID else { return }
        updatePanelFrame(animated: false)
    }

    private func closeForOutsideClickIfNeeded() {
        guard settings.closeOnOutsideClick,
              appStore.nookState.isOpen,
              !panel.frame.contains(NSEvent.mouseLocation) else { return }
        collapse()
    }

    private func observeGeometryChanges() {
        withObservationTracking {
            _ = appStore.nookState
            _ = appStore.isMediaIslandManuallyHidden
            _ = settings.virtualNotchWidth
            _ = settings.minimumNotchWidth
            _ = settings.maximumNotchWidth
            _ = settings.expandedWidth
            _ = settings.expandedHeight
            _ = settings.displayPreference
            _ = settings.animationSpeed
            _ = settings.shadowEnabled
            _ = settings.showMediaIsland
            _ = settings.showMediaStartPreview
            _ = liveActions.currentAction
            _ = mediaStore.info
            _ = licenseStore.isLicensed
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let isLicensed = self.licenseStore.isLicensed
                if self.wasLicensed, !isLicensed {
                    self.cancelAutomaticMediaPreview()
                    self.appStore.nookState = .expanded
                }
                self.wasLicensed = isLicensed
                self.handleMediaPresentationTransition()
                self.updatePanelFrame(animated: true)
                self.observeGeometryChanges()
            }
        }
    }

    private func handleMediaPresentationTransition() {
        let currentIdentity = settings.showMediaIsland
            ? MediaPresentationTransition.identity(for: mediaStore.info)
            : nil
        let transition = MediaPresentationTransition.resolve(
            previousIdentity: lastMediaIdentity,
            currentIdentity: currentIdentity
        )
        lastMediaIdentity = currentIdentity

        if !settings.showMediaStartPreview, isAutomaticMediaPreview {
            cancelAutomaticMediaPreview()
            if appStore.nookState == .peeking { appStore.collapse() }
        }

        switch transition {
        case .newMedia:
            beginAutomaticMediaPreviewIfNeeded()
        case .ended:
            endMediaPresentation()
        case .none:
            break
        }
    }

    private func beginAutomaticMediaPreviewIfNeeded() {
        guard settings.showMediaStartPreview,
              settings.showMediaIsland,
              !appStore.isMediaIslandManuallyHidden,
              mediaStore.info?.isPlaying == true,
              appStore.nookState == .collapsed,
              liveActions.currentAction == nil else { return }

        mediaPreviewTask?.cancel()
        isAutomaticMediaPreview = true
        appStore.nookState = .peeking
        mediaPreviewTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled, self.isAutomaticMediaPreview else { return }
            self.isAutomaticMediaPreview = false
            self.mediaPreviewTask = nil
            guard !self.isPointerInsidePanel, self.appStore.nookState == .peeking else { return }
            self.appStore.collapse()
        }
    }

    private func endMediaPresentation() {
        mediaPreviewTask?.cancel()
        mediaPreviewTask = nil
        isAutomaticMediaPreview = false
        guard appStore.nookState == .peeking else { return }
        appStore.collapse()
    }

    private func cancelAutomaticMediaPreview() {
        mediaPreviewTask?.cancel()
        mediaPreviewTask = nil
        isAutomaticMediaPreview = false
    }

    private func updatePanelFrame(animated: Bool) {
        guard let screen = displayService.targetScreen(preference: settings.displayPreference) else { return }
        let geometry = displayService.geometry(for: screen, virtualWidth: settings.virtualNotchWidth)
        currentCollapsedWidth = geometry.collapsedSize.width
        let size = NookPanelLayout.size(
            state: appStore.nookState,
            notchSize: geometry.collapsedSize,
            hasPhysicalNotch: geometry.hasPhysicalNotch,
            minimumNotchWidth: settings.minimumNotchWidth,
            maximumNotchWidth: settings.maximumNotchWidth,
            hasLiveAction: liveActions.currentAction != nil,
            hasPlayingMedia: settings.showMediaIsland &&
                !appStore.isMediaIslandManuallyHidden &&
                mediaStore.info != nil,
            preferredMediaWidth: mediaStore.info.map {
                NookPanelLayout.preferredMediaWidth(title: $0.title, artist: $0.artist)
            },
            expandedSize: CGSize(width: settings.expandedWidth, height: settings.expandedHeight),
            screenSize: screen.frame.size
        )
        let targetFrame = PanelPositioner.frame(panelSize: size, screenFrame: screen.frame)
        appStore.activeDisplayID = screen.displayID
        // Keep the expanded Nook visually fused with the notch. NSPanel's
        // system shadow appears as a pale top edge on dark wallpapers.
        panel.hasShadow = false

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard animated, !reduceMotion, panel.frame != .zero else {
            panel.setFrame(targetFrame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NookMotion.duration(speed: settings.animationSpeed)
            context.timingFunction = NookMotion.timingFunction
            panel.animator().setFrame(targetFrame, display: true)
        }
    }
}
