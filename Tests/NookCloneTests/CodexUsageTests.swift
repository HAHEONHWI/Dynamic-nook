import Foundation
import XCTest
@testable import NookClone

final class CodexUsageTests: XCTestCase {
    func testLatestTokenCountUsesCurrentContextRatherThanCumulativeUsage() throws {
        let data = Data("""
        {"timestamp":"2026-08-18T01:00:00Z","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":90000},"model_context_window":258400},"rate_limits":{"primary":{"used_percent":41.0,"window_minutes":10080}}}}
        {"timestamp":"2026-08-18T02:00:00Z","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":900000},"last_token_usage":{"total_tokens":215199},"model_context_window":258400},"rate_limits":{"primary":{"used_percent":78.0,"window_minutes":10080}}}}
        """.utf8)

        let snapshot = try XCTUnwrap(CodexUsageParser.latestSnapshot(in: data))

        XCTAssertEqual(snapshot.usedTokens, 215_199)
        XCTAssertEqual(snapshot.contextWindow, 258_400)
        XCTAssertEqual(snapshot.remainingTokens, 43_201)
        XCTAssertEqual(snapshot.weeklyUsedPercent, 78)
        XCTAssertEqual(snapshot.usedFraction, 215_199.0 / 258_400.0, accuracy: 0.000_001)
    }

    func testInvalidSessionTailReturnsNoUsage() {
        XCTAssertNil(CodexUsageParser.latestSnapshot(in: Data("partial prompt content".utf8)))
    }

    func testServiceLoadsNewestSessionFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let older = directory.appending(path: "older.jsonl")
        let latest = directory.appending(path: "latest.jsonl")
        try Data("{\"payload\":{\"type\":\"token_count\",\"info\":{\"last_token_usage\":{\"total_tokens\":100},\"model_context_window\":1000}}}\n".utf8).write(to: older)
        try Data("{\"payload\":{\"type\":\"token_count\",\"info\":{\"last_token_usage\":{\"total_tokens\":750},\"model_context_window\":1000}}}\n".utf8).write(to: latest)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: older.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2)], ofItemAtPath: latest.path)

        let snapshot = await CodexUsageService(sessionsRoot: directory).loadLatest()

        XCTAssertEqual(snapshot?.remainingTokens, 250)
    }
}
