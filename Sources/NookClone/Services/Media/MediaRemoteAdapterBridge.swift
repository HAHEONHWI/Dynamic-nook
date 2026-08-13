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
    private let lineBuffer = AdapterLineBuffer()
    private var streamProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var latestPayload: Payload?
    private var didPerformInitialFetch = false

    var isAvailable: Bool { locations != nil }

    init(bundle: Bundle = .main, runner: ProcessRunner = ProcessRunner()) {
        locations = Self.locations(in: bundle)
        self.runner = runner
    }

    init(locations: Locations?, runner: ProcessRunner = ProcessRunner()) {
        self.locations = locations
        self.runner = runner
    }

    func currentMedia() async -> MediaInfo? {
        start()
        if latestPayload == nil, !didPerformInitialFetch {
            didPerformInitialFetch = true
            await fetchInitialMedia()
        }
        return latestPayload?.mediaInfo(
            at: Date(),
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

    func start() {
        guard streamProcess == nil, let locations else { return }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            locations.scriptURL.path,
            locations.frameworkURL.path,
            "stream",
            "--no-diff",
            "--debounce=100"
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self, lineBuffer] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let lines = lineBuffer.append(data)
            guard !lines.isEmpty else { return }
            Task { @MainActor [weak self] in
                lines.forEach { self?.consume($0) }
            }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            if handle.availableData.isEmpty { handle.readabilityHandler = nil }
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.streamProcess = nil
                self?.outputPipe = nil
                self?.errorPipe = nil
            }
        }

        do {
            try process.run()
            streamProcess = process
            self.outputPipe = outputPipe
            self.errorPipe = errorPipe
        } catch {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
        }
    }

    func stop() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        if let streamProcess, streamProcess.isRunning { streamProcess.terminate() }
        streamProcess = nil
        outputPipe = nil
        errorPipe = nil
        lineBuffer.removeAll()
    }

    static func decodeMedia(
        from data: Data,
        at date: Date = Date(),
        playerName: String = "System Player"
    ) -> MediaInfo? {
        decodePayload(from: data)?.mediaInfo(at: date, playerName: playerName)
    }

    private func fetchInitialMedia() async {
        guard let locations else { return }
        guard let result = try? await runner.run(
            executable: URL(fileURLWithPath: "/usr/bin/perl"),
            arguments: [
                locations.scriptURL.path,
                locations.frameworkURL.path,
                "get",
                "--now",
                "--no-artwork"
            ]
        ), result.exitCode == 0 else { return }
        if let payload = Self.decodePayload(from: Data(result.output.utf8)) {
            latestPayload = payload
        }
    }

    private func run(arguments: [String]) async throws {
        guard let locations else { throw MediaRemoteAdapterError.unavailable }
        let result = try await runner.run(
            executable: URL(fileURLWithPath: "/usr/bin/perl"),
            arguments: [locations.scriptURL.path, locations.frameworkURL.path] + arguments
        )
        guard result.exitCode == 0 else { throw MediaRemoteAdapterError.commandFailed }
    }

    private func consume(_ line: Data) {
        if line == Data("null".utf8) {
            latestPayload = nil
            return
        }
        if let payload = Self.decodePayload(from: line) {
            latestPayload = payload
        }
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
}

private final class AdapterLineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ data: Data) -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)

        var lines: [Data] = []
        let newline = Data([0x0A])
        while let range = buffer.range(of: newline) {
            let line = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            if !line.isEmpty { lines.append(line) }
        }
        return lines
    }

    func removeAll() {
        lock.lock()
        buffer.removeAll(keepingCapacity: false)
        lock.unlock()
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
