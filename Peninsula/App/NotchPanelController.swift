import Foundation
import AppKit
import SwiftUI
import Combine

final class NotchPanelController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<NotchPanelView>?
    private let viewModel: NotchViewModel
    private var stateObservationTask: Task<Void, Never>?
    
    private let shadowPadding: CGFloat = 25
    
    var currentPanelFrame: NSRect {
        panel?.frame ?? .zero
    }
    
    var currentContentFrame: NSRect {
        let contentSize = calculateContentSize(for: viewModel.state)
        let panelFrame = currentPanelFrame
        
        let contentX = panelFrame.origin.x + (panelFrame.width - contentSize.width) / 2
        let contentY = panelFrame.origin.y + panelFrame.height - contentSize.height - shadowPadding
        
        return NSRect(
            x: contentX,
            y: contentY,
            width: contentSize.width,
            height: contentSize.height
        )
    }
    
    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        setupPanel()
        observeStateChanges()
    }
    
    private func setupPanel() {
        let geometry = viewModel.currentGeometry
        let panelFrame = calculateFixedPanelFrame(geometry: geometry)
        
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
        
        updateMouseEventHandling(for: viewModel.state)
    }
    
    private func observeStateChanges() {
        stateObservationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            var lastState = self.viewModel.state
            
            while !Task.isCancelled {
                let currentState = withObservationTracking {
                    self.viewModel.state
                } onChange: {
                    Task { @MainActor in }
                }
                
                if currentState != lastState {
                    lastState = currentState
                    self.updateMouseEventHandling(for: currentState)
                }
                
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
    
    private func updateMouseEventHandling(for state: NotchState) {
        guard let panel = panel else { return }
        panel.ignoresMouseEvents = !state.isExpanded
    }
    
    private func calculateFixedPanelFrame(geometry: NotchGeometry) -> NSRect {
        let width = Notch.Expanded.width + (shadowPadding * 2)
        let height = Notch.Expanded.height + shadowPadding
        
        let x = geometry.centerX - width / 2
        let y = geometry.screenFrame.maxY - height
        
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    private func calculateContentSize(for state: NotchState) -> CGSize {
        switch state {
        case .closed:
            return CGSize(width: Notch.Closed.width, height: Notch.Closed.height)
        case .playing:
            return CGSize(width: Notch.Playing.width, height: Notch.Playing.height)
        case .expanded:
            return CGSize(width: Notch.Expanded.width, height: Notch.Expanded.height)
        }
    }
    
    func show() {
        panel?.orderFrontRegardless()
        viewModel.startTracking()
        updateMouseEventHandling(for: viewModel.state)
    }
    
    func hide() {
        panel?.orderOut(nil)
        viewModel.stopTracking()
    }
    
    func updateForCurrentScreen() {
        viewModel.updateGeometry()
        if viewModel.currentGeometry != .zero {
            let newFrame = calculateFixedPanelFrame(geometry: viewModel.currentGeometry)
            panel?.setFrame(newFrame, display: true, animate: false)
            hostingView?.frame = NSRect(origin: .zero, size: newFrame.size)
        }
    }
    
    deinit {
        stateObservationTask?.cancel()
    }
}
