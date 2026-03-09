import Foundation

// MARK: - Spotify Track Info (from AppleScript)

struct SpotifyTrack: Equatable {
    let id: String          // Just the track ID (e.g., "4PTG3Z6ehGkBFwjybzWkR8")
    let name: String
    let artist: String
    let album: String
    let duration: Int       // Duration in milliseconds
    var position: Double    // Current position in seconds
    var isPlaying: Bool
}

// MARK: - Lyrics API Response

struct LyricsResponse: Decodable {
    let lyrics: LyricsData?
}

struct LyricsData: Decodable {
    let syncType: String?
    let lines: [LyricLineRaw]
}

struct LyricLineRaw: Decodable {
    let startTimeMs: String
    let words: String
}

// MARK: - Processed Lyric Line

struct LyricLine {
    let startTimeMs: Int
    let words: String
}

// MARK: - Access Token Response

struct AccessTokenResponse: Decodable {
    let accessToken: String
    let accessTokenExpirationTimestampMs: Int64
    let clientId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken
        case accessTokenExpirationTimestampMs
        case clientId
    }
}
