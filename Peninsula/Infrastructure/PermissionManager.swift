import AppKit
import Foundation

final class PermissionManager {
    static let shared = PermissionManager()
    
    private init() {}
    
    func requestPermissionsOnLaunch() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.triggerAppleMusicPermission()
            self.triggerSpotifyPermission()
        }
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
