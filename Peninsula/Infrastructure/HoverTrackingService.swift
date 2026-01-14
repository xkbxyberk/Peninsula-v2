import Foundation
import AppKit
import Combine

final class HoverTrackingService {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let notchGeometryProvider: () -> NotchGeometry
    
    private let hoverSubject = CurrentValueSubject<Bool, Never>(false)
    var isHovering: AnyPublisher<Bool, Never> {
        hoverSubject.removeDuplicates().eraseToAnyPublisher()
    }
    
    private var currentHoverState = false
    private let hitTestPadding: CGFloat = 10
    
    init(notchGeometryProvider: @escaping () -> NotchGeometry) {
        self.notchGeometryProvider = notchGeometryProvider
    }
    
    func startTracking() {
        stopTracking()
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited]) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited]) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }
    }
    
    func stopTracking() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        let geometry = notchGeometryProvider()
        
        let hitTestFrame = geometry.frame.expanded(by: NSEdgeInsets(
            top: 20,
            left: hitTestPadding,
            bottom: hitTestPadding,
            right: hitTestPadding
        ))
        
        let isInNotchArea = hitTestFrame.contains(mouseLocation)
        
        if isInNotchArea != currentHoverState {
            currentHoverState = isInNotchArea
            hoverSubject.send(isInNotchArea)
        }
    }
    
    deinit {
        stopTracking()
    }
}
