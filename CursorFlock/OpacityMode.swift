import CoreGraphics
import Foundation

enum OpacityMode: String, CaseIterable {
    case solid
    case distanceFade
}

extension OpacityMode {
    var displayName: String {
        switch self {
        case .solid:
            return "Fully Opaque"
        case .distanceFade:
            return "Fade by Distance"
        }
    }
}

struct OpacitySettings {
    var mode: OpacityMode
    var baseOpacity: CGFloat {
        didSet {
            baseOpacity = Self.clampedOpacity(baseOpacity)
        }
    }
    var minimumOpacity: CGFloat {
        didSet {
            minimumOpacity = Self.clampedOpacity(minimumOpacity)
        }
    }
    var fadeExponent: CGFloat {
        didSet {
            fadeExponent = max(fadeExponent, 0.01)
        }
    }

    init(
        mode: OpacityMode = .distanceFade,
        baseOpacity: CGFloat = 0.85,
        minimumOpacity: CGFloat = 0.18,
        fadeExponent: CGFloat = 1.35
    ) {
        self.mode = mode
        self.baseOpacity = Self.clampedOpacity(baseOpacity)
        self.minimumOpacity = Self.clampedOpacity(minimumOpacity)
        self.fadeExponent = max(fadeExponent, 0.01)
    }

    static func clampedOpacity(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
