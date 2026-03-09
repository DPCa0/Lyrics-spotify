import Foundation
import AppKit

class SpotifyBridge {

    static let shared = SpotifyBridge()

    private init() {}

    /// Check if Spotify is running
    func isSpotifyRunning() -> Bool {
        let apps = NSWorkspace.shared.runningApplications
        return apps.contains { $0.bundleIdentifier == "com.spotify.client" }
    }

    /// Query Spotify via AppleScript for current track info
    func getCurrentTrack() -> SpotifyTrack? {
        guard isSpotifyRunning() else { return nil }

        let script = """
        tell application "Spotify"
            if player state is stopped then
                return "STOPPED"
            end if
            set trackId to id of current track
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackDuration to duration of current track
            set playerPos to player position
            set playState to player state
            set isPlaying to (playState is playing)
            return trackId & "|||" & trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (trackDuration as text) & "|||" & (playerPos as text) & "|||" & (isPlaying as text)
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else { return nil }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if error != nil { return nil }

        let output = result.stringValue ?? ""
        if output == "STOPPED" { return nil }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 7 else { return nil }

        let rawId = parts[0]  // "spotify:track:XXXXX"
        let trackId = rawId.replacingOccurrences(of: "spotify:track:", with: "")

        let name = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let duration = Int(parts[4]) ?? 0  // already in ms
        let position = Double(parts[5]) ?? 0.0
        let isPlaying = parts[6] == "true"

        return SpotifyTrack(
            id: trackId,
            name: name,
            artist: artist,
            album: album,
            duration: duration,
            position: position,
            isPlaying: isPlaying
        )
    }
}
