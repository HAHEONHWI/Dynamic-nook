import CoreGraphics
import Foundation

enum AppConstants {
    static let bundleIdentifier = "dev.nookclone.app"
    static let virtualNotchSize = CGSize(width: 190, height: 32)
    static let defaultExpandedSize = CGSize(width: 1120, height: 220)
    static let minimumExpandedWidth: CGFloat = 760
    static let maximumExpandedWidth: CGFloat = 1400
    static let minimumExpandedHeight: CGFloat = 180
    static let maximumExpandedHeight: CGFloat = 300
    static let mediaRefreshInterval: Duration = .milliseconds(500)
}
