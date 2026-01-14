import SwiftUI
import AppKit

@main
struct PeninsulaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: NotchPanelController?
    private var viewModel: NotchViewModel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupNotchPanel()
    }
    
    private func setupNotchPanel() {
        let screen = ScreenIntelligenceService.shared.currentScreen()
        
        guard ScreenIntelligenceService.shared.hasPhysicalNotch(screen) else {
            return
        }
        
        let vm = NotchViewModel()
        viewModel = vm
        
        let controller = NotchPanelController(viewModel: vm)
        panelController = controller
        
        controller.show()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func screenParametersChanged() {
        panelController?.updateForCurrentScreen()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        panelController?.hide()
    }
}
