import CoreGraphics
import XCTest
@testable import NookClone

final class GeometryTests: XCTestCase {
    func testNookMotionDurationClampsAnimationSpeed() {
        XCTAssertEqual(NookMotion.duration(speed: 1), 0.42, accuracy: 0.0001)
        XCTAssertEqual(NookMotion.duration(speed: 0.1), 0.42 / 0.65, accuracy: 0.0001)
        XCTAssertEqual(NookMotion.duration(speed: 9), 0.42 / 1.5, accuracy: 0.0001)
    }

    func testVirtualNotchFallback() {
        let metrics = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055),
            safeAreaTop: 0,
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        )
        let result = NotchGeometryCalculator.calculate(metrics: metrics, virtualWidth: 205)
        XCTAssertFalse(result.hasPhysicalNotch)
        XCTAssertEqual(result.collapsedSize, CGSize(width: 205, height: 32))
    }

    func testPhysicalNotchUsesAuxiliaryGap() {
        let metrics = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
            visibleFrame: CGRect(x: 0, y: 0, width: 1728, height: 1080),
            safeAreaTop: 37,
            auxiliaryTopLeftArea: CGRect(x: 0, y: 1080, width: 764, height: 37),
            auxiliaryTopRightArea: CGRect(x: 964, y: 1080, width: 764, height: 37)
        )
        let result = NotchGeometryCalculator.calculate(metrics: metrics, virtualWidth: 190)
        XCTAssertTrue(result.hasPhysicalNotch)
        XCTAssertEqual(result.collapsedSize, CGSize(width: 200, height: 37))
    }

    func testPanelAnchorsAtTopCenter() {
        let screen = CGRect(x: 100, y: -200, width: 1200, height: 900)
        let result = PanelPositioner.frame(panelSize: CGSize(width: 480, height: 250), screenFrame: screen)
        XCTAssertEqual(result, CGRect(x: 460, y: 450, width: 480, height: 250))
    }

    func testNotchSizeHighlightUsesActualTopCenteredDimensions() {
        let values = NotchSizeHighlightGeometry.Values(
            virtualWidth: 210,
            minimumWidth: 280,
            maximumWidth: 600,
            expandedWidth: 1_400,
            expandedHeight: 250,
            cornerRadius: 34
        )
        let screen = CGRect(x: 100, y: -200, width: 900, height: 700)

        let compact = NotchSizeHighlightGeometry.calculate(
            kind: .mediaMinimum,
            values: values,
            screenFrame: screen,
            collapsedHeight: 37
        )
        let expanded = NotchSizeHighlightGeometry.calculate(
            kind: .expandedWidth,
            values: values,
            screenFrame: screen,
            collapsedHeight: 37
        )

        XCTAssertEqual(compact.frame, CGRect(x: 410, y: 452, width: 280, height: 48))
        XCTAssertEqual(expanded.frame, CGRect(x: 112, y: 250, width: 876, height: 250))
        XCTAssertEqual(expanded.cornerRadius, 34)
    }

    func testPlayingMediaStaysInsideCompactNotch() {
        let size = NookPanelLayout.size(
            state: .collapsed,
            notchSize: CGSize(width: 185, height: 32),
            hasPhysicalNotch: true,
            minimumNotchWidth: 220,
            maximumNotchWidth: 520,
            hasLiveAction: false,
            hasPlayingMedia: true,
            preferredMediaWidth: 460,
            expandedSize: CGSize(width: 1120, height: 220),
            screenSize: CGSize(width: 1512, height: 982)
        )
        XCTAssertEqual(size, CGSize(width: 249, height: 32))
    }

    func testPeekingGrowsFromCurrentCompactIsland() {
        let size = NookPanelLayout.size(
            state: .peeking,
            notchSize: CGSize(width: 190, height: 32),
            hasPhysicalNotch: true,
            minimumNotchWidth: 220,
            maximumNotchWidth: 520,
            hasLiveAction: false,
            hasPlayingMedia: true,
            preferredMediaWidth: 460,
            expandedSize: CGSize(width: 1120, height: 220),
            screenSize: CGSize(width: 1512, height: 982)
        )
        XCTAssertEqual(size, CGSize(width: 460, height: 80))
    }

    func testWideLayoutClampsToSmallDisplay() {
        let size = NookPanelLayout.size(
            state: .expanded,
            notchSize: CGSize(width: 190, height: 32),
            hasPhysicalNotch: false,
            minimumNotchWidth: 220,
            maximumNotchWidth: 520,
            hasLiveAction: false,
            hasPlayingMedia: false,
            preferredMediaWidth: nil,
            expandedSize: CGSize(width: 1400, height: 300),
            screenSize: CGSize(width: 900, height: 700)
        )
        XCTAssertEqual(size, CGSize(width: 876, height: 300))
    }

    func testMediaWidthClampsToConfiguredRange() {
        let small = NookPanelLayout.size(
            state: .peeking,
            notchSize: CGSize(width: 185, height: 32),
            hasPhysicalNotch: true,
            minimumNotchWidth: 300,
            maximumNotchWidth: 440,
            hasLiveAction: false,
            hasPlayingMedia: true,
            preferredMediaWidth: 250,
            expandedSize: CGSize(width: 1120, height: 220),
            screenSize: CGSize(width: 1512, height: 982)
        )
        let large = NookPanelLayout.size(
            state: .peeking,
            notchSize: CGSize(width: 185, height: 32),
            hasPhysicalNotch: true,
            minimumNotchWidth: 300,
            maximumNotchWidth: 440,
            hasLiveAction: false,
            hasPlayingMedia: true,
            preferredMediaWidth: 600,
            expandedSize: CGSize(width: 1120, height: 220),
            screenSize: CGSize(width: 1512, height: 982)
        )

        XCTAssertEqual(small.width, 300)
        XCTAssertEqual(large.width, 440)
    }

    func testPreferredMediaWidthChangesWithMetadataLength() {
        let short = NookPanelLayout.preferredMediaWidth(title: "Song", artist: "Artist")
        let long = NookPanelLayout.preferredMediaWidth(
            title: "A much longer title for variable sizing",
            artist: "Artist"
        )

        XCTAssertGreaterThan(long, short)
        XCTAssertLessThanOrEqual(long, 520)
    }
}
