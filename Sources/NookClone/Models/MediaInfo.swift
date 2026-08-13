import Foundation

struct MediaInfo: Equatable, Sendable {
    var title: String
    var artist: String
    var album: String?
    var duration: TimeInterval
    var position: TimeInterval
    var isPlaying: Bool
    var playerName: String
    var playerBundleIdentifier: String?
    var artworkData: Data?

    static let preview = MediaInfo(
        title: "Nothing Playing",
        artist: "Open Apple Music to begin",
        album: nil,
        duration: 0,
        position: 0,
        isPlaying: false,
        playerName: "Music",
        playerBundleIdentifier: "com.apple.Music",
        artworkData: nil
    )
}
