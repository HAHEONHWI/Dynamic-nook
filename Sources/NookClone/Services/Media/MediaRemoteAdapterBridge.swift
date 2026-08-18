import AppKit
import Foundation

enum MediaRemoteAdapterError: LocalizedError {
    case unavailable
    case commandFailed

    var errorDescription: String? {
        switch self {
        case .unavailable: "MediaRemote adapter is unavailable."
        case .commandFailed: "MediaRemote adapter command failed."
        }
    }
}

// Private API:
// This implementation relies on MediaRemote through an entitled system Perl process.
// It may require maintenance after macOS updates.
@MainActor
final class MediaRemoteAdapterBridge {
    struct Locations: Sendable {
        let scriptURL: URL
        let frameworkURL: URL
    }

    private struct StreamEnvelope: Decodable {
        let type: String
        let diff: Bool
        let payload: Payload
    }

    private struct Payload: Decodable {
        let title: String?
        let artist: String?
        let album: String?
        let duration: Double?
        let elapsedTime: Double?
        let elapsedTimeNow: Double?
        let timestamp: String?
        let playbackRate: Double?
        let playing: Bool?
        let bundleIdentifier: String?
        let artworkData: String?

        func mediaInfo(at date: Date, playerName: String) -> MediaInfo? {
            guard let title, !title.isEmpty else { return nil }

            let rate = playbackRate ?? 0
            let duration = max(0, duration ?? 0)
            var position = max(0, elapsedTimeNow ?? elapsedTime ?? 0)
            if elapsedTimeNow == nil,
               (playing ?? (rate > 0)),
               rate > 0,
               let timestamp,
               let updateDate = ISO8601DateFormatter().date(from: timestamp) {
                position += max(0, date.timeIntervalSince(updateDate)) * rate
            }
            if duration > 0 { position = min(position, duration) }

            return MediaInfo(
                title: title,
                artist: artist.flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown Artist",
                album: album.flatMap { $0.isEmpty ? nil : $0 },
                duration: duration,
                position: position,
                isPlaying: playing ?? (rate > 0),
                playerName: playerName,
                playerBundleIdentifier: bundleIdentifier,
                artworkData: artworkData.flatMap {
                    Data(base64Encoded: $0, options: .ignoreUnknownCharacters)
                }
            )
        }
    }

    private let locations: Locations?
    private let runner: ProcessRunner
    private var latestPayload: Payload?
    private var lastFetchDate: Date?
    private let minimumFetchInterval: TimeInterval = 1

    var isAvailable: Bool { locations != nil }

    init(bundle: Bundle = .main, runner: ProcessRunner = ProcessRunner()) {
        locations = Self.locations(in: bundle)
        self.runner = runner
        if let locations {
            Self.terminateLegacyStreamProcesses(scriptURL: locations.scriptURL)
        }
    }

    init(locations: Locations?, runner: ProcessRunner = ProcessRunner()) {
        self.locations = locations
        self.runner = runner
    }

    func currentMedia() async -> MediaInfo? {
        let now = Date()
        if lastFetchDate.map({ now.timeIntervalSince($0) >= minimumFetchInterval }) != false {
            lastFetchDate = now
            await fetchCurrentMedia()
        }
        return latestPayload?.mediaInfo(
            at: now,
            playerName: playerName(for: latestPayload?.bundleIdentifier)
        )
    }

    func send(_ command: MediaRemoteCommand) async throws {
        try await run(arguments: ["send", String(command.rawValue)])
    }

    func seek(to position: TimeInterval) async throws {
        let microseconds = Int64(max(0, position) * 1_000_000)
        try await run(arguments: ["seek", String(microseconds)])
    }

    func stop() {
        latestPayload = nil
        lastFetchDate = nil
    }

    static func decodeMedia(
        from data: Data,
        at date: Date = Date(),
        playerName: String = "System Player"
    ) -> MediaInfo? {
        decodePayload(from: data)?.mediaInfo(at: date, playerName: playerName)
    }

    private func fetchCurrentMedia() async {
        guard let locations else { return }
        guard let result = try? await runner.run(
            executable: URL(fileURLWithPath: "/usr/bin/perl"),
            arguments: [
                locations.scriptURL.path,
                locations.frameworkURL.path,
                "get",
                "--now"
            ]
        ), result.exitCode == 0 else { return }
        latestPayload = Self.decodePayload(from: Data(result.output.utf8))
    }

    private func run(arguments: [String]) async throws {
        guard let locations else { throw MediaRemoteAdapterError.unavailable }
        let result = try await runner.run(
            executable: URL(fileURLWithPath: "/usr/bin/perl"),
            arguments: [locations.scriptURL.path, locations.frameworkURL.path] + arguments
        )
        guard result.exitCode == 0 else { throw MediaRemoteAdapterError.commandFailed }
    }

    private func playerName(for bundleIdentifier: String?) -> String {
        guard let bundleIdentifier else { return "System Player" }
        if let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).first, let localizedName = application.localizedName {
            return localizedName
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return "System Player"
    }

    private static func decodePayload(from data: Data) -> Payload? {
        let trimmed = data.trimmingASCIIWhitespace()
        guard !trimmed.isEmpty, trimmed != Data("null".utf8) else { return nil }
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(StreamEnvelope.self, from: trimmed),
           envelope.type == "data",
           !envelope.diff {
            return envelope.payload
        }
        return try? decoder.decode(Payload.self, from: trimmed)
    }

    private static func locations(in bundle: Bundle) -> Locations? {
        guard #available(macOS 15.4, *),
              FileManager.default.isExecutableFile(atPath: "/usr/bin/perl"),
              let resourceURL = bundle.resourceURL else { return nil }

        let scriptURL = resourceURL
            .appendingPathComponent("MediaRemoteAdapter", isDirectory: true)
            .appendingPathComponent("mediaremote-adapter.pl")
        let frameworkURL = (bundle.privateFrameworksURL ?? bundle.bundleURL
            .appendingPathComponent("Contents/Frameworks", isDirectory: true))
            .appendingPathComponent("MediaRemoteAdapter.framework", isDirectory: true)
        guard FileManager.default.fileExists(atPath: scriptURL.path),
              FileManager.default.fileExists(
                atPath: frameworkURL.appendingPathComponent("MediaRemoteAdapter").path
              ) else { return nil }
        return Locations(scriptURL: scriptURL, frameworkURL: frameworkURL)
    }

    static func legacyStreamPattern(scriptPath: String) -> String {
        let escapedPath = NSRegularExpression.escapedPattern(for: scriptPath)
        return "\(escapedPath).*[[:space:]]stream([[:space:]]|$)"
    }

    private static func terminateLegacyStreamProcesses(scriptURL: URL) {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/pkill") else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        process.arguments = ["-TERM", "-f", legacyStreamPattern(scriptPath: scriptURL.path)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}

private extension Data {
    func trimmingASCIIWhitespace() -> Data {
        let whitespace = Set([UInt8(0x09), 0x0A, 0x0D, 0x20])
        guard let first = firstIndex(where: { !whitespace.contains($0) }),
              let last = lastIndex(where: { !whitespace.contains($0) }) else { return Data() }
        return subdata(in: first..<index(after: last))
    }
}
