import CoreGraphics

enum NookPanelLayout {
    static func size(
        state: NookState,
        notchSize: CGSize,
        hasPhysicalNotch: Bool,
        minimumNotchWidth: CGFloat,
        maximumNotchWidth: CGFloat,
        hasLiveAction: Bool,
        hasPlayingMedia: Bool,
        preferredMediaWidth: CGFloat?,
        expandedSize: CGSize,
        screenSize: CGSize
    ) -> CGSize {
        let displayMaximumWidth = max(notchSize.width, screenSize.width - 24)
        let lowerWidth = min(max(minimumNotchWidth, notchSize.width), displayMaximumWidth)
        let upperWidth = min(max(maximumNotchWidth, lowerWidth), displayMaximumWidth)
        let baseCollapsedSize: CGSize
        if hasLiveAction {
            baseCollapsedSize = CGSize(
                width: clamp(max(notchSize.width, 260), lower: lowerWidth, upper: upperWidth),
                height: max(notchSize.height, 52)
            )
        } else if hasPlayingMedia {
            if hasPhysicalNotch {
                let wingWidth = min(max(notchSize.height, 32), 44)
                baseCollapsedSize = CGSize(
                    width: clamp(notchSize.width + wingWidth * 2, lower: lowerWidth, upper: upperWidth),
                    height: notchSize.height
                )
            } else {
                baseCollapsedSize = CGSize(
                    width: clamp(max(notchSize.width, 220), lower: lowerWidth, upper: upperWidth),
                    height: max(notchSize.height, 38)
                )
            }
        } else {
            baseCollapsedSize = notchSize
        }

        switch state {
        case .collapsed:
            return baseCollapsedSize
        case .peeking:
            if hasPlayingMedia {
                return CGSize(
                    width: clamp(
                        preferredMediaWidth ?? baseCollapsedSize.width + 150,
                        lower: lowerWidth,
                        upper: upperWidth
                    ),
                    height: max(baseCollapsedSize.height + 46, 80)
                )
            }
            return CGSize(
                width: min(baseCollapsedSize.width + 26, displayMaximumWidth),
                height: baseCollapsedSize.height + 10
            )
        case .expanded, .tray:
            return CGSize(
                width: min(expandedSize.width, displayMaximumWidth),
                height: min(expandedSize.height, screenSize.height - 48)
            )
        }
    }

    static func preferredMediaWidth(title: String, artist: String) -> CGFloat {
        let visibleCharacters = max(title.count, artist.count)
        return 380 + min(CGFloat(visibleCharacters) * 3.5, 140)
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
