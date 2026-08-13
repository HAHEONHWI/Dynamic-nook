import XCTest
@testable import NookClone

@MainActor
final class MediaRemoteTests: XCTestCase {
    func testRuntimeBridgeLoadsOnCurrentMacOS() {
        let bridge = MediaRemoteBridge()
        XCTAssertTrue(bridge.isAvailable)
        _ = bridge.currentMedia()
    }

    func testAdapterDecodesStreamPayloadAndAdvancesPosition() throws {
        let json = #"{"type":"data","diff":false,"payload":{"title":"Adapter Track","artist":"Adapter Artist","album":"Adapter Album","duration":420.5,"elapsedTime":10,"timestamp":"2026-08-12T09:00:00Z","playbackRate":1,"playing":true,"bundleIdentifier":"com.google.Chrome","artworkData":"AQID"}}"#
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-12T09:00:05Z"))
        let media = try XCTUnwrap(
            MediaRemoteAdapterBridge.decodeMedia(
                from: Data(json.utf8),
                at: now,
                playerName: "Google Chrome"
            )
        )

        XCTAssertEqual(media.title, "Adapter Track")
        XCTAssertEqual(media.artist, "Adapter Artist")
        XCTAssertEqual(media.album, "Adapter Album")
        XCTAssertEqual(media.duration, 420.5)
        XCTAssertEqual(media.position, 15, accuracy: 0.01)
        XCTAssertTrue(media.isPlaying)
        XCTAssertEqual(media.playerName, "Google Chrome")
        XCTAssertEqual(media.playerBundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(media.artworkData, Data([1, 2, 3]))
    }

    func testAdapterDecodesOneShotPayload() throws {
        let json = #"{"title":"Paused Track","artist":"Artist","duration":180,"elapsedTime":42,"elapsedTimeNow":43.5,"playbackRate":0,"playing":false,"bundleIdentifier":"com.apple.Music"}"#
        let media = try XCTUnwrap(MediaRemoteAdapterBridge.decodeMedia(from: Data(json.utf8)))

        XCTAssertEqual(media.title, "Paused Track")
        XCTAssertEqual(media.position, 43.5, accuracy: 0.01)
        XCTAssertFalse(media.isPlaying)
        XCTAssertEqual(media.playerBundleIdentifier, "com.apple.Music")
    }

    func testAdapterRejectsEmptyAndDiffPayloads() {
        XCTAssertNil(MediaRemoteAdapterBridge.decodeMedia(from: Data("null\n".utf8)))
        let diff = #"{"type":"data","diff":true,"payload":{"title":"Partial"}}"#
        XCTAssertNil(MediaRemoteAdapterBridge.decodeMedia(from: Data(diff.utf8)))
    }
}
