import Foundation

enum NotchState: Equatable, Sendable {
    case closed
    case expanded
    
    var isExpanded: Bool {
        self == .expanded
    }
    
    mutating func toggle() {
        self = isExpanded ? .closed : .expanded
    }
}
