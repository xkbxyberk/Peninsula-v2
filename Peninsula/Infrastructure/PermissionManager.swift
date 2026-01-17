import AppKit
import Foundation

final class PermissionManager {
    static let shared = PermissionManager()
    
    /// Weather service instance for permission management
    private(set) var weatherService: WeatherService?
    
    /// Calendar service instance for permission management
    private(set) var calendarService: CalendarService?
    
    private init() {}
    
    func requestPermissionsOnLaunch() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.triggerAppleMusicPermission()
            self.triggerSpotifyPermission()
        }
    }
    
    /// Initialize dashboard services and request their permissions
    /// - Parameters:
    ///   - weatherService: The weather service instance
    ///   - calendarService: The calendar service instance
    func initializeDashboardServices(weatherService: WeatherService, calendarService: CalendarService) {
        self.weatherService = weatherService
        self.calendarService = calendarService
        
        // Start monitoring - this will trigger permission dialogs if needed
        weatherService.startMonitoring()
        calendarService.startMonitoring()
    }
    
    private func triggerAppleMusicPermission() {
        let script = """
        tell application "System Events"
            return name of first process whose bundle identifier is "com.apple.Music"
        end tell
        """
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(&error)
    }
    
    private func triggerSpotifyPermission() {
        let script = """
        tell application "System Events"
            return name of first process whose bundle identifier is "com.spotify.client"
        end tell
        """
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(&error)
    }
}

