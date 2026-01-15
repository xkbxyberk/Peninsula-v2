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
        
        let baseH = closedHeight
        let h = height
        
        let c1_y_closed = baseH * 0.30
        let c1_y_open: CGFloat = 80
        let c1_y = c1_y_closed + (c1_y_open - c1_y_closed) * progress
        
        let v_y_closed = baseH * 0.50
        let v_y_open = h - 70
        let v_y = v_y_closed + (v_y_open - v_y_closed) * progress
        
        let c2_y1_closed = baseH * 0.80
        let c2_y1_open = h - 30
        let c2_y1 = c2_y1_closed + (c2_y1_open - c2_y1_closed) * progress
        
        let c2_y2_closed = baseH
        let c2_y2_open = h
        let c2_y2 = c2_y2_closed + (c2_y2_open - c2_y2_closed) * progress
        
        let curve1_cp1 = CGPoint(x: offsetX + 8 + (25-8) * progress, y: 0)
        let curve1_cp2 = CGPoint(x: offsetX + 11 + (38-11) * progress, y: 2 + (12-2) * progress)
        let curve1_to = CGPoint(x: offsetX + 12 + (40-12) * progress, y: c1_y)
        
        let vLine_to = CGPoint(x: offsetX + 12 + (40-12) * progress, y: v_y)
        
        let curve2_cp1 = CGPoint(x: offsetX + 12 + (40-12) * progress, y: c2_y1)
        let curve2_cp2 = CGPoint(x: offsetX + 18 + (60-18) * progress, y: c2_y2)
        let curve2_to = CGPoint(x: offsetX + 28 + (95-28) * progress, y: c2_y2)
        
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

struct ProgressRingShape: Shape {
    var width: CGFloat
    var height: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let offsetX = (rect.width - width) / 2
        let baseH = height
        
        let c1_y = baseH * 0.30
        let v_y = baseH * 0.50
        let c2_y1 = baseH * 0.80
        let c2_y2 = baseH
        
        let curve1_cp1 = CGPoint(x: offsetX + 8, y: 0)
        let curve1_cp2 = CGPoint(x: offsetX + 11, y: 2)
        let curve1_to = CGPoint(x: offsetX + 12, y: c1_y)
        
        let vLine_to = CGPoint(x: offsetX + 12, y: v_y)
        
        let curve2_cp1 = CGPoint(x: offsetX + 12, y: c2_y1)
        let curve2_cp2 = CGPoint(x: offsetX + 18, y: c2_y2)
        let curve2_to = CGPoint(x: offsetX + 28, y: c2_y2)
        
        let rightOffset = offsetX + width
        
        path.move(to: CGPoint(x: offsetX, y: 0))
        
        path.addCurve(to: curve1_to, control1: curve1_cp1, control2: curve1_cp2)
        path.addLine(to: vLine_to)
        path.addCurve(to: curve2_to, control1: curve2_cp1, control2: curve2_cp2)
        
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
        
        return path
    }
}


