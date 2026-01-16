import AppKit
import Combine
import Foundation

enum MusicApp: String {
    case appleMusic = "com.apple.Music"
    case spotify = "com.spotify.client"
}

@Observable
final class MusicService {
    var isPlaying: Bool = false
    var trackName: String = ""
    var artistName: String = ""
    var albumName: String = ""
    var artwork: NSImage? {
        didSet {
            updateAccentColor()
        }
    }
    var accentColor: NSColor = .white
    var activeApp: MusicApp?
    var currentPosition: Double = 0
    var duration: Double = 0
    var shuffleEnabled: Bool = false
    
    private var timer: Timer?
    private var artworkCache: [String: NSImage] = [:]
    private var lastTrackName: String = ""
    
    init() {
        startPolling()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNowPlaying()
        }
        timer?.tolerance = 0.2
        updateNowPlaying()
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    func playPause() {
        guard let app = activeApp else { return }
        switch app {
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to playpause")
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to playpause")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateNowPlaying()
        }
    }
    
    func nextTrack() {
        guard let app = activeApp else { return }
        switch app {
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to next track")
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to next track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateNowPlaying()
        }
    }
    
    func previousTrack() {
        guard let app = activeApp else { return }
        switch app {
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to previous track")
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to previous track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateNowPlaying()
        }
    }
    
    func seek(to position: Double) {
        guard let app = activeApp else { return }
        let posInt = Int(position)
        switch app {
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to set player position to \(posInt)")
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to set player position to \(posInt)")
        }
    }
    
    func toggleShuffle() {
        guard let app = activeApp else { return }
        switch app {
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to set shuffle enabled to (not shuffle enabled)")
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to set shuffling to (not shuffling)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.updateShuffleState()
        }
    }
    
    private func updateShuffleState() {
        guard let app = activeApp else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var isShuffled = false
            switch app {
            case .appleMusic:
                if let result = self?.executeAppleScript("tell application \"Music\" to return shuffle enabled") {
                    isShuffled = result == "true"
                }
            case .spotify:
                if let result = self?.executeAppleScript("tell application \"Spotify\" to return shuffling") {
                    isShuffled = result == "true"
                }
            }
            DispatchQueue.main.async {
                self?.shuffleEnabled = isShuffled
            }
        }
    }
    
    private func updateNowPlaying() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            
            if self.isAppRunning(.appleMusic) {
                if let info = self.getAppleMusicTrackInfo() {
                    let (position, dur) = self.getAppleMusicPosition()
                    let trackChanged = self.lastTrackName != info.track
                    DispatchQueue.main.async {
                        self.activeApp = .appleMusic
                        self.isPlaying = info.isPlaying
                        self.trackName = info.track
                        self.artistName = info.artist
                        self.albumName = info.album
                        self.currentPosition = position
                        self.duration = dur
                        if trackChanged {
                            self.lastTrackName = info.track
                            self.loadAppleMusicArtwork()
                        }
                    }
                    return
                }
            }
            
            if self.isAppRunning(.spotify) {
                if let info = self.getSpotifyTrackInfo() {
                    let (position, dur) = self.getSpotifyPosition()
                    let trackChanged = self.lastTrackName != info.track
                    DispatchQueue.main.async {
                        self.activeApp = .spotify
                        self.isPlaying = info.isPlaying
                        self.trackName = info.track
                        self.artistName = info.artist
                        self.albumName = info.album
                        self.currentPosition = position
                        self.duration = dur
                        if trackChanged {
                            self.lastTrackName = info.track
                            if let url = info.artworkURL {
                                self.loadSpotifyArtwork(from: url)
                            }
                        }
                    }
                    return
                }
            }
            
            DispatchQueue.main.async {
                self.activeApp = nil
                self.isPlaying = false
                self.trackName = ""
                self.artistName = ""
                self.albumName = ""
                self.artwork = nil
                self.currentPosition = 0
                self.duration = 0
                self.lastTrackName = ""
            }
        }
    }
    
    private func isAppRunning(_ app: MusicApp) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == app.rawValue }
    }
    
    private func getAppleMusicTrackInfo() -> (isPlaying: Bool, track: String, artist: String, album: String)? {
        let script = """
        tell application "Music"
            if player state is playing then
                set playerState to "playing"
            else
                set playerState to "paused"
            end if
            try
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                return playerState & "|" & trackName & "|" & trackArtist & "|" & trackAlbum
            on error
                return ""
            end try
        end tell
        """
        
        guard let result = executeAppleScript(script), !result.isEmpty else { return nil }
        let parts = result.components(separatedBy: "|")
        guard parts.count >= 4 else { return nil }
        
        let isPlaying = parts[0] == "playing"
        let track = parts[1]
        let artist = parts[2]
        let album = parts[3]
        
        guard !track.isEmpty else { return nil }
        return (isPlaying, track, artist, album)
    }
    
    private func getAppleMusicPosition() -> (position: Double, duration: Double) {
        let posScript = "tell application \"Music\" to return player position"
        let durScript = "tell application \"Music\" to return duration of current track"
        
        let posResult = executeAppleScript(posScript) ?? "0"
        let durResult = executeAppleScript(durScript) ?? "0"
        
        let position = parseDouble(posResult)
        let duration = parseDouble(durResult)
        
        return (position, duration)
    }
    
    private func getSpotifyTrackInfo() -> (isPlaying: Bool, track: String, artist: String, album: String, artworkURL: String?)? {
        let script = """
        tell application "Spotify"
            if player state is playing then
                set playerState to "playing"
            else
                set playerState to "paused"
            end if
            try
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set artURL to artwork url of current track
                return playerState & "|" & trackName & "|" & trackArtist & "|" & trackAlbum & "|" & artURL
            on error
                return ""
            end try
        end tell
        """
        
        guard let result = executeAppleScript(script), !result.isEmpty else { return nil }
        let parts = result.components(separatedBy: "|")
        guard parts.count >= 5 else { return nil }
        
        let isPlaying = parts[0] == "playing"
        let track = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let artworkURL = parts[4].isEmpty ? nil : parts[4]
        
        guard !track.isEmpty else { return nil }
        return (isPlaying, track, artist, album, artworkURL)
    }
    
    private func getSpotifyPosition() -> (position: Double, duration: Double) {
        let posScript = "tell application \"Spotify\" to return player position"
        let durScript = "tell application \"Spotify\" to return (duration of current track) / 1000"
        
        let posResult = executeAppleScript(posScript) ?? "0"
        let durResult = executeAppleScript(durScript) ?? "0"
        
        let position = parseDouble(posResult)
        let duration = parseDouble(durResult)
        
        return (position, duration)
    }
    
    private func parseDouble(_ string: String) -> Double {
        let cleaned = string.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0
    }
    
    private func loadAppleMusicArtwork() {
        let artist = self.artistName
        let album = self.albumName
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            
            let script = """
            tell application "Music"
                try
                    set theTrack to current track
                    set artworkCount to count of artworks of theTrack
                    if artworkCount > 0 then
                        return data of artwork 1 of theTrack
                    else
                        return ""
                    end if
                on error
                    return ""
                end try
            end tell
            """
            
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else {
                self.fetchArtworkFromiTunes(artist: artist, album: album)
                return
            }
            let result = appleScript.executeAndReturnError(&error)
            
            let imageData = result.data
            if imageData.count > 0, let image = NSImage(data: imageData) {
                DispatchQueue.main.async {
                    self.artwork = image
                }
            } else {
                self.fetchArtworkFromiTunes(artist: artist, album: album)
            }
        }
    }
    
    private func fetchArtworkFromiTunes(artist: String, album: String) {
        let searchTerm = "\(artist) \(album)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(searchTerm)&media=music&entity=album&limit=1"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let firstResult = results.first,
                   let artworkUrl = firstResult["artworkUrl100"] as? String {
                    
                    let highResUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
                    
                    if let imageUrl = URL(string: highResUrl) {
                        URLSession.shared.dataTask(with: imageUrl) { [weak self] imgData, _, _ in
                            guard let self, let imgData, let image = NSImage(data: imgData) else { return }
                            DispatchQueue.main.async {
                                self.artwork = image
                            }
                        }.resume()
                    }
                }
            } catch {}
        }.resume()
    }
    
    private func loadSpotifyArtwork(from urlString: String) {
        let cacheKey = urlString
        if let cached = artworkCache[cacheKey] {
            self.artwork = cached
            return
        }
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                self.artworkCache[cacheKey] = image
                self.artwork = image
            }
        }.resume()
    }
    
    @discardableResult
    private func executeAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        return result?.stringValue
    }
    
    private func updateAccentColor() {
        guard let image = artwork else {
            accentColor = .white
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                return
            }
            
            let width = min(bitmap.pixelsWide, 50)
            let height = min(bitmap.pixelsHigh, 50)
            let stepX = max(1, bitmap.pixelsWide / width)
            let stepY = max(1, bitmap.pixelsHigh / height)
            
            var totalR: CGFloat = 0
            var totalG: CGFloat = 0
            var totalB: CGFloat = 0
            var count: CGFloat = 0
            
            for x in stride(from: 0, to: bitmap.pixelsWide, by: stepX) {
                for y in stride(from: 0, to: bitmap.pixelsHigh, by: stepY) {
                    if let color = bitmap.colorAt(x: x, y: y) {
                        let r = color.redComponent
                        let g = color.greenComponent
                        let b = color.blueComponent
                        let brightness = (r + g + b) / 3
                        
                        if brightness > 0.15 && brightness < 0.85 {
                            let saturation = max(r, g, b) - min(r, g, b)
                            if saturation > 0.1 {
                                totalR += r
                                totalG += g
                                totalB += b
                                count += 1
                            }
                        }
                    }
                }
            }
            
            var finalColor: NSColor = .white
            if count > 0 {
                var r = totalR / count
                var g = totalG / count
                var b = totalB / count
                
                let currentBrightness = (r + g + b) / 3
                if currentBrightness < 0.5 {
                    let boost: CGFloat = 0.5 / max(currentBrightness, 0.1)
                    r = min(1, r * boost)
                    g = min(1, g * boost)
                    b = min(1, b * boost)
                }
                
                finalColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
            }
            
            DispatchQueue.main.async {
                self.accentColor = finalColor
            }
        }
    }
}

