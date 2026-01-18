import Foundation
import CoreGraphics
import Combine

/// Represents which panel is currently active when expanded
enum ActivePanel: Equatable {
    case music
    case dashboard
}

final class NotchViewModel: ObservableObject {
    @Published private(set) var state: NotchState = .closed
    @Published private(set) var currentGeometry: NotchGeometry = .zero
    @Published private(set) var displayGeometry: NotchGeometry = .zero
    @Published var shouldShowProgressRing: Bool = false
    @Published private(set) var activePanel: ActivePanel = .music
    
    let musicService = MusicService()
    let weatherService = WeatherService()
    let calendarService = CalendarService()
    
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
        setupMusicServiceObserver()
        initializeDashboardServices()
        
        // Delayed initial state check - MusicService needs time to detect playing music
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshMusicState()
            self?.objectWillChange.send()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refreshMusicState()
            self?.objectWillChange.send()
        }
    }
    
    /// Initialize dashboard services and request permissions
    private func initializeDashboardServices() {
        PermissionManager.shared.initializeDashboardServices(
            weatherService: weatherService,
            calendarService: calendarService
        )
    }
    
    /// Setup observer for MusicService state changes
    private func setupMusicServiceObserver() {
        // Forward ALL MusicService changes to the ViewModel
        // This ensures that when 'duration' or 'currentPosition' changes (timer tick),
        // the View (which observes ViewModel) gets a redraw signal.
        musicService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Observe activeApp changes to update notch state
        musicService.$activeApp
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Wait for the property to actually update (Published fires on willSet)
                DispatchQueue.main.async {
                     self?.refreshMusicState()
                }
            }
            .store(in: &cancellables)
        
        // Observe isPlaying changes for equalizer animation and progress ring
        musicService.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Wait for the property to actually update
                DispatchQueue.main.async {
                    self?.refreshMusicState()
                }
            }
            .store(in: &cancellables)
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
        
        let previousState = state
        
        // Update state logic
        if newState != state {
            state = newState
            updateDisplayGeometry()
            
            // Reset activePanel to music when leaving expanded state
            if previousState == .expanded && newState != .expanded {
                activePanel = .music
            }
        }
        
        // Notify of potential ring visibility change
        if previousState != newState || newState == .playing {
            objectWillChange.send()
        }
    }
    
    // Simplified visibility logic - purely derived from state
    var showProgressRing: Bool {
        // Show ring if we are in playing state AND music is actually playing
        return state == .playing && musicService.isPlaying
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
    
    // MARK: - Panel Switching
    
    /// Switch to a specific panel (only works when expanded and music is active)
    func switchToPanel(_ panel: ActivePanel) {
        guard state.isExpanded, isMusicActive else { return }
        activePanel = panel
    }
    
    /// Toggle between music and dashboard panels
    func togglePanel() {
        guard state.isExpanded, isMusicActive else { return }
        activePanel = (activePanel == .music) ? .dashboard : .music
    }
}
