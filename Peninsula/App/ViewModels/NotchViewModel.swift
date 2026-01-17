import Foundation
import CoreGraphics
import Combine

final class NotchViewModel: ObservableObject {
    @Published private(set) var state: NotchState = .closed
    @Published private(set) var currentGeometry: NotchGeometry = .zero
    @Published private(set) var displayGeometry: NotchGeometry = .zero
    
    let musicService = MusicService()
    
    private let screenService: ScreenIntelligenceService
    private var hoverService: HoverTrackingService?
    private var cancellables = Set<AnyCancellable>()
    private var isHovering: Bool = false
    
    weak var panelController: NotchPanelController?
    
    var isMusicActive: Bool {
        musicService.activeApp != nil
    }
    
    var expansionProgress: CGFloat {
        switch state {
        case .closed:
            return 0.0
        case .playing:
            return 0.0
        case .expanded:
            return 1.0
        }
    }
    
    var baseWidth: CGFloat {
        isMusicActive ? Notch.Playing.width : Notch.Closed.width
    }
    
    var currentWidth: CGFloat {
        switch state {
        case .closed:
            return Notch.Closed.width
        case .playing:
            return Notch.Playing.width
        case .expanded:
            return Notch.Expanded.width
        }
    }
    
    var baseHeight: CGFloat {
        currentGeometry.menuBarHeight > 0 ? currentGeometry.menuBarHeight : Notch.Closed.height
    }
    
    var currentHeight: CGFloat {
        switch state {
        case .closed:
            return baseHeight
        case .playing:
            return baseHeight
        case .expanded:
            return Notch.Expanded.height
        }
    }
    
    init(screenService: ScreenIntelligenceService = .shared) {
        self.screenService = screenService
        updateGeometry()
        setupHoverTracking()
    }
    
    func updateGeometry() {
        currentGeometry = screenService.notchGeometryForCurrentScreen()
        updateDisplayGeometry()
    }
    
    private func updateDisplayGeometry() {
        displayGeometry = currentGeometry.expanded(to: CGSize(
            width: currentWidth,
            height: currentHeight
        ))
    }
    
    private func setupHoverTracking() {
        hoverService = HoverTrackingService(
            notchGeometryProvider: { [weak self] in
                self?.currentGeometry ?? .zero
            },
            contentFrameProvider: { [weak self] in
                self?.panelController?.currentContentFrame ?? .zero
            },
            stateProvider: { [weak self] in
                self?.state ?? .closed
            },
            hitTestInfoProvider: { [weak self] in
                self?.currentHitTestInfo
            }
        )
        
        hoverService?.isHovering
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isHovering in
                self?.handleHoverChange(isHovering)
            }
            .store(in: &cancellables)
    }
    
    /// Hit-test için gereken tüm bilgileri döndürür
    var currentHitTestInfo: NotchHitTestPath.HitTestInfo? {
        guard let panelController = panelController else { return nil }
        
        let panelFrame = panelController.currentPanelFrame
        guard panelFrame != .zero else { return nil }
        
        let shadowPadding: CGFloat = 25
        
        let path = NotchHitTestPath.createPath(
            progress: expansionProgress,
            closedWidth: baseWidth,
            closedHeight: baseHeight,
            openWidth: Notch.Expanded.width,
            openHeight: Notch.Expanded.height,
            in: CGRect(origin: .zero, size: panelFrame.size)
        )
        
        return NotchHitTestPath.HitTestInfo(
            path: path,
            panelFrame: panelFrame,
            shadowPadding: shadowPadding
        )
    }
    
    private func handleHoverChange(_ hovering: Bool) {
        isHovering = hovering
        updateState()
    }
    
    private func updateState() {
        let newState: NotchState
        
        if isHovering {
            newState = .expanded
        } else if musicService.activeApp != nil {
            newState = .playing
        } else {
            newState = .closed
        }
        
        guard newState != state else { return }
        state = newState
        updateDisplayGeometry()
    }
    
    func refreshMusicState() {
        if !isHovering {
            updateState()
        }
    }
    
    func startTracking() {
        hoverService?.startTracking()
    }
    
    func stopTracking() {
        hoverService?.stopTracking()
    }
    
    func expand() {
        isHovering = true
        updateState()
    }
    
    func collapse() {
        isHovering = false
        updateState()
    }
}
