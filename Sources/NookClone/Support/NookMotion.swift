import AppKit
import SwiftUI

enum NookMotion {
    static let controlPoint1 = CGPoint(x: 0.22, y: 1.00)
    static let controlPoint2 = CGPoint(x: 0.36, y: 1.00)

    static func duration(speed: Double) -> Double {
        0.42 / min(max(speed, 0.65), 1.5)
    }

    static func animation(speed: Double, reduceMotion: Bool) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.16) }
        return .timingCurve(
            controlPoint1.x,
            controlPoint1.y,
            controlPoint2.x,
            controlPoint2.y,
            duration: duration(speed: speed)
        )
    }

    static var timingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(
            controlPoints: Float(controlPoint1.x),
            Float(controlPoint1.y),
            Float(controlPoint2.x),
            Float(controlPoint2.y)
        )
    }
}
