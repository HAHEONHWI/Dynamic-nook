import AppKit
import ApplicationServices
import Observation

enum WindowPlacement: String, CaseIterable, Identifiable, Sendable {
    case left, right, maximize, center
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var image: String {
        switch self { case .left: "rectangle.lefthalf.inset.filled"; case .right: "rectangle.righthalf.inset.filled"; case .maximize: "rectangle.inset.filled"; case .center: "rectangle.center.inset.filled" }
    }
}

@MainActor
@Observable
final class WindowLayoutService {
    private(set) var isAccessibilityTrusted = AXIsProcessTrusted()
    private(set) var errorMessage: String?

    func refreshPermission() { isAccessibilityTrusted = AXIsProcessTrusted() }
    func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermission()
    }
    func openSettings() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }

    func arrange(_ placement: WindowPlacement) {
        refreshPermission()
        guard isAccessibilityTrusted, let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            errorMessage = "Accessibility permission is required."; return
        }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &focused) == .success,
              let window = focused as! AXUIElement?, let screen = NSScreen.main else { errorMessage = "No movable window was found."; return }
        let area = screen.visibleFrame
        let frame: CGRect
        switch placement {
        case .left: frame = CGRect(x: area.minX, y: area.minY, width: area.width / 2, height: area.height)
        case .right: frame = CGRect(x: area.midX, y: area.minY, width: area.width / 2, height: area.height)
        case .maximize: frame = area
        case .center: frame = CGRect(x: area.midX - area.width * 0.35, y: area.midY - area.height * 0.35, width: area.width * 0.7, height: area.height * 0.7)
        }
        var position = frame.origin, size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position), let sizeValue = AXValueCreate(.cgSize, &size) else { return }
        let p = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let s = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        errorMessage = p == .success && s == .success ? nil : "The window could not be moved."
    }
}
