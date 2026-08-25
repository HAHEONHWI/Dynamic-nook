import Foundation
import XCTest
@testable import NookClone

@MainActor
final class UtilityAndMarketTests: XCTestCase {
    func testCountdownUsesReferenceDateAndStopsAtZero() {
        let store = UtilityTimerStore()
        let base = Date(timeIntervalSinceReferenceDate: 1_000)
        store.setMinutes(1)
        store.startPause(now: base)
        store.refresh(now: base.addingTimeInterval(20))
        XCTAssertEqual(store.displayedSeconds, 40)
        store.refresh(now: base.addingTimeInterval(61))
        XCTAssertEqual(store.displayedSeconds, 0)
        XCTAssertFalse(store.isRunning)
    }

    func testCountdownCompletionFiresOnlyOnce() {
        let store = UtilityTimerStore()
        let base = Date(timeIntervalSinceReferenceDate: 2_000)
        var completions = 0
        store.onCompletion = { completions += 1 }
        store.setMinutes(1)
        store.startPause(now: base)

        store.refresh(now: base.addingTimeInterval(61))
        store.refresh(now: base.addingTimeInterval(120))

        XCTAssertEqual(completions, 1, "Countdown reaching zero must emit exactly one completion event")
    }

    func testMarketItemStorageRoundTrip() {
        let item = MarketItem.currency(base: "USD", quote: "KRW")
        XCTAssertEqual(MarketItem(storageValue: item.storageValue), item)
        XCTAssertEqual(MarketItem(storageValue: "stock:AAPL"), .stock(symbol: "AAPL"))
    }

    func testKoreanStockSymbolCandidates() {
        XCTAssertEqual(MarketService.stockSymbolCandidates("005930"), ["005930.KS", "005930.KQ"])
        XCTAssertEqual(MarketService.stockSymbolCandidates("aapl"), ["AAPL"])
    }

    func testNetworkCachePolicy() {
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        XCTAssertTrue(NetworkCachePolicy.isValid(fetchedAt: date, now: date.addingTimeInterval(59)))
        XCTAssertFalse(NetworkCachePolicy.isValid(fetchedAt: date, now: date.addingTimeInterval(60)))
    }

    func testCPUUsageUsesTickDeltas() {
        XCTAssertEqual(SystemUsageMath.cpu(previous: [10, 5, 80, 5], current: [30, 15, 130, 5]), 0.375, accuracy: 0.001)
    }

    func testQuickActionTargetParsing() throws {
        XCTAssertEqual(QuickActionTarget.parse("https://example.com"), .url(try XCTUnwrap(URL(string: "https://example.com"))))
        XCTAssertEqual(QuickActionTarget.parse("shell:echo hello"), .shell("echo hello"))
        XCTAssertNil(QuickActionTarget.parse("   "))
    }

    func testGitHubRemoteUsernameParsing() {
        XCTAssertEqual(DeveloperService.username(fromRemoteURL: "git@github.com:HAHEONHWI/Dynamic-nook.git\n"), "HAHEONHWI")
        XCTAssertEqual(DeveloperService.username(fromRemoteURL: "https://github.com/octocat/Hello-World.git"), "octocat")
        XCTAssertEqual(DeveloperService.username(fromRemoteURL: "https://gitlab.com/user/repo.git"), "")
    }

    func testGitHubContributionParsing() {
        let html = #"<td data-date="2026-08-11" data-level="0"></td><td data-date="2026-08-12" data-level="4"></td><h2>1,234 contributions in the last year</h2>"#
        XCTAssertEqual(DeveloperService.parseContributionDays(html), [
            GitHubContributionDay(date: "2026-08-11", level: 0),
            GitHubContributionDay(date: "2026-08-12", level: 4)
        ])
        XCTAssertEqual(DeveloperService.parseContributionCount(html), 1_234)
    }
}
