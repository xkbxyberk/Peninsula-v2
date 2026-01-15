import Foundation

enum NotchState: Equatable, Sendable {
    case closed
    case playing
    case expanded
    
    var isExpanded: Bool {
        self == .expanded
    }
    
    var isPlaying: Bool {
        self == .playing
    }
    
    var isClosed: Bool {
        self == .closed
    }
}

