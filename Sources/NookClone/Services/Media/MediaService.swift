import AppKit
import Foundation
import Observation

@MainActor
protocol MediaProviding: AnyObject {
    func currentTrack() async throws -> MediaInfo?
    func play() async throws
    func pause() async throws
    func togglePlayback() async throws
    func next() async throws
    func previous() async throws
    func seek(to position: TimeInterval) async throws
    func openPlayer()
    func shutdown()
}

extension MediaProviding {
    func shutdown() {}
}

@MainActor
@Observable
final class MediaStore {
    private(set) var info: MediaInfo?
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    private let provider: any MediaProviding

    init(provider: any MediaProviding) {
        self.provider = provider
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            info = try await provider.currentTrack()
            errorMessage = nil
        } catch {
            info = nil
            errorMessage = error.localizedDescription
        }
    }

    func play() async { await perform(provider.play) }
    func pause() async { await perform(provider.pause) }
    func togglePlayback() async { await perform(provider.togglePlayback) }
    func next() async { await perform(provider.next) }
    func previous() async { await perform(provider.previous) }
    func seek(to position: TimeInterval) async { await perform { try await provider.seek(to: position) } }
    func openPlayer() { provider.openPlayer() }
    func shutdown() { provider.shutdown() }

    private func perform(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            try? await Task.sleep(for: .milliseconds(150))
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
