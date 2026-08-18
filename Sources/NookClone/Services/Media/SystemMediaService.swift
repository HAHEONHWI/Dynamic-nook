import AppKit
import Foundation

@MainActor
final class SystemMediaService: MediaProviding {
    private let bridge: MediaRemoteBridge
    private let adapter: MediaRemoteAdapterBridge
    private let fallback: AppleMusicProvider
    private var lastMedia: MediaInfo?

    init(
        bridge: MediaRemoteBridge = MediaRemoteBridge(),
        adapter: MediaRemoteAdapterBridge = MediaRemoteAdapterBridge(),
        fallback: AppleMusicProvider = AppleMusicProvider()
    ) {
        self.bridge = bridge
        self.adapter = adapter
        self.fallback = fallback
    }

    func currentTrack() async throws -> MediaInfo? {
        // Read in-process first. The compatibility adapter is intentionally
        // one-shot only so Dynamic Nook never keeps a MediaRemote notification
        // client alive that could interfere with headset media-key routing.
        if bridge.isAvailable, let media = bridge.currentMedia() {
            lastMedia = media
            return media
        }
        if adapter.isAvailable, let media = await adapter.currentMedia() {
            lastMedia = media
            return media
        }
        let media = try await fallback.currentTrack()
        lastMedia = media
        return media
    }

    func play() async throws { try await send(.play, fallback: fallback.play) }
    func pause() async throws { try await send(.pause, fallback: fallback.pause) }
    func togglePlayback() async throws { try await send(.togglePlayPause, fallback: fallback.togglePlayback) }
    func next() async throws { try await send(.nextTrack, fallback: fallback.next) }
    func previous() async throws { try await send(.previousTrack, fallback: fallback.previous) }

    func seek(to position: TimeInterval) async throws {
        if bridge.isAvailable {
            do {
                try bridge.seek(to: position)
                return
            } catch {
                // Fall through to the compatibility adapter, then Apple Music.
            }
        }
        if adapter.isAvailable {
            do {
                try await adapter.seek(to: position)
                return
            } catch {
                // Fall through to Apple Music.
            }
        }
        try await fallback.seek(to: position)
    }

    func openPlayer() {
        if let identifier = lastMedia?.playerBundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        } else {
            fallback.openPlayer()
        }
    }

    func shutdown() {
        adapter.stop()
    }

    private func send(
        _ command: MediaRemoteCommand,
        fallback fallbackOperation: () async throws -> Void
    ) async throws {
        if bridge.isAvailable {
            do {
                try bridge.send(command)
                return
            } catch {
                // Fall through to the compatibility adapter, then Apple Music.
            }
        }
        if adapter.isAvailable {
            do {
                try await adapter.send(command)
                return
            } catch {
                // Fall through to Apple Music.
            }
        }
        try await fallbackOperation()
    }
}
