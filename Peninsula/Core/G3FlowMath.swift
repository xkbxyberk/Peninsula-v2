import Foundation
import CoreGraphics

struct G3FlowMath {
    static func cubicBezierY(t: Double, c1: Double, c2: Double, c3: Double, c4: Double) -> Double {
        let t2 = t * t
        let t3 = t2 * t
        let mt = 1 - t
        let mt2 = mt * mt
        
        return 3 * mt2 * t * c1 + 3 * mt * t2 * c2 + t3
    }
    
    static func g3CornerControlPoints(
        cornerPoint: CGPoint,
        entryDirection: CGVector,
        exitDirection: CGVector,
        radius: CGFloat,
        smoothness: CGFloat = 0.55
    ) -> (cp1: CGPoint, cp2: CGPoint, cp3: CGPoint, cp4: CGPoint) {
        let handleLength = radius * smoothness
        let extendedHandle = radius * smoothness * 0.6
        
        let entryPoint = CGPoint(
            x: cornerPoint.x + entryDirection.dx * radius,
            y: cornerPoint.y + entryDirection.dy * radius
        )
        
        let exitPoint = CGPoint(
            x: cornerPoint.x + exitDirection.dx * radius,
            y: cornerPoint.y + exitDirection.dy * radius
        )
        
        let cp1 = CGPoint(
            x: entryPoint.x - entryDirection.dx * extendedHandle,
            y: entryPoint.y - entryDirection.dy * extendedHandle
        )
        
        let cp2 = CGPoint(
            x: entryPoint.x - entryDirection.dx * handleLength,
            y: entryPoint.y - entryDirection.dy * handleLength
        )
        
        let cp3 = CGPoint(
            x: exitPoint.x - exitDirection.dx * handleLength,
            y: exitPoint.y - exitDirection.dy * handleLength
        )
        
        let cp4 = CGPoint(
            x: exitPoint.x - exitDirection.dx * extendedHandle,
            y: exitPoint.y - exitDirection.dy * extendedHandle
        )
        
        return (cp1, cp2, cp3, cp4)
    }
    
    static func smoothCornerPath(
        from start: CGPoint,
        through corner: CGPoint,
        to end: CGPoint,
        radius: CGFloat
    ) -> (entry: CGPoint, exit: CGPoint, control1: CGPoint, control2: CGPoint) {
        let v1 = CGVector(dx: start.x - corner.x, dy: start.y - corner.y)
        let v2 = CGVector(dx: end.x - corner.x, dy: end.y - corner.y)
        
        let len1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let len2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        
        let n1 = CGVector(dx: v1.dx / len1, dy: v1.dy / len1)
        let n2 = CGVector(dx: v2.dx / len2, dy: v2.dy / len2)
        
        let entry = CGPoint(
            x: corner.x + n1.dx * radius,
            y: corner.y + n1.dy * radius
        )
        
        let exit = CGPoint(
            x: corner.x + n2.dx * radius,
            y: corner.y + n2.dy * radius
        )
        
        let handleFactor: CGFloat = 0.552284749831
        
        let control1 = CGPoint(
            x: entry.x - n1.dx * radius * handleFactor,
            y: entry.y - n1.dy * radius * handleFactor
        )
        
        let control2 = CGPoint(
            x: exit.x - n2.dx * radius * handleFactor,
            y: exit.y - n2.dy * radius * handleFactor
        )
        
        return (entry, exit, control1, control2)
    }
    
    static func interpolate(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
    
    static func easeOutExpo(_ t: Double) -> Double {
        t == 1 ? 1 : 1 - pow(2, -10 * t)
    }
}
