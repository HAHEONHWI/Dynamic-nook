import AppKit
import Foundation

extension TimeInterval {
    var clockText: String {
        let value = max(0, Int(self.rounded()))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

extension URL {
    var safeDisplayName: String {
        (try? resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? lastPathComponent
    }
}

extension NSImage {
    static func symbol(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }
}
