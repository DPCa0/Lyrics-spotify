import Foundation
import Combine

class LyricsSyncEngine: ObservableObject {

    @Published var lines: [LyricLine] = []
    @Published var currentIndex: Int = -1
    @Published var trackName: String = ""
    @Published var artistName: String = ""
    @Published var statusMessage: String = "Waiting for Spotify..."
    @Published var hasLyrics: Bool = false

    private var pollTimer: Timer?
    private var currentTrackId: String = ""
    private var isFetchingLyrics: Bool = false
    private var lastPosition: Double = 0
    private var lastPollTime: Date = Date()
    private var isPlaying: Bool = false

    func start() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        guard SpotifyLyricsAPI.shared.hasCookie() else {
            DispatchQueue.main.async {
                self.statusMessage = "Set sp_dc cookie from menu bar"
                self.hasLyrics = false
                self.lines = []
            }
            return
        }

        guard SpotifyBridge.shared.isSpotifyRunning() else {
            DispatchQueue.main.async {
                self.statusMessage = "Spotify is not running"
                self.hasLyrics = false
                self.lines = []
                self.currentTrackId = ""
            }
            return
        }

        guard let track = SpotifyBridge.shared.getCurrentTrack() else {
            DispatchQueue.main.async {
                self.statusMessage = "No track playing"
                self.hasLyrics = false
                self.lines = []
                self.currentTrackId = ""
            }
            return
        }

        let now = Date()
        isPlaying = track.isPlaying

        // Track changed → fetch new lyrics
        if track.id != currentTrackId {
            currentTrackId = track.id
            lastPosition = track.position
            lastPollTime = now

            DispatchQueue.main.async {
                self.trackName = track.name
                self.artistName = track.artist
                self.statusMessage = "Loading lyrics..."
                self.hasLyrics = false
                self.lines = []
                self.currentIndex = -1
            }

            fetchLyrics(trackId: track.id)
            return
        }

        // Update position: use AppleScript reported position
        lastPosition = track.position
        lastPollTime = now

        DispatchQueue.main.async {
            self.trackName = track.name
            self.artistName = track.artist
            self.isPlaying = track.isPlaying
        }

        // Update current lyric index
        if hasLyrics {
            updateCurrentIndex(positionMs: Int(track.position * 1000))
        }
    }

    private func fetchLyrics(trackId: String) {
        guard !isFetchingLyrics else {
            debugLog("[SyncEngine] Already fetching, skipping")
            return
        }
        isFetchingLyrics = true
        debugLog("[SyncEngine] Fetching lyrics for trackId: \(trackId)")

        SpotifyLyricsAPI.shared.fetchLyrics(trackId: trackId) { [weak self] fetchedLines in
            debugLog("[SyncEngine] Fetch callback: got \(fetchedLines?.count ?? 0) lines (nil=\(fetchedLines == nil))")
            DispatchQueue.main.async {
                self?.isFetchingLyrics = false

                guard let self = self else { return }
                // Make sure we're still on the same track
                guard self.currentTrackId == trackId else { return }

                if let fetchedLines = fetchedLines, !fetchedLines.isEmpty {
                    self.lines = fetchedLines
                    self.hasLyrics = true
                    self.statusMessage = ""
                    self.updateCurrentIndex(positionMs: Int(self.lastPosition * 1000))
                } else {
                    self.lines = []
                    self.hasLyrics = false
                    self.statusMessage = "No lyrics available"
                }
            }
        }
    }

    private func updateCurrentIndex(positionMs: Int) {
        guard !lines.isEmpty else { return }

        var newIndex = -1
        for (i, line) in lines.enumerated() {
            if positionMs >= line.startTimeMs {
                newIndex = i
            } else {
                break
            }
        }

        DispatchQueue.main.async {
            if newIndex != self.currentIndex {
                self.currentIndex = newIndex
            }
        }
    }
}
