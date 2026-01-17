// MusicService.swift

import AppKit
import Combine
import Foundation

enum MusicApp: String {
    case appleMusic = "com.apple.Music"
    case spotify = "com.spotify.client"
}

final class MusicService: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var trackName: String = ""
    @Published var artistName: String = ""
    @Published var albumName: String = ""
    @Published var artwork: NSImage? {
        didSet {
            updateAccentColor()
        }
    }
    @Published var accentColor: NSColor = .white
    @Published var activeApp: MusicApp?
    @Published var currentPosition: Double = 0
    @Published var duration: Double = 0
    @Published var shuffleEnabled: Bool = false
    @Published var isSeeking: Bool = false
    
    private var artworkCache: [String: NSImage] = [:]
    private var currentTrackIdentifier: String = ""
    private var currentArtworkRequestId: UUID?
    private var artworkLoadWorkItem: DispatchWorkItem?
    private var positionTimer: Timer?
    
    init() {
        setupNotificationObservers()
        updateNowPlaying()
    }
    
    deinit {
        removeNotificationObservers()
        positionTimer?.invalidate()
    }
    
    private func setupNotificationObservers() {
        let dnc = DistributedNotificationCenter.default()
        
        dnc.addObserver(
            self,
            selector: #selector(handleSpotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
        
        dnc.addObserver(
            self,
            selector: #selector(handleAppleMusicNotification(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }
    
    private func removeNotificationObservers() {
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    @objc private func handleSpotifyNotification(_ notification: Notification) {
        guard isAppRunning(.spotify) else { return }
        
        if let userInfo = notification.userInfo {
            processSpotifyPayload(userInfo)
        } else {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.fetchSpotifyState()
            }
        }
    }
    
    @objc private func handleAppleMusicNotification(_ notification: Notification) {
        guard isAppRunning(.appleMusic) else { return }
        
        if let userInfo = notification.userInfo {
            processAppleMusicPayload(userInfo)
        } else {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.fetchAppleMusicState()
            }
        }
    }
    
    @objc private func handleAppLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }
        
        if bundleId == MusicApp.appleMusic.rawValue || bundleId == MusicApp.spotify.rawValue {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.updateNowPlaying()
            }
        }
    }
    
    @objc private func handleAppTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }
        
        if bundleId == activeApp?.rawValue {
            DispatchQueue.main.async { [weak self] in
                self?.clearState()
                self?.updateNowPlaying()
            }
        }
    }
    
    private func processSpotifyPayload(_ userInfo: [AnyHashable: Any]) {
        let state = userInfo["Player State"] as? String ?? ""
        let newIsPlaying = state == "Playing"
        let newTrack = userInfo["Name"] as? String ?? ""
        let newArtist = userInfo["Artist"] as? String ?? ""
        let newAlbum = userInfo["Album"] as? String ?? ""
        let newDuration = (userInfo["Duration"] as? Double ?? 0) / 1000.0
        
        let newIdentifier = "\(newTrack)|\(newArtist)|\(newAlbum)"
        let trackChanged = currentTrackIdentifier != newIdentifier
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.activeApp = .spotify
            self.isPlaying = newIsPlaying
            self.trackName = newTrack
            self.artistName = newArtist
            self.albumName = newAlbum
            self.duration = newDuration
            
            if trackChanged {
                self.currentTrackIdentifier = newIdentifier
                self.artwork = nil  // Immediately clear old artwork
                self.scheduleArtworkLoad { self.fetchSpotifyArtwork() }
            }
            
            self.managePositionTracking()
        }
    }
    
    private func processAppleMusicPayload(_ userInfo: [AnyHashable: Any]) {
        let state = userInfo["Player State"] as? String ?? ""
        let newIsPlaying = state == "Playing"
        let newTrack = userInfo["Name"] as? String ?? ""
        let newArtist = userInfo["Artist"] as? String ?? ""
        let newAlbum = userInfo["Album"] as? String ?? ""
        let newDuration = userInfo["Total Time"] as? Double ?? 0
        
        let newIdentifier = "\(newTrack)|\(newArtist)|\(newAlbum)"
        let trackChanged = currentTrackIdentifier != newIdentifier
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.activeApp = .appleMusic
            self.isPlaying = newIsPlaying
            self.trackName = newTrack
            self.artistName = newArtist
            self.albumName = newAlbum
            self.duration = newDuration / 1000.0
            
            if trackChanged {
                self.currentTrackIdentifier = newIdentifier
                self.artwork = nil  // Immediately clear old artwork
                self.scheduleArtworkLoad { self.loadAppleMusicArtwork() }
            }
            
            self.managePositionTracking()
        }
    }
    
    private func managePositionTracking() {
        positionTimer?.invalidate()
        positionTimer = nil
        
        guard isPlaying else { return }
        
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePositionOnly()
        }
        positionTimer?.tolerance = 0.1
        updatePositionOnly()
    }
    
    private func updatePositionOnly() {
        guard let app = activeApp, !isSeeking else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            
            let position: Double
            switch app {
            case .appleMusic:
                position = self.getAppleMusicPosition().position
            case .spotify:
                position = self.getSpotifyPosition().position
            }
            
            DispatchQueue.main.async {
                self.currentPosition = position
            }
        }
    }
    
    private func fetchSpotifyState() {
        guard let info = getSpotifyTrackInfo() else { return }
        let (position, dur) = getSpotifyPosition()
        let newIdentifier = "\(info.track)|\(info.artist)|\(info.album)"
        let trackChanged = currentTrackIdentifier != newIdentifier
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.activeApp = .spotify
            self.isPlaying = info.isPlaying
            self.trackName = info.track
            self.artistName = info.artist
            self.albumName = info.album
            self.currentPosition = position
            self.duration = dur
            
            if trackChanged {
                self.currentTrackIdentifier = newIdentifier
                self.artwork = nil  // Immediately clear old artwork
                if let url = info.artworkURL {
                    self.scheduleArtworkLoad { self.loadSpotifyArtwork(from: url) }
                }
            }
            
            self.managePositionTracking()
        }
    }
    
    private func fetchAppleMusicState() {
        guard let info = getAppleMusicTrackInfo() else { return }
        let (position, dur) = getAppleMusicPosition()
        let newIdentifier = "\(info.track)|\(info.artist)|\(info.album)"
        let trackChanged = currentTrackIdentifier != newIdentifier
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.activeApp = .appleMusic
            self.isPlaying = info.isPlaying
            self.trackName = info.track
            self.artistName = info.artist
            self.albumName = info.album
            self.currentPosition = position
            self.duration = dur
            
            if trackChanged {
                self.currentTrackIdentifier = newIdentifier
                self.artwork = nil  // Immediately clear old artwork
                self.scheduleArtworkLoad { self.loadAppleMusicArtwork() }
            }
            
            self.managePositionTracking()
        }
    }
    
    /// Debounce artwork loading to prevent rapid consecutive requests during fast track skipping
    private func scheduleArtworkLoad(_ loadAction: @escaping () -> Void) {
        artworkLoadWorkItem?.cancel()
        
        let requestId = UUID()
        currentArtworkRequestId = requestId
        
        artworkLoadWorkItem = DispatchWorkItem { [weak self] in
            guard let self, self.currentArtworkRequestId == requestId else { return }
            loadAction()
        }
        
        // 150ms debounce - prevents unnecessary requests during rapid skipping
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: artworkLoadWorkItem!)
    }
    
    private func fetchSpotifyArtwork() {
        let requestId = currentArtworkRequestId
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, self.currentArtworkRequestId == requestId else { return }
            
            let script = """
            tell application "Spotify"
                try
                    return artwork url of current track
                on error
                    return ""
                end try
            end tell
            """
            
            if let urlString = self.executeAppleScript(script), !urlString.isEmpty {
                // Verify request is still valid before loading
                guard self.currentArtworkRequestId == requestId else { return }
                self.loadSpotifyArtwork(from: urlString, requestId: requestId)
            }
        }
    }
    
    func playPause() {
        guard let app = activeApp else { return }
        switch app {
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to playpause")
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to playpause")
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
    }
    
    func previousTrack() {
        guard let app = activeApp else { return }
        switch app {
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to previous track")
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to previous track")
        }
    }
    
    func seek(to position: Double) {
        guard let app = activeApp else { return }
        
        currentPosition = position
        
        let posInt = Int(position)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            switch app {
            case .appleMusic:
                self?.executeAppleScript("tell application \"Music\" to set player position to \(posInt)")
            case .spotify:
                self?.executeAppleScript("tell application \"Spotify\" to set player position to \(posInt)")
            }
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
                self.fetchAppleMusicState()
                return
            }
            
            if self.isAppRunning(.spotify) {
                self.fetchSpotifyState()
                return
            }
            
            DispatchQueue.main.async {
                self.clearState()
            }
        }
    }
    
    private func clearState() {
        activeApp = nil
        isPlaying = false
        trackName = ""
        artistName = ""
        albumName = ""
        artwork = nil
        currentPosition = 0
        duration = 0
        currentTrackIdentifier = ""
        currentArtworkRequestId = nil
        artworkLoadWorkItem?.cancel()
        artworkLoadWorkItem = nil
        positionTimer?.invalidate()
        positionTimer = nil
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
        let requestId = currentArtworkRequestId
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, self.currentArtworkRequestId == requestId else { return }
            
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
                self.fetchArtworkFromiTunes(artist: artist, album: album, requestId: requestId)
                return
            }
            let result = appleScript.executeAndReturnError(&error)
            
            // Verify request is still valid before updating artwork
            guard self.currentArtworkRequestId == requestId else { return }
            
            let imageData = result.data
            if imageData.count > 0, let image = NSImage(data: imageData) {
                DispatchQueue.main.async {
                    guard self.currentArtworkRequestId == requestId else { return }
                    self.artwork = image
                }
            } else {
                self.fetchArtworkFromiTunes(artist: artist, album: album, requestId: requestId)
            }
        }
    }
    
    private func fetchArtworkFromiTunes(artist: String, album: String, requestId: UUID?) {
        let searchTerm = "\(artist) \(album)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(searchTerm)&media=music&entity=album&limit=1"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data else { return }
            guard self.currentArtworkRequestId == requestId else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let firstResult = results.first,
                   let artworkUrl = firstResult["artworkUrl100"] as? String {
                    
                    let highResUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
                    
                    if let imageUrl = URL(string: highResUrl) {
                        URLSession.shared.dataTask(with: imageUrl) { [weak self] imgData, _, _ in
                            guard let self, let imgData, let image = NSImage(data: imgData) else { return }
                            guard self.currentArtworkRequestId == requestId else { return }
                            DispatchQueue.main.async {
                                guard self.currentArtworkRequestId == requestId else { return }
                                self.artwork = image
                            }
                        }.resume()
                    }
                }
            } catch {}
        }.resume()
    }
    
    private func loadSpotifyArtwork(from urlString: String, requestId: UUID? = nil) {
        let cacheKey = urlString
        let activeRequestId = requestId ?? currentArtworkRequestId
        
        if let cached = artworkCache[cacheKey] {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.currentArtworkRequestId == activeRequestId else { return }
                self.artwork = cached
            }
            return
        }
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let image = NSImage(data: data) else { return }
            guard self.currentArtworkRequestId == activeRequestId else { return }
            DispatchQueue.main.async {
                guard self.currentArtworkRequestId == activeRequestId else { return }
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
