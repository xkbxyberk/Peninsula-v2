import Foundation
import AppKit
import Combine

final class HoverTrackingService {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private let notchGeometryProvider: () -> NotchGeometry
    private let contentFrameProvider: () -> NSRect
    private let stateProvider: () -> NotchState
    
    private let hoverSubject = CurrentValueSubject<Bool, Never>(false)
    var isHovering: AnyPublisher<Bool, Never> {
        hoverSubject.removeDuplicates().eraseToAnyPublisher()
    }
    
    private var currentHoverState = false
    private var exitWorkItem: DispatchWorkItem?
    
    private let entryPadding: CGFloat = 15
    private let activePadding: CGFloat = 2
    private let exitDelayMs: Int = 50
    
    init(
        notchGeometryProvider: @escaping () -> NotchGeometry,
        contentFrameProvider: @escaping () -> NSRect,
        stateProvider: @escaping () -> NotchState
    ) {
        self.notchGeometryProvider = notchGeometryProvider
        self.contentFrameProvider = contentFrameProvider
        self.stateProvider = stateProvider
    }
    
    func startTracking() {
        stopTracking()
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseEvent()
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseEvent()
            return event
        }
    }
    
    func stopTracking() {
        exitWorkItem?.cancel()
        exitWorkItem = nil
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func handleMouseEvent() {
        let mouseLocation = NSEvent.mouseLocation
        let state = stateProvider()
        
        let isInHoverZone: Bool
        
        if currentHoverState || state.isExpanded {
            isInHoverZone = isInActiveZone(mouseLocation)
        } else {
            isInHoverZone = isInEntryZone(mouseLocation)
        }
        
        if isInHoverZone {
            exitWorkItem?.cancel()
            exitWorkItem = nil
            
            if !currentHoverState {
                currentHoverState = true
                hoverSubject.send(true)
            }
        } else if currentHoverState {
            scheduleExit()
        }
    }
    
    private func isInEntryZone(_ point: CGPoint) -> Bool {
        let geometry = notchGeometryProvider()
        guard geometry != .zero else { return false }
        
        let entryWidth = max(Notch.Playing.width, geometry.width)
        let entryHeight = geometry.menuBarHeight
        
        let entryFrame = CGRect(
            x: geometry.centerX - (entryWidth / 2) - entryPadding,
            y: geometry.screenFrame.maxY - entryHeight,
            width: entryWidth + (entryPadding * 2),
            height: entryHeight + entryPadding
        )
        
        return entryFrame.contains(point)
    }
    
    private func isInActiveZone(_ point: CGPoint) -> Bool {
        if isInEntryZone(point) {
            return true
        }
        
        let contentFrame = contentFrameProvider()
        guard contentFrame != .zero else { return false }
        
        let activeFrame = contentFrame.insetBy(dx: -activePadding, dy: -activePadding)
        return activeFrame.contains(point)
    }
    
    private func scheduleExit() {
        exitWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            let state = self.stateProvider()
            
            let stillHovering: Bool
            if state.isExpanded {
                stillHovering = self.isInActiveZone(mouseLocation)
            } else {
                stillHovering = self.isInEntryZone(mouseLocation)
            }
            
            if !stillHovering {
                self.currentHoverState = false
                self.hoverSubject.send(false)
            }
            
            self.exitWorkItem = nil
        }
        
        exitWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(exitDelayMs), execute: workItem)
    }
    
    func forceExit() {
        exitWorkItem?.cancel()
        exitWorkItem = nil
        currentHoverState = false
        hoverSubject.send(false)
    }
    
    deinit {
        stopTracking()
    }
}
