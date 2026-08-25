import XCTest
@testable import NookClone

@MainActor
final class TimerAlertServiceTests: XCTestCase {
    func testPlayUsesAudiblePrimarySound() {
        var plays = 0
        var fallbacks = 0
        let service = TimerAlertService(
            playPrimary: { plays += 1; return true },
            playFallback: { fallbacks += 1 }
        )

        service.play()

        XCTAssertEqual(plays, 1)
        XCTAssertEqual(fallbacks, 0)
    }

    func testPlayFallsBackWhenPrimarySoundFails() {
        var fallbacks = 0
        let service = TimerAlertService(
            playPrimary: { false },
            playFallback: { fallbacks += 1 }
        )

        service.play()

        XCTAssertEqual(fallbacks, 1)
    }
}
