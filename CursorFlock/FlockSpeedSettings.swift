import CoreGraphics

struct FlockSpeedSettings {
    var maximumSpeed: CGFloat {
        didSet {
            maximumSpeed = Self.clampedMaximumSpeed(maximumSpeed)
        }
    }
    var minimumSpeedRatio: CGFloat {
        didSet {
            minimumSpeedRatio = Self.clampedMinimumSpeedRatio(minimumSpeedRatio)
        }
    }
    var speedVariation: CGFloat {
        didSet {
            speedVariation = Self.clampedSpeedVariation(speedVariation)
        }
    }

    init(
        maximumSpeed: CGFloat = 520,
        minimumSpeedRatio: CGFloat = 0.45,
        speedVariation: CGFloat = 0.30
    ) {
        self.maximumSpeed = Self.clampedMaximumSpeed(maximumSpeed)
        self.minimumSpeedRatio = Self.clampedMinimumSpeedRatio(minimumSpeedRatio)
        self.speedVariation = Self.clampedSpeedVariation(speedVariation)
    }

    func maximumSpeed(forNormalizedSeed seed: CGFloat) -> CGFloat {
        let normalizedSeed = min(max(seed, 0), 1)
        let low = 1 - speedVariation
        let high = 1 + speedVariation
        let variationMultiplier = low + (high - low) * normalizedSeed
        return maximumSpeed * max(minimumSpeedRatio, variationMultiplier)
    }

    static func clampedMaximumSpeed(_ value: CGFloat) -> CGFloat {
        min(max(value, 120), 2400)
    }

    static func clampedMinimumSpeedRatio(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.20), 1.0)
    }

    static func clampedSpeedVariation(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 0.60)
    }
}

enum FlockSpeedPreset: String, CaseIterable {
    case slow
    case balanced
    case fast
    case veryFast
}

extension FlockSpeedPreset {
    var displayName: String {
        switch self {
        case .slow:
            return "Slow"
        case .balanced:
            return "Balanced"
        case .fast:
            return "Fast"
        case .veryFast:
            return "Very Fast"
        }
    }

    var maximumSpeed: CGFloat {
        switch self {
        case .slow:
            return 400
        case .balanced:
            return 900
        case .fast:
            return 1450
        case .veryFast:
            return 2000
        }
    }

    static func matching(maximumSpeed: CGFloat) -> FlockSpeedPreset? {
        allCases.first { abs($0.maximumSpeed - maximumSpeed) < 0.001 }
    }
}

enum SpeedVariationPreset: String, CaseIterable {
    case uniform
    case subtle
    case natural
    case strong
}

extension SpeedVariationPreset {
    var displayName: String {
        switch self {
        case .uniform:
            return "Uniform"
        case .subtle:
            return "Subtle"
        case .natural:
            return "Natural"
        case .strong:
            return "Strong"
        }
    }

    var minimumSpeedRatio: CGFloat {
        switch self {
        case .uniform:
            return 1.00
        case .subtle:
            return 0.75
        case .natural:
            return 0.45
        case .strong:
            return 0.30
        }
    }

    var speedVariation: CGFloat {
        switch self {
        case .uniform:
            return 0.00
        case .subtle:
            return 0.12
        case .natural:
            return 0.30
        case .strong:
            return 0.50
        }
    }

    static func matching(settings: FlockSpeedSettings) -> SpeedVariationPreset? {
        allCases.first {
            abs($0.minimumSpeedRatio - settings.minimumSpeedRatio) < 0.001
                && abs($0.speedVariation - settings.speedVariation) < 0.001
        }
    }
}

enum FlockDistancePreset: String, CaseIterable {
    case compact
    case close
    case balanced
    case wide
    case expanded
    case large
}

extension FlockDistancePreset {
    var displayName: String {
        switch self {
        case .compact:
            return "Compact - 100 pt"
        case .close:
            return "Close - 140 pt"
        case .balanced:
            return "Balanced - 180 pt"
        case .wide:
            return "Wide - 240 pt"
        case .expanded:
            return "Expanded - 320 pt"
        case .large:
            return "Large - 400 pt"
        }
    }

    var maximumRadius: CGFloat {
        switch self {
        case .compact:
            return 100
        case .close:
            return 140
        case .balanced:
            return 180
        case .wide:
            return 240
        case .expanded:
            return 320
        case .large:
            return 400
        }
    }

    static func matching(maximumRadius: CGFloat) -> FlockDistancePreset? {
        allCases.first { abs($0.maximumRadius - maximumRadius) < 0.001 }
    }
}
