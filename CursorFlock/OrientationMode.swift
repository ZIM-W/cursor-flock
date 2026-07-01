import Foundation

enum OrientationMode: String, CaseIterable {
    case preserveSystemOrientation
    case alignToGroupDirection
    case alignToIndividualDirection
}

extension OrientationMode {
    var displayName: String {
        switch self {
        case .preserveSystemOrientation:
            return "Preserve System Orientation"
        case .alignToGroupDirection:
            return "Align to Group Direction"
        case .alignToIndividualDirection:
            return "Align to Individual Direction"
        }
    }
}

enum RotationEligibilityMode: String, CaseIterable {
    case safeOnly
    case allowAllCursors
}

extension RotationEligibilityMode {
    var displayName: String {
        switch self {
        case .safeOnly:
            return "Safe Cursors Only"
        case .allowAllCursors:
            return "Allow All Cursor Shapes"
        }
    }
}
