import SwiftUI

struct NotchShape: Shape {
    var progress: CGFloat
    var closedWidth: CGFloat
    var closedHeight: CGFloat
    var openWidth: CGFloat
    var openHeight: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let currentWidth = closedWidth + (openWidth - closedWidth) * progress
        let currentHeight = closedHeight + (openHeight - closedHeight) * progress
        
        let offsetX = (rect.width - currentWidth) / 2
        
        let width = currentWidth
        let height = currentHeight
        
        let curve1_cp1 = CGPoint(x: offsetX + 8 + (25-8) * progress, y: 0)
        let curve1_cp2 = CGPoint(x: offsetX + 11 + (38-11) * progress, y: 2 + (12-2) * progress)
        let curve1_to = CGPoint(x: offsetX + 12 + (40-12) * progress, y: 10 + (80-10) * progress)
        
        let vLine_to = CGPoint(x: offsetX + 12 + (40-12) * progress, y: 16 + ((height - 70) - 16) * progress)
        
        let curve2_cp1 = CGPoint(x: offsetX + 12 + (40-12) * progress, y: 26 + ((height - 30) - 26) * progress)
        let curve2_cp2 = CGPoint(x: offsetX + 18 + (60-18) * progress, y: 32 + (height - 32) * progress)
        let curve2_to = CGPoint(x: offsetX + 28 + (95-28) * progress, y: 32 + (height - 32) * progress)
        
        path.move(to: CGPoint(x: offsetX, y: 0))
        
        path.addCurve(to: curve1_to, control1: curve1_cp1, control2: curve1_cp2)
        path.addLine(to: vLine_to)
        path.addCurve(to: curve2_to, control1: curve2_cp1, control2: curve2_cp2)
        
        let rightOffset = offsetX + width
        
        path.addLine(to: CGPoint(x: rightOffset - (curve2_to.x - offsetX), y: curve2_to.y))
        
        path.addCurve(
            to: CGPoint(x: rightOffset - (vLine_to.x - offsetX), y: vLine_to.y),
            control1: CGPoint(x: rightOffset - (curve2_cp2.x - offsetX), y: curve2_cp2.y),
            control2: CGPoint(x: rightOffset - (curve2_cp1.x - offsetX), y: curve2_cp1.y)
        )
        
        path.addLine(to: CGPoint(x: rightOffset - (curve1_to.x - offsetX), y: curve1_to.y))
        
        path.addCurve(
            to: CGPoint(x: rightOffset, y: 0),
            control1: CGPoint(x: rightOffset - (curve1_cp2.x - offsetX), y: curve1_cp2.y),
            control2: CGPoint(x: rightOffset - (curve1_cp1.x - offsetX), y: curve1_cp1.y)
        )
        
        path.closeSubpath()
        return path
    }
}
