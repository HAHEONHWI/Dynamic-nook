import Foundation
import XCTest
@testable import NookClone

@MainActor
final class KeepAwakeServiceTests: XCTestCase {
    func testDefaultSessionCreatesDisplaySleepAssertion() throws {
        let service = KeepAwakeService(startTicker: false)
        service.start(minutes: 1, allowClosedDisplaySleep: true)
        defer { service.stop() }

        XCTAssertTrue(service.isActive)
        XCTAssertFalse(service.allowDisplaySleep)

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "assertions"]
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let assertions = String(decoding: data, as: UTF8.self)

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertTrue(
            assertions.contains("PreventUserIdleDisplaySleep named: \"Dynamic Nook Keep Awake\""),
            "An active default session must register a display-sleep assertion with powerd"
        )
    }
}
