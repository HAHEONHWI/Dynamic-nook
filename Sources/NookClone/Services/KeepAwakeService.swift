import Foundation
import AppKit
import CoreGraphics
import IOKit.pwr_mgt
import Observation

@MainActor
@Observable
final class KeepAwakeService {
    private(set) var isActive = false
    private(set) var endDate: Date?
    private(set) var errorMessage: String?
    private(set) var allowDisplaySleep = true
    private(set) var allowClosedDisplaySleep = false
    private(set) var screenSaverMinutes = 0
    private var sessionMinutes: Int?
    private var screenSaverLaunched = false
    private let closedDisplayBridge = ClosedDisplaySleepBridge()
    private(set) var closedDisplayProtectionActive = false
    @ObservationIgnored private var systemAssertion: IOPMAssertionID = 0
    @ObservationIgnored private var displayAssertion: IOPMAssertionID = 0
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(startTicker: Bool = true) {
        if startTicker {
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    self?.refresh()
                }
            }
        }
    }

    deinit {
        ticker?.cancel()
        if systemAssertion != 0 { IOPMAssertionRelease(systemAssertion) }
        if displayAssertion != 0 { IOPMAssertionRelease(displayAssertion) }
    }

    func start(
        minutes: Int?,
        allowDisplaySleep: Bool = true,
        allowClosedDisplaySleep: Bool = false,
        screenSaverMinutes: Int = 0,
        now: Date = .now
    ) {
        stop()
        self.sessionMinutes = minutes
        self.allowDisplaySleep = allowDisplaySleep
        self.allowClosedDisplaySleep = allowClosedDisplaySleep
        self.screenSaverMinutes = max(0, screenSaverMinutes)
        screenSaverLaunched = false
        closedDisplayProtectionActive = !allowClosedDisplaySleep && closedDisplayBridge.enable()
        let reason = "Dynamic Nook Keep Awake" as CFString
        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &systemAssertion
        )
        let displayResult: IOReturn = allowDisplaySleep
            ? kIOReturnSuccess
            : IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &displayAssertion
            )
        guard systemResult == kIOReturnSuccess, displayResult == kIOReturnSuccess,
              systemAssertion != 0 else {
            releaseAssertions()
            closedDisplayBridge.disable()
            closedDisplayProtectionActive = false
            errorMessage = "The sleep prevention request failed."
            return
        }
        endDate = minutes.map { now.addingTimeInterval(TimeInterval(max(1, $0) * 60)) }
        errorMessage = nil
        isActive = true
        if !allowClosedDisplaySleep, !closedDisplayProtectionActive {
            errorMessage = "Administrator permission is required to prevent closed-display sleep."
        }
    }

    func stop() {
        releaseAssertions()
        closedDisplayBridge.disable()
        closedDisplayProtectionActive = false
        endDate = nil
        isActive = false
    }

    func refresh(now: Date = .now) {
        if let endDate, now >= endDate { stop() }
        guard isActive, screenSaverMinutes > 0 else { return }
        let anyEvent = CGEventType(rawValue: UInt32.max) ?? .null
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
        if idle >= Double(screenSaverMinutes * 60), !screenSaverLaunched {
            let url = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
            screenSaverLaunched = true
        } else if idle < 5 {
            screenSaverLaunched = false
        }
    }

    func updateConfiguration(allowDisplaySleep: Bool, allowClosedDisplaySleep: Bool, screenSaverMinutes: Int) {
        guard isActive else {
            self.allowDisplaySleep = allowDisplaySleep
            self.allowClosedDisplaySleep = allowClosedDisplaySleep
            self.screenSaverMinutes = screenSaverMinutes
            return
        }
        let remainingMinutes = endDate.map { max(1, Int(ceil($0.timeIntervalSinceNow / 60))) } ?? sessionMinutes
        start(minutes: remainingMinutes, allowDisplaySleep: allowDisplaySleep, allowClosedDisplaySleep: allowClosedDisplaySleep, screenSaverMinutes: screenSaverMinutes)
    }

    func shutdown() { stop() }

    var remainingText: String {
        guard let endDate else { return String(localized: "Until stopped") }
        let seconds = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func releaseAssertions() {
        if systemAssertion != 0 { IOPMAssertionRelease(systemAssertion); systemAssertion = 0 }
        if displayAssertion != 0 { IOPMAssertionRelease(displayAssertion); displayAssertion = 0 }
    }
}
