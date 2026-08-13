import AppKit
import Foundation

@MainActor
final class AppleMusicProvider: MediaProviding {
    private let runner: ProcessRunner
    private let musicBundleIdentifier = "com.apple.Music"

    init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    func currentTrack() async throws -> MediaInfo? {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: musicBundleIdentifier).isEmpty == false else {
            return nil
        }
        let script = """
        tell application "Music"
          if player state is stopped then return ""
          set t to current track
          return (name of t as text) & "|||" & (artist of t as text) & "|||" & (album of t as text) & "|||" & (duration of t as text) & "|||" & (player position as text) & "|||" & (player state as text)
        end tell
        """
        let result = try await runner.run(executable: URL(fileURLWithPath: "/usr/bin/osascript"), arguments: ["-e", script])
        guard result.exitCode == 0 else { throw ProcessRunnerError.failed(result.errorOutput) }
        let fields = result.output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|||")
        guard fields.count == 6 else { return nil }
        return MediaInfo(
            title: fields[0],
            artist: fields[1],
            album: fields[2],
            duration: Double(fields[3]) ?? 0,
            position: Double(fields[4]) ?? 0,
            isPlaying: fields[5].localizedCaseInsensitiveContains("playing"),
            playerName: "Music",
            playerBundleIdentifier: musicBundleIdentifier,
            artworkData: nil
        )
    }

    func play() async throws { try await run(command: "play") }
    func pause() async throws { try await run(command: "pause") }
    func togglePlayback() async throws { try await run(command: "playpause") }
    func next() async throws { try await run(command: "next track") }
    func previous() async throws { try await run(command: "previous track") }

    func seek(to position: TimeInterval) async throws {
        try await run(command: "set player position to \(position)")
    }

    func openPlayer() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: musicBundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    private func run(command: String) async throws {
        let script = "tell application \"Music\" to \(command)"
        let result = try await runner.run(executable: URL(fileURLWithPath: "/usr/bin/osascript"), arguments: ["-e", script])
        guard result.exitCode == 0 else { throw ProcessRunnerError.failed(result.errorOutput) }
    }
}
