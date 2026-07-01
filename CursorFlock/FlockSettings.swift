import CoreGraphics
import Foundation

enum FlockPattern: String, CaseIterable {
    case classicFlock
    case vFormation
    case scatterAndReturn
    case orbitingFlock
}

extension FlockPattern {
    var displayName: String {
        switch self {
        case .classicFlock:
            return "Classic Flock"
        case .vFormation:
            return "V Formation"
        case .scatterAndReturn:
            return "Scatter and Return"
        case .orbitingFlock:
            return "Orbiting Flock"
        }
    }
}

enum RenderFrameRate: Int, CaseIterable {
    case fps30 = 30
    case fps60 = 60
    case fps90 = 90
    case fps120 = 120
}

extension RenderFrameRate {
    var displayName: String {
        "\(rawValue) FPS"
    }
}

enum IdleBehavior: String, CaseIterable {
    case gather
    case slowOrbit
    case fade
    case freeze
}

extension IdleBehavior {
    var displayName: String {
        switch self {
        case .gather:
            return "Gather"
        case .slowOrbit:
            return "Slow Orbit"
        case .fade:
            return "Fade"
        case .freeze:
            return "Freeze"
        }
    }
}

enum ScaleMode: String, CaseIterable {
    case uniform
    case distanceScale
    case subtleVariation
}

extension ScaleMode {
    var displayName: String {
        switch self {
        case .uniform:
            return "Uniform"
        case .distanceScale:
            return "Scale by Distance"
        case .subtleVariation:
            return "Subtle Variation"
        }
    }
}

enum FlockPreset: String, CaseIterable {
    case balancedFlock
    case migratingV
    case expressiveScatter
    case orbitingSpirits
    case quietWork
    case playfulSwarm
    case presentationMode
    case minimalCompanion
}

extension FlockPreset {
    var displayName: String {
        switch self {
        case .balancedFlock:
            return "Balanced Flock"
        case .migratingV:
            return "Migrating V"
        case .expressiveScatter:
            return "Expressive Scatter"
        case .orbitingSpirits:
            return "Orbiting Spirits"
        case .quietWork:
            return "Quiet Work"
        case .playfulSwarm:
            return "Playful Swarm"
        case .presentationMode:
            return "Presentation Mode"
        case .minimalCompanion:
            return "Minimal Companion"
        }
    }
}

struct ClassicFlockParameters {
    var cohesion: CGFloat
    var separation: CGFloat
    var alignment: CGFloat
    var wander: CGFloat

    init(
        cohesion: CGFloat = 1,
        separation: CGFloat = 1,
        alignment: CGFloat = 1,
        wander: CGFloat = 1
    ) {
        self.cohesion = Self.clampedMultiplier(cohesion)
        self.separation = Self.clampedMultiplier(separation)
        self.alignment = Self.clampedMultiplier(alignment)
        self.wander = Self.clampedMultiplier(wander)
    }

    static func clampedMultiplier(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.35), 2.0)
    }
}

struct VFormationParameters {
    var wingAngleDegrees: CGFloat
    var wingSpacing: CGFloat
    var formationRigidity: CGFloat

    init(
        wingAngleDegrees: CGFloat = 35,
        wingSpacing: CGFloat = 1,
        formationRigidity: CGFloat = 1
    ) {
        self.wingAngleDegrees = min(max(wingAngleDegrees, 18), 58)
        self.wingSpacing = Self.clampedMultiplier(wingSpacing)
        self.formationRigidity = Self.clampedMultiplier(formationRigidity)
    }

    static func clampedMultiplier(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.55), 1.65)
    }
}

struct ScatterAndReturnParameters {
    var scatterSensitivity: CGFloat
    var returnStrength: CGFloat
    var idleCompactness: CGFloat

    init(
        scatterSensitivity: CGFloat = 1,
        returnStrength: CGFloat = 1,
        idleCompactness: CGFloat = 1
    ) {
        self.scatterSensitivity = Self.clampedMultiplier(scatterSensitivity)
        self.returnStrength = Self.clampedMultiplier(returnStrength)
        self.idleCompactness = Self.clampedMultiplier(idleCompactness)
    }

    static func clampedMultiplier(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.45), 1.75)
    }
}

struct OrbitingFlockParameters {
    var orbitRadius: CGFloat
    var orbitSpeed: CGFloat
    var orbitBandCount: Int

    init(
        orbitRadius: CGFloat = 1,
        orbitSpeed: CGFloat = 1,
        orbitBandCount: Int = 2
    ) {
        self.orbitRadius = min(max(orbitRadius, 0.55), 1.55)
        self.orbitSpeed = min(max(orbitSpeed, 0.35), 1.8)
        self.orbitBandCount = min(max(orbitBandCount, 1), 3)
    }
}

struct ScaleSettings {
    var mode: ScaleMode
    var baseScale: CGFloat {
        didSet {
            baseScale = Self.clampedScale(baseScale)
        }
    }
    var minimumScale: CGFloat {
        didSet {
            minimumScale = Self.clampedScale(minimumScale)
        }
    }
    var maximumScale: CGFloat {
        didSet {
            maximumScale = Self.clampedScale(maximumScale)
        }
    }
    var variationAmount: CGFloat {
        didSet {
            variationAmount = min(max(variationAmount, 0), 0.25)
        }
    }

    init(
        mode: ScaleMode = .distanceScale,
        baseScale: CGFloat = 0.92,
        minimumScale: CGFloat = 0.72,
        maximumScale: CGFloat = 1.0,
        variationAmount: CGFloat = 0.08
    ) {
        self.mode = mode
        self.baseScale = Self.clampedScale(baseScale)
        self.minimumScale = Self.clampedScale(minimumScale)
        self.maximumScale = Self.clampedScale(maximumScale)
        self.variationAmount = min(max(variationAmount, 0), 0.25)
    }

    static func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.4), 1.5)
    }
}

struct FlockSettings {
    var enabled: Bool
    var launchAtLoginEnabled: Bool
    var cursorCount: Int {
        didSet {
            cursorCount = Self.clampedCursorCount(cursorCount)
        }
    }
    var maximumRadius: CGFloat {
        didSet {
            maximumRadius = Self.clampedMaximumRadius(maximumRadius)
        }
    }
    var speedSettings: FlockSpeedSettings
    var pattern: FlockPattern
    var orientationMode: OrientationMode
    var rotationStrength: CGFloat {
        didSet {
            rotationStrength = min(max(rotationStrength, 0), 1)
        }
    }
    var turnSmoothing: CGFloat {
        didSet {
            turnSmoothing = min(max(turnSmoothing, 0), 1)
        }
    }
    var baseAxisAdjustmentDegrees: CGFloat
    var rotationEligibilityMode: RotationEligibilityMode
    var opacitySettings: OpacitySettings
    var renderFrameRate: RenderFrameRate
    var idleBehavior: IdleBehavior
    var idleDelaySeconds: TimeInterval {
        didSet {
            idleDelaySeconds = min(max(idleDelaySeconds, 0.25), 5.0)
        }
    }
    var idleMotionScale: CGFloat {
        didSet {
            idleMotionScale = min(max(idleMotionScale, 0), 1)
        }
    }
    var idleFadeOpacity: CGFloat {
        didSet {
            idleFadeOpacity = min(max(idleFadeOpacity, 0), 1)
        }
    }
    var classicParameters: ClassicFlockParameters
    var vFormationParameters: VFormationParameters
    var scatterAndReturnParameters: ScatterAndReturnParameters
    var orbitingFlockParameters: OrbitingFlockParameters
    var scaleSettings: ScaleSettings
    var selectedPreset: FlockPreset?

    init(
        enabled: Bool = true,
        launchAtLoginEnabled: Bool = false,
        cursorCount: Int = 10,
        maximumRadius: CGFloat = 180,
        speedSettings: FlockSpeedSettings = FlockSpeedSettings(),
        pattern: FlockPattern = .classicFlock,
        orientationMode: OrientationMode = .preserveSystemOrientation,
        rotationStrength: CGFloat = 1.0,
        turnSmoothing: CGFloat = 0.18,
        // In AppKit's y-up drawing space, the default macOS arrow tip points upper-left.
        baseAxisAdjustmentDegrees: CGFloat = 135.0,
        rotationEligibilityMode: RotationEligibilityMode = .safeOnly,
        opacitySettings: OpacitySettings = OpacitySettings(),
        renderFrameRate: RenderFrameRate = .fps60,
        idleBehavior: IdleBehavior = .gather,
        idleDelaySeconds: TimeInterval = 1.25,
        idleMotionScale: CGFloat = 0.25,
        idleFadeOpacity: CGFloat = 0.12,
        classicParameters: ClassicFlockParameters = ClassicFlockParameters(),
        vFormationParameters: VFormationParameters = VFormationParameters(),
        scatterAndReturnParameters: ScatterAndReturnParameters = ScatterAndReturnParameters(),
        orbitingFlockParameters: OrbitingFlockParameters = OrbitingFlockParameters(),
        scaleSettings: ScaleSettings = ScaleSettings(),
        selectedPreset: FlockPreset? = nil
    ) {
        self.enabled = enabled
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.cursorCount = Self.clampedCursorCount(cursorCount)
        self.maximumRadius = Self.clampedMaximumRadius(maximumRadius)
        self.speedSettings = speedSettings
        self.pattern = pattern
        self.orientationMode = orientationMode
        self.rotationStrength = min(max(rotationStrength, 0), 1)
        self.turnSmoothing = min(max(turnSmoothing, 0), 1)
        self.baseAxisAdjustmentDegrees = baseAxisAdjustmentDegrees
        self.rotationEligibilityMode = rotationEligibilityMode
        self.opacitySettings = opacitySettings
        self.renderFrameRate = renderFrameRate
        self.idleBehavior = idleBehavior
        self.idleDelaySeconds = min(max(idleDelaySeconds, 0.25), 5.0)
        self.idleMotionScale = min(max(idleMotionScale, 0), 1)
        self.idleFadeOpacity = min(max(idleFadeOpacity, 0), 1)
        self.classicParameters = classicParameters
        self.vFormationParameters = vFormationParameters
        self.scatterAndReturnParameters = scatterAndReturnParameters
        self.orbitingFlockParameters = orbitingFlockParameters
        self.scaleSettings = scaleSettings
        self.selectedPreset = selectedPreset
    }

    static func clampedCursorCount(_ value: Int) -> Int {
        min(max(value, 1), 30)
    }

    static func clampedMaximumRadius(_ value: CGFloat) -> CGFloat {
        min(max(value, 80), 420)
    }
}

struct PresetManager {
    func applying(_ preset: FlockPreset, to currentSettings: FlockSettings) -> FlockSettings {
        var settings = currentSettings
        settings.selectedPreset = preset

        switch preset {
        case .balancedFlock:
            settings.pattern = .classicFlock
            settings.cursorCount = 10
            settings.renderFrameRate = .fps60
            settings.opacitySettings = OpacitySettings(mode: .distanceFade, baseOpacity: 0.85)
            settings.scaleSettings = ScaleSettings(mode: .distanceScale)
            settings.idleBehavior = .gather
            settings.orientationMode = .preserveSystemOrientation
            settings.classicParameters = ClassicFlockParameters()

        case .migratingV:
            settings.pattern = .vFormation
            settings.cursorCount = 10
            settings.vFormationParameters = VFormationParameters(
                wingAngleDegrees: 35,
                wingSpacing: 1,
                formationRigidity: 1
            )
            settings.orientationMode = .alignToGroupDirection
            settings.scaleSettings = ScaleSettings(mode: .uniform, baseScale: 0.92)
            settings.idleBehavior = .gather

        case .expressiveScatter:
            settings.pattern = .scatterAndReturn
            settings.cursorCount = 14
            settings.scatterAndReturnParameters = ScatterAndReturnParameters(
                scatterSensitivity: 1.35,
                returnStrength: 1,
                idleCompactness: 1
            )
            settings.opacitySettings = OpacitySettings(mode: .distanceFade, baseOpacity: 0.85)
            settings.scaleSettings = ScaleSettings(mode: .subtleVariation)
            settings.idleBehavior = .slowOrbit

        case .orbitingSpirits:
            settings.pattern = .orbitingFlock
            settings.cursorCount = 12
            settings.orbitingFlockParameters = OrbitingFlockParameters(
                orbitRadius: 1,
                orbitSpeed: 0.65,
                orbitBandCount: 2
            )
            settings.opacitySettings = OpacitySettings(mode: .distanceFade, baseOpacity: 0.78)
            settings.scaleSettings = ScaleSettings(mode: .distanceScale)
            settings.idleBehavior = .slowOrbit

        case .quietWork:
            settings.pattern = .classicFlock
            settings.cursorCount = 5
            settings.renderFrameRate = .fps60
            settings.opacitySettings = OpacitySettings(mode: .distanceFade, baseOpacity: 0.55)
            settings.scaleSettings = ScaleSettings(mode: .uniform, baseScale: 0.85)
            settings.idleBehavior = .fade
            settings.orientationMode = .preserveSystemOrientation
            settings.classicParameters = ClassicFlockParameters(wander: 0.65)

        case .playfulSwarm:
            settings.pattern = .classicFlock
            settings.cursorCount = 18
            settings.classicParameters = ClassicFlockParameters(separation: 1, wander: 1.45)
            settings.scaleSettings = ScaleSettings(mode: .subtleVariation)
            settings.idleBehavior = .slowOrbit
            settings.opacitySettings = OpacitySettings(mode: .distanceFade, baseOpacity: 0.85)

        case .presentationMode:
            settings.pattern = .vFormation
            settings.cursorCount = 16
            settings.renderFrameRate = .fps90
            settings.opacitySettings = OpacitySettings(mode: .solid, baseOpacity: 1)
            settings.scaleSettings = ScaleSettings(mode: .uniform, baseScale: 1.0)
            settings.orientationMode = .alignToGroupDirection
            settings.idleBehavior = .slowOrbit

        case .minimalCompanion:
            settings.pattern = .classicFlock
            settings.cursorCount = 2
            settings.renderFrameRate = .fps30
            settings.opacitySettings = OpacitySettings(mode: .distanceFade, baseOpacity: 0.62)
            settings.scaleSettings = ScaleSettings(mode: .uniform, baseScale: 0.85)
            settings.idleBehavior = .fade
            settings.orientationMode = .preserveSystemOrientation
            settings.classicParameters = ClassicFlockParameters(wander: 0.65)
        }

        return settings
    }
}
