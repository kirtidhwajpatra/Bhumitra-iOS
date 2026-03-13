import SwiftUI

public enum ParcelStyle {
    case normal(landUse: String?)
    case selected
    
    var fillColor: Color {
        switch self {
        case .normal(let landUse):
            switch landUse?.lowercased() {
            case "residential": return .green
            case "commercial": return .red
            case "industrial": return .purple
            case "open space": return .yellow
            default: return .blue
            }
        case .selected: return .yellow
        }
    }
    
    var strokeColor: Color {
        switch self {
        case .normal: return .white
        case .selected: return .yellow
        }
    }
    
    var strokeWidth: CGFloat {
        switch self {
        case .normal: return 1.0
        case .selected: return 3.0
        }
    }
}
