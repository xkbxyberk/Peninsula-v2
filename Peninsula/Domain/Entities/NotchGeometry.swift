import Foundation
import CoreGraphics

struct NotchGeometry: Equatable, Sendable {
    let width: CGFloat
    let height: CGFloat
    let centerX: CGFloat
    let cornerRadius: CGFloat
    let screenFrame: CGRect
    let menuBarHeight: CGFloat
    
    var origin: CGPoint {
        CGPoint(
            x: centerX - width / 2,
            y: screenFrame.maxY - height
        )
    }
    
    var frame: CGRect {
        CGRect(origin: origin, size: CGSize(width: width, height: height))
    }
    
    var bottomLeft: CGPoint {
        CGPoint(x: frame.minX, y: frame.minY)
    }
    
    var bottomRight: CGPoint {
        CGPoint(x: frame.maxX, y: frame.minY)
    }
    
    var topLeft: CGPoint {
        CGPoint(x: frame.minX, y: frame.maxY)
    }
    
    var topRight: CGPoint {
        CGPoint(x: frame.maxX, y: frame.maxY)
    }
    
    func expanded(to size: CGSize) -> NotchGeometry {
        NotchGeometry(
            width: size.width,
            height: size.height,
            centerX: centerX,
            cornerRadius: Notch.CornerRadius.max,
            screenFrame: screenFrame,
            menuBarHeight: menuBarHeight
        )
    }
    
    static let zero = NotchGeometry(
        width: 0,
        height: 0,
        centerX: 0,
        cornerRadius: 0,
        screenFrame: .zero,
        menuBarHeight: 0
    )
}

