import Foundation
import MediaRemoteBridgeC

enum MediaRemoteBridgeError: LocalizedError {
    case unavailable
    case commandFailed

    var errorDescription: String? {
        switch self {
        case .unavailable: "System MediaRemote is unavailable."
        case .commandFailed: "System media command failed."
        }
    }
}

@MainActor
final class MediaRemoteBridge {
    var isAvailable: Bool { NCMediaRemoteIsAvailable() }

    func currentMedia() -> MediaInfo? {
        guard let raw = NCMediaRemoteCopyNowPlayingInfo() else { return nil }
        let dictionary = raw as NSDictionary
        guard let title = dictionary[MediaRemoteKey.title] as? String, !title.isEmpty else { return nil }
        let playbackRate = (dictionary[MediaRemoteKey.playbackRate] as? NSNumber)?.doubleValue ?? 0
        return MediaInfo(
            title: title,
            artist: dictionary[MediaRemoteKey.artist] as? String ?? "Unknown Artist",
            album: dictionary[MediaRemoteKey.album] as? String,
            duration: (dictionary[MediaRemoteKey.duration] as? NSNumber)?.doubleValue ?? 0,
            position: (dictionary[MediaRemoteKey.elapsedTime] as? NSNumber)?.doubleValue ?? 0,
            isPlaying: playbackRate > 0,
            playerName: dictionary[MediaRemoteKey.playerName] as? String ?? "System Player",
            playerBundleIdentifier: dictionary[MediaRemoteKey.bundleIdentifier] as? String,
            artworkData: dictionary[MediaRemoteKey.artworkData] as? Data
        )
    }

    func send(_ command: MediaRemoteCommand) throws {
        guard isAvailable else { throw MediaRemoteBridgeError.unavailable }
        guard NCMediaRemoteSendCommand(command.rawValue) else { throw MediaRemoteBridgeError.commandFailed }
    }

    func seek(to position: TimeInterval) throws {
        guard isAvailable else { throw MediaRemoteBridgeError.unavailable }
        guard NCMediaRemoteSetElapsedTime(position) else { throw MediaRemoteBridgeError.commandFailed }
    }
}
