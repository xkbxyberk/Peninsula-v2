import Foundation
import CoreGraphics

/// Notch şeklinin gerçek zamanlı CGPath hesaplaması ve hit-test kontrolü.
/// NotchShape.swift ile aynı algoritmayı kullanarak görsel ve hit-test alanlarının
/// %100 senkron kalmasını sağlar.
struct NotchHitTestPath {
    
    /// Mevcut animasyon ilerlemesine göre hit-test için CGPath üretir.
    /// Bu fonksiyon, NotchShape.path(in:) ile aynı bezier eğri hesaplamalarını kullanır.
    ///
    /// - Parameters:
    ///   - progress: Animasyon ilerlemesi (0.0 = kapalı, 1.0 = açık)
    ///   - closedWidth: Kapalı durumdaki genişlik
    ///   - closedHeight: Kapalı durumdaki yükseklik
    ///   - openWidth: Açık durumdaki genişlik
    ///   - openHeight: Açık durumdaki yükseklik
    ///   - rect: Path'in çizileceği dikdörtgen alan
    /// - Returns: Hit-test için kullanılacak CGPath
    static func createPath(
        progress: CGFloat,
        closedWidth: CGFloat,
        closedHeight: CGFloat,
        openWidth: CGFloat,
        openHeight: CGFloat,
        in rect: CGRect
    ) -> CGPath {
        let path = CGMutablePath()
        
        let currentWidth = closedWidth + (openWidth - closedWidth) * progress
        let currentHeight = closedHeight + (openHeight - closedHeight) * progress
        
        let offsetX = (rect.width - currentWidth) / 2
        
        let width = currentWidth
        let height = currentHeight
        
        let baseH = closedHeight
        let h = height
        
        // Bezier eğri kontrol noktaları - NotchShape ile aynı hesaplamalar
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
        
        // Sol taraf eğrileri
        let curve1_cp1 = CGPoint(x: offsetX + 8 + (25-8) * progress, y: 0)
        let curve1_cp2 = CGPoint(x: offsetX + 11 + (38-11) * progress, y: 2 + (12-2) * progress)
        let curve1_to = CGPoint(x: offsetX + 12 + (40-12) * progress, y: c1_y)
        
        let vLine_to = CGPoint(x: offsetX + 12 + (40-12) * progress, y: v_y)
        
        let curve2_cp1 = CGPoint(x: offsetX + 12 + (40-12) * progress, y: c2_y1)
        let curve2_cp2 = CGPoint(x: offsetX + 18 + (60-18) * progress, y: c2_y2)
        let curve2_to = CGPoint(x: offsetX + 28 + (95-28) * progress, y: c2_y2)
        
        // Path oluşturma
        path.move(to: CGPoint(x: offsetX, y: 0))
        
        // Sol üst eğri
        path.addCurve(to: curve1_to, control1: curve1_cp1, control2: curve1_cp2)
        // Sol dikey çizgi
        path.addLine(to: vLine_to)
        // Sol alt eğri
        path.addCurve(to: curve2_to, control1: curve2_cp1, control2: curve2_cp2)
        
        let rightOffset = offsetX + width
        
        // Alt yatay çizgi
        path.addLine(to: CGPoint(x: rightOffset - (curve2_to.x - offsetX), y: curve2_to.y))
        
        // Sağ alt eğri (yansıma)
        path.addCurve(
            to: CGPoint(x: rightOffset - (vLine_to.x - offsetX), y: vLine_to.y),
            control1: CGPoint(x: rightOffset - (curve2_cp2.x - offsetX), y: curve2_cp2.y),
            control2: CGPoint(x: rightOffset - (curve2_cp1.x - offsetX), y: curve2_cp1.y)
        )
        
        // Sağ dikey çizgi
        path.addLine(to: CGPoint(x: rightOffset - (curve1_to.x - offsetX), y: curve1_to.y))
        
        // Sağ üst eğri (yansıma)
        path.addCurve(
            to: CGPoint(x: rightOffset, y: 0),
            control1: CGPoint(x: rightOffset - (curve1_cp2.x - offsetX), y: curve1_cp2.y),
            control2: CGPoint(x: rightOffset - (curve1_cp1.x - offsetX), y: curve1_cp1.y)
        )
        
        path.closeSubpath()
        return path
    }
    
    /// Ekran koordinatlarındaki bir noktanın Notch path'i içinde olup olmadığını kontrol eder.
    ///
    /// - Parameters:
    ///   - screenPoint: Ekran koordinatlarındaki nokta (NSEvent.mouseLocation)
    ///   - path: Hit-test için kullanılacak CGPath (view koordinatlarında)
    ///   - panelFrame: Panel penceresinin ekran koordinatlarındaki frame'i
    ///   - shadowPadding: Panel etrafındaki shadow padding miktarı
    /// - Returns: Nokta path içindeyse true, değilse false
    static func containsScreenPoint(
        _ screenPoint: CGPoint,
        path: CGPath,
        panelFrame: NSRect,
        shadowPadding: CGFloat = 25
    ) -> Bool {
        // Ekran koordinatlarını view koordinatlarına dönüştür
        // macOS'ta ekran koordinatları sol-alt köşeden başlar
        // View koordinatları da sol-alt köşeden başlar (flipped değilse)
        
        // Panel frame içindeki koordinata dönüştür
        let localX = screenPoint.x - panelFrame.origin.x
        let localY = screenPoint.y - panelFrame.origin.y
        
        // View koordinat sistemine çevir (üstten başlayan)
        // Panel yüksekliğinden çıkararak y'yi çevir
        let viewY = panelFrame.height - localY
        
        let viewPoint = CGPoint(x: localX, y: viewY)
        
        return path.contains(viewPoint)
    }
    
    /// Hit-test için gereken tüm bilgileri içeren yapı
    struct HitTestInfo {
        let path: CGPath
        let panelFrame: NSRect
        let shadowPadding: CGFloat
        
        func contains(screenPoint: CGPoint) -> Bool {
            return NotchHitTestPath.containsScreenPoint(
                screenPoint,
                path: path,
                panelFrame: panelFrame,
                shadowPadding: shadowPadding
            )
        }
    }
}
