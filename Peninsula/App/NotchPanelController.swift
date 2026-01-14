import Foundation
import AppKit
import SwiftUI
import Combine

final class NotchPanelController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<NotchPanelView>?
    private let viewModel: NotchViewModel
    
    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        setupPanel()
        observeStateChanges()
    }
    
    private func setupPanel() {
        let geometry = viewModel.currentGeometry
        let panelFrame = calculatePanelFrame(for: geometry)
        
        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Panel.level)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.isMovableByWindowBackground = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        
        let contentView = NotchPanelView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(origin: .zero, size: panelFrame.size)
        
        panel.contentView = hostingView
        
        self.panel = panel
        self.hostingView = hostingView
    }
    
    private func observeStateChanges() {
        Task { @MainActor in
            var lastState = viewModel.state
            while true {
                let currentState = withObservationTracking {
                    viewModel.state
                } onChange: {
                    Task { @MainActor in }
                }
                
                if currentState != lastState {
                    lastState = currentState
                    updateMouseEventHandling()
                }
                
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
    
    private func updateMouseEventHandling() {
        guard let panel = panel else { return }
        panel.ignoresMouseEvents = !viewModel.state.isExpanded
    }
    
    private func calculatePanelFrame(for geometry: NotchGeometry) -> NSRect {
        let width = Notch.Expanded.width
        let height = Notch.Expanded.height
        
        let x = geometry.centerX - width / 2
        let y = geometry.screenFrame.maxY - height
        
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    func show() {
        panel?.orderFrontRegardless()
        viewModel.startTracking()
        updateMouseEventHandling()
    }
    
    func hide() {
        panel?.orderOut(nil)
        viewModel.stopTracking()
    }
    
    func updateForCurrentScreen() {
        viewModel.updateGeometry()
        if let geometry = viewModel.currentGeometry as NotchGeometry?, geometry != .zero {
            let newFrame = calculatePanelFrame(for: geometry)
            panel?.setFrame(newFrame, display: true, animate: false)
            hostingView?.frame = NSRect(origin: .zero, size: newFrame.size)
        }
    }
}
