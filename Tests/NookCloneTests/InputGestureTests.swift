import CoreGraphics
import XCTest
@testable import NookClone

final class InputGestureTests: XCTestCase {
    func testTopScreenEdgeAddsSafeHitPaddingAroundNotch() {
        let screen = CGRect(x: 100, y: -200, width: 1_200, height: 900)

        XCTAssertTrue(
            NookPanelInteractionPolicy.isInTopEdgeInputRegion(
                point: CGPoint(x: 700, y: 700),
                screenFrame: screen,
                notchWidth: 190
            )
        )
        XCTAssertTrue(
            NookPanelInteractionPolicy.isInTopEdgeInputRegion(
                point: CGPoint(x: 806, y: 698),
                screenFrame: screen,
                notchWidth: 190
            )
        )
        XCTAssertFalse(
            NookPanelInteractionPolicy.isInTopEdgeInputRegion(
                point: CGPoint(x: 820, y: 700),
                screenFrame: screen,
                notchWidth: 190
            )
        )
        XCTAssertFalse(
            NookPanelInteractionPolicy.isInTopEdgeInputRegion(
                point: CGPoint(x: 700, y: 694),
                screenFrame: screen,
                notchWidth: 190
            )
        )
    }

    func testSmallTrackpadDeltasAccumulateIntoDownGesture() {
        var accumulator = NookScrollGestureAccumulator(threshold: 30)
        XCTAssertNil(accumulator.process(sample(vertical: -8, phase: .began)))
        XCTAssertNil(accumulator.process(sample(vertical: -8)))
        XCTAssertNil(accumulator.process(sample(vertical: -8)))
        XCTAssertEqual(accumulator.process(sample(vertical: -8)), .down)
    }

    func testNaturalScrollingIsNormalized() {
        var accumulator = NookScrollGestureAccumulator(threshold: 20)
        XCTAssertNil(accumulator.process(sample(vertical: 11, inverted: true, phase: .began)))
        XCTAssertEqual(accumulator.process(sample(vertical: 11, inverted: true)), .down)
    }

    func testOnlyOneActionPerGesture() {
        var accumulator = NookScrollGestureAccumulator(threshold: 20)
        XCTAssertNil(accumulator.process(sample(horizontal: -12, phase: .began)))
        XCTAssertEqual(accumulator.process(sample(horizontal: -12)), .left)
        XCTAssertNil(accumulator.process(sample(horizontal: -30)))
        XCTAssertNil(accumulator.process(sample(phase: .ended)))
        XCTAssertNil(accumulator.process(sample(horizontal: 12, phase: .began)))
        XCTAssertEqual(accumulator.process(sample(horizontal: 12)), .right)
    }

    func testMouseWheelDoesNotTriggerTrackpadGesture() {
        var accumulator = NookScrollGestureAccumulator(threshold: 10)
        XCTAssertNil(accumulator.process(sample(vertical: -100, precise: false, phase: .began)))
    }

    func testCompactMediaSwipeHidesLeftAndRestoresRight() {
        XCTAssertEqual(
            NookPanelInteractionPolicy.compactMediaSwipeAction(
                direction: .left,
                state: .collapsed,
                hasMedia: true,
                isMediaHidden: false,
                isMediaIslandEnabled: true,
                hasLiveAction: false
            ),
            .hide
        )
        XCTAssertEqual(
            NookPanelInteractionPolicy.compactMediaSwipeAction(
                direction: .right,
                state: .collapsed,
                hasMedia: true,
                isMediaHidden: true,
                isMediaIslandEnabled: true,
                hasLiveAction: false
            ),
            .restore
        )
    }

    func testCompactMediaSwipeDoesNotOverrideSettingsOrExpandedWidgets() {
        XCTAssertNil(
            NookPanelInteractionPolicy.compactMediaSwipeAction(
                direction: .right,
                state: .collapsed,
                hasMedia: true,
                isMediaHidden: true,
                isMediaIslandEnabled: false,
                hasLiveAction: false
            )
        )
        XCTAssertNil(
            NookPanelInteractionPolicy.compactMediaSwipeAction(
                direction: .left,
                state: .expanded,
                hasMedia: true,
                isMediaHidden: false,
                isMediaIslandEnabled: true,
                hasLiveAction: false
            )
        )
    }

    func testClickPolicyUsesWholeCollapsedPanel() {
        XCTAssertTrue(
            NookPanelInteractionPolicy.shouldToggleForClick(
                state: .collapsed,
                location: CGPoint(x: 5, y: 5),
                panelSize: CGSize(width: 190, height: 32),
                notchWidth: 190,
                isEnabled: true
            )
        )
    }

    func testExpandedClickPolicyOnlyUsesTopCenterHeader() {
        let size = CGSize(width: 480, height: 250)
        XCTAssertTrue(
            NookPanelInteractionPolicy.shouldToggleForClick(
                state: .expanded,
                location: CGPoint(x: 240, y: 245),
                panelSize: size,
                notchWidth: 190,
                isEnabled: true
            )
        )
        XCTAssertFalse(
            NookPanelInteractionPolicy.shouldToggleForClick(
                state: .expanded,
                location: CGPoint(x: 240, y: 200),
                panelSize: size,
                notchWidth: 190,
                isEnabled: true
            )
        )
        XCTAssertFalse(
            NookPanelInteractionPolicy.shouldToggleForClick(
                state: .expanded,
                location: CGPoint(x: 30, y: 245),
                panelSize: size,
                notchWidth: 190,
                isEnabled: true
            )
        )
    }

    func testPeekingMediaControlsReceiveClicksOutsideNotchHeader() {
        let controlClick = NookPanelInteractionPolicy.shouldToggleForClick(
            state: .peeking,
            location: CGPoint(x: 320, y: 20),
            panelSize: CGSize(width: 420, height: 80),
            notchWidth: 185,
            hasInteractiveMediaControls: true,
            isEnabled: true
        )
        let notchClick = NookPanelInteractionPolicy.shouldToggleForClick(
            state: .peeking,
            location: CGPoint(x: 210, y: 70),
            panelSize: CGSize(width: 420, height: 80),
            notchWidth: 185,
            hasInteractiveMediaControls: true,
            isEnabled: true
        )

        XCTAssertFalse(controlClick)
        XCTAssertTrue(notchClick)
    }

    func testFileDropRoutesAcrossStablePanelHalves() {
        XCTAssertEqual(
            NookFileDropRouting.target(locationX: 120, panelWidth: 500, canAirDrop: true),
            .tray
        )
        XCTAssertEqual(
            NookFileDropRouting.target(locationX: 380, panelWidth: 500, canAirDrop: true),
            .airDrop
        )
        XCTAssertEqual(
            NookFileDropRouting.target(locationX: 380, panelWidth: 500, canAirDrop: false),
            .tray
        )
    }

    func testCalendarDateWheelKeepsVerticalAndHorizontalScroll() {
        XCTAssertTrue(
            NookPanelInteractionPolicy.shouldPreserveCalendarDateScroll(
                horizontalDelta: 12,
                verticalDelta: 2,
                isPointerOverCalendarDates: true
            )
        )
        XCTAssertTrue(
            NookPanelInteractionPolicy.shouldPreserveCalendarDateScroll(
                horizontalDelta: 2,
                verticalDelta: 12,
                isPointerOverCalendarDates: true
            )
        )
        XCTAssertFalse(
            NookPanelInteractionPolicy.shouldPreserveCalendarDateScroll(
                horizontalDelta: 12,
                verticalDelta: 2,
                isPointerOverCalendarDates: false
            )
        )
    }

    private func sample(
        horizontal: CGFloat = 0,
        vertical: CGFloat = 0,
        inverted: Bool = false,
        precise: Bool = true,
        phase: NookScrollPhase = .changed
    ) -> NookScrollSample {
        NookScrollSample(
            horizontal: horizontal,
            vertical: vertical,
            isDirectionInverted: inverted,
            isPrecise: precise,
            phase: phase,
            isMomentum: false
        )
    }
}
