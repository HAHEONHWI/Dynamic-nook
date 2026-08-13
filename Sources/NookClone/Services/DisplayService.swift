import AppKit
import CoreGraphics
import Observation
import SystemDisplayBridgeC

struct ScreenMetrics: Equatable, Sendable {
    let frame: CGRect
    let visibleFrame: CGRect
    let safeAreaTop: CGFloat
    let auxiliaryTopLeftArea: CGRect?
    let auxiliaryTopRightArea: CGRect?
}

struct NotchGeometry: Equatable, Sendable {
    let collapsedSize: CGSize
    let hasPhysicalNotch: Bool
}

struct DisplayModeItem: Identifiable, Equatable, Sendable {
    let id: Int32
    let width: Int
    let height: Int
    let refreshRate: Double

    var title: String {
        let rate = refreshRate > 0 ? " · \(Int(refreshRate.rounded())) Hz" : ""
        return "\(width) × \(height)\(rate)"
    }
}

struct ManagedDisplay: Identifiable, Equatable, Sendable {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
    var brightness: Double
    var contrast: Double
    let supportsBrightness: Bool
    let supportsDDC: Bool
    var currentModeID: Int32
    let modes: [DisplayModeItem]
}

enum NotchGeometryCalculator {
    static func calculate(metrics: ScreenMetrics, virtualWidth: CGFloat) -> NotchGeometry {
        if let left = metrics.auxiliaryTopLeftArea,
           let right = metrics.auxiliaryTopRightArea {
            let gap = right.minX - left.maxX
            if gap >= 80, gap <= 420, metrics.safeAreaTop > 0 {
                return NotchGeometry(
                    collapsedSize: CGSize(width: gap, height: max(28, metrics.safeAreaTop)),
                    hasPhysicalNotch: true
                )
            }
        }

        return NotchGeometry(
            collapsedSize: CGSize(width: virtualWidth, height: AppConstants.virtualNotchSize.height),
            hasPhysicalNotch: false
        )
    }
}

@MainActor
@Observable
final class DisplayService {
    private(set) var screens: [NSScreen] = NSScreen.screens
    private(set) var managedDisplays: [ManagedDisplay] = []
    private(set) var lastControlError: String?
    var onConfigurationChange: (() -> Void)?
    private var screenObserver: NSObjectProtocol?

    init() {
        refreshManagedDisplays()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.screens = NSScreen.screens
                self?.refreshManagedDisplays()
                self?.onConfigurationChange?()
            }
        }
    }

    func refreshManagedDisplays() {
        managedDisplays = screens.compactMap { screen in
            guard let id = screen.displayID,
                  let currentMode = CGDisplayCopyDisplayMode(id) else { return nil }
            var brightness: Float = 0.5
            let hasNativeBrightness = NookDisplayGetBrightness(id, &brightness)
            let supportsDDC = CGDisplayIsBuiltin(id) == 0 && NookDisplaySupportsDDC(id)
            let modes = uniqueModes(for: id)
            return ManagedDisplay(
                id: id,
                name: screen.localizedName,
                isBuiltIn: CGDisplayIsBuiltin(id) != 0,
                brightness: Double(brightness),
                contrast: 0.5,
                supportsBrightness: hasNativeBrightness || supportsDDC,
                supportsDDC: supportsDDC,
                currentModeID: currentMode.ioDisplayModeID,
                modes: modes
            )
        }
    }

    func setBrightness(_ value: Double, for displayID: CGDirectDisplayID) {
        guard let index = managedDisplays.firstIndex(where: { $0.id == displayID }) else { return }
        managedDisplays[index].brightness = value
        let succeeded = NookDisplaySetBrightness(displayID, Float(value))
        lastControlError = succeeded ? nil : "This display did not accept the brightness command."
    }

    func setContrast(_ value: Double, for displayID: CGDirectDisplayID) {
        guard let index = managedDisplays.firstIndex(where: { $0.id == displayID }) else { return }
        managedDisplays[index].contrast = value
        let succeeded = NookDisplaySetContrast(displayID, Float(value))
        lastControlError = succeeded ? nil : "This display did not accept the DDC/CI contrast command."
    }

    func setMode(_ modeID: Int32, for displayID: CGDirectDisplayID) {
        guard let mode = (CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode])?
            .first(where: { $0.ioDisplayModeID == modeID }) else { return }
        var configuration: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&configuration) == .success,
              let configuration else { return }
        let configureResult = CGConfigureDisplayWithDisplayMode(configuration, displayID, mode, nil)
        guard configureResult == .success else {
            CGCancelDisplayConfiguration(configuration)
            lastControlError = "The selected display mode could not be applied."
            return
        }
        let result = CGCompleteDisplayConfiguration(configuration, .permanently)
        if result == .success,
           let index = managedDisplays.firstIndex(where: { $0.id == displayID }) {
            managedDisplays[index].currentModeID = modeID
            lastControlError = nil
        } else {
            lastControlError = "The selected display mode could not be saved."
        }
    }

    private func uniqueModes(for displayID: CGDirectDisplayID) -> [DisplayModeItem] {
        let modes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] ?? []
        var seen = Set<String>()
        return modes.compactMap { mode in
            let key = "\(mode.width)x\(mode.height)@\(Int(mode.refreshRate.rounded()))"
            guard seen.insert(key).inserted else { return nil }
            return DisplayModeItem(
                id: mode.ioDisplayModeID,
                width: mode.width,
                height: mode.height,
                refreshRate: mode.refreshRate
            )
        }
        .sorted {
            if $0.width != $1.width { return $0.width > $1.width }
            if $0.height != $1.height { return $0.height > $1.height }
            return $0.refreshRate > $1.refreshRate
        }
    }

    func shutdown() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    func targetScreen(preference: DisplayPreference) -> NSScreen? {
        guard !screens.isEmpty else { return nil }
        switch preference {
        case .main:
            return NSScreen.main ?? screens.first
        case .underPointer:
            let point = NSEvent.mouseLocation
            return screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main ?? screens.first
        case .builtIn:
            return screens.first(where: { screen in
                guard let id = screen.displayID else { return false }
                return CGDisplayIsBuiltin(id) != 0
            }) ?? NSScreen.main ?? screens.first
        }
    }

    func geometry(for screen: NSScreen, virtualWidth: CGFloat) -> NotchGeometry {
        NotchGeometryCalculator.calculate(
            metrics: ScreenMetrics(
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                safeAreaTop: screen.safeAreaInsets.top,
                auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
                auxiliaryTopRightArea: screen.auxiliaryTopRightArea
            ),
            virtualWidth: virtualWidth
        )
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
