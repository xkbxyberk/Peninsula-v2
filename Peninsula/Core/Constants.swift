import Foundation
import CoreGraphics

enum Notch {
    static let animationDuration: Double = 0.5
    static let animationTimingFunction = (c1: 0.16, c2: 1.0, c3: 0.3, c4: 1.0)
    
    enum Closed {
        static let width: CGFloat = 204
        static let height: CGFloat = 34
    }
    
    enum Playing {
        static let width: CGFloat = 320
        static let height: CGFloat = 34
    }
    
    enum Expanded {
        static let width: CGFloat = 530
        static let height: CGFloat = 260
    }
    
    enum CornerRadius {
        static let heightRatio: CGFloat = 0.35
        static let min: CGFloat = 8
        static let max: CGFloat = 24
    }
}

enum Panel {
    static let level: Int = 25
    static let shadowRadius: CGFloat = 20
    static let shadowOpacity: Float = 0.3
}

enum Colors {
    static let notchBackground = (r: 0.0, g: 0.0, b: 0.0, a: 1.0)
    static let contentBackground = (r: 0.1, g: 0.1, b: 0.1, a: 0.95)
}
