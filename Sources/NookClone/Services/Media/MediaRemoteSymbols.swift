enum MediaRemoteCommand: Int32, Sendable {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

enum MediaRemoteKey {
    static let title = "kMRMediaRemoteNowPlayingInfoTitle"
    static let artist = "kMRMediaRemoteNowPlayingInfoArtist"
    static let album = "kMRMediaRemoteNowPlayingInfoAlbum"
    static let duration = "kMRMediaRemoteNowPlayingInfoDuration"
    static let elapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
    static let playbackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"
    static let artworkData = "kMRMediaRemoteNowPlayingInfoArtworkData"
    static let playerName = "NookClonePlayerDisplayName"
    static let bundleIdentifier = "NookClonePlayerBundleIdentifier"
}
