import Foundation
import XCTest
@testable import NookClone

@MainActor
final class FocusTimerTests: XCTestCase {
    func testStartPauseResumeAndReset() {
        let base = Date(timeIntervalSinceReferenceDate: 1_000)
        let store = FocusTimerStore(defaultMinutes: 5, startTicker: false)
        store.start(now: base)
        XCTAssertEqual(store.state, .running)
        store.pause(now: base.addingTimeInterval(75))
        XCTAssertEqual(store.remainingSeconds, 225, accuracy: 0.01)
        store.resume(now: base.addingTimeInterval(100))
        XCTAssertEqual(store.endDate, base.addingTimeInterval(325))
        store.reset()
        XCTAssertEqual(store.state, .idle)
        XCTAssertEqual(store.remainingSeconds, 300)
    }

    func testSleepCorrectionUsesEndDate() {
        let base = Date(timeIntervalSinceReferenceDate: 2_000)
        let store = FocusTimerStore(defaultMinutes: 5, startTicker: false)
        store.start(now: base)
        store.refresh(now: base.addingTimeInterval(240))
        XCTAssertEqual(store.remainingSeconds, 60, accuracy: 0.01)
    }

    func testCompletionFiresOnlyOnce() {
        let base = Date(timeIntervalSinceReferenceDate: 3_000)
        let store = FocusTimerStore(defaultMinutes: 5, startTicker: false)
        var completions = 0
        store.onCompletion = { completions += 1 }
        store.start(now: base)
        store.refresh(now: base.addingTimeInterval(301))
        store.refresh(now: base.addingTimeInterval(400))
        XCTAssertEqual(store.state, .completed)
        XCTAssertEqual(completions, 1)
    }
}
