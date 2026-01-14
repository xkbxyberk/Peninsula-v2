import Foundation
import Combine

@Observable
final class NotchViewModel {
    private(set) var state: NotchState = .closed
    private(set) var currentGeometry: NotchGeometry = .zero
    private(set) var displayGeometry: NotchGeometry = .zero
    
    private let screenService: ScreenIntelligenceService
    private var hoverService: HoverTrackingService?
    private var cancellables = Set<AnyCancellable>()
    
    var expansionProgress: CGFloat {
        state.isExpanded ? 1.0 : 0.0
    }
    
    init(screenService: ScreenIntelligenceService = .shared) {
        self.screenService = screenService
        updateGeometry()
        setupHoverTracking()
    }
    
    func updateGeometry() {
        currentGeometry = screenService.notchGeometryForCurrentScreen()
        displayGeometry = currentGeometry
    }
    
    private func setupHoverTracking() {
        hoverService = HoverTrackingService { [weak self] in
            self?.currentGeometry ?? .zero
        }
        
        hoverService?.isHovering
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isHovering in
                self?.handleHoverChange(isHovering)
            }
            .store(in: &cancellables)
    }
    
    private func handleHoverChange(_ isHovering: Bool) {
        let newState: NotchState = isHovering ? .expanded : .closed
        guard newState != state else { return }
        
        state = newState
        
        if state.isExpanded {
            displayGeometry = currentGeometry.expanded(to: CGSize(
                width: Notch.Expanded.width,
                height: Notch.Expanded.height
            ))
        } else {
            displayGeometry = currentGeometry
        }
    }
    
    func startTracking() {
        hoverService?.startTracking()
    }
    
    func stopTracking() {
        hoverService?.stopTracking()
    }
    
    func expand() {
        handleHoverChange(true)
    }
    
    func collapse() {
        handleHoverChange(false)
    }
}
