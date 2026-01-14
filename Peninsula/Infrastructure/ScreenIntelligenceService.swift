import Foundation
import AppKit

final class ScreenIntelligenceService: Sendable {
    static let shared = ScreenIntelligenceService()
    
    private init() {}
    
    func calculateNotchGeometry(for screen: NSScreen) -> NotchGeometry {
        let frame = screen.frame
        let safeArea = screen.safeAreaInsets
        
        guard safeArea.top > 0 else {
            return .zero
        }
        
        let notchWidth = Notch.Closed.width
        let notchHeight = Notch.Closed.height
        
        let cornerRadius = Notch.CornerRadius.min
        
        return NotchGeometry(
            width: notchWidth,
            height: notchHeight,
            centerX: frame.midX,
            cornerRadius: cornerRadius,
            screenFrame: frame
        )
    }
    
    func hasPhysicalNotch(_ screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0
    }
    
    func currentScreen() -> NSScreen {
        NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens.first!
    }
    
    func notchGeometryForCurrentScreen() -> NotchGeometry {
        calculateNotchGeometry(for: currentScreen())
    }
}
