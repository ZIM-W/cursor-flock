import CoreGraphics
import Foundation

final class SettingsStore {
    private enum Key {
        static let schemaVersion = "settings.schemaVersion"
        static let enabled = "settings.enabled"
        static let launchAtLoginEnabled = "settings.launchAtLoginEnabled"
        static let cursorCount = "settings.cursorCount"
        static let maximumRadius = "settings.maximumRadius"
        static let maximumSpeed = "settings.speed.maximumSpeed"
        static let minimumSpeedRatio = "settings.speed.minimumSpeedRatio"
        static let speedVariation = "settings.speed.variation"
        static let pattern = "settings.pattern"
        static let frameRate = "settings.frameRate"
        static let opacityMode = "settings.opacityMode"
        static let baseOpacity = "settings.baseOpacity"
        static let minimumOpacity = "settings.minimumOpacity"
        static let fadeExponent = "settings.fadeExponent"
        static let orientationMode = "settings.orientationMode"
        static let rotationStrength = "settings.rotationStrength"
        static let turnSmoothing = "settings.turnSmoothing"
        static let baseAxisAdjustmentDegrees = "settings.baseAxisAdjustmentDegrees"
        static let rotationPolicy = "settings.rotationPolicy"
        static let idleBehavior = "settings.idleBehavior"
        static let idleDelaySeconds = "settings.idleDelaySeconds"
        static let idleMotionScale = "settings.idleMotionScale"
        static let idleFadeOpacity = "settings.idleFadeOpacity"
        static let classicCohesion = "settings.classic.cohesion"
        static let classicSeparation = "settings.classic.separation"
        static let classicAlignment = "settings.classic.alignment"
        static let classicWander = "settings.classic.wander"
        static let vWingAngle = "settings.v.wingAngle"
        static let vWingSpacing = "settings.v.wingSpacing"
        static let vRigidity = "settings.v.rigidity"
        static let scatterSensitivity = "settings.scatter.sensitivity"
        static let scatterReturnStrength = "settings.scatter.returnStrength"
        static let scatterIdleCompactness = "settings.scatter.idleCompactness"
        static let orbitRadius = "settings.orbit.radius"
        static let orbitSpeed = "settings.orbit.speed"
        static let orbitBandCount = "settings.orbit.bandCount"
        static let scaleMode = "settings.scale.mode"
        static let baseScale = "settings.scale.baseScale"
        static let minimumScale = "settings.scale.minimumScale"
        static let maximumScale = "settings.scale.maximumScale"
        static let variationAmount = "settings.scale.variationAmount"
        static let selectedPreset = "settings.selectedPreset"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> FlockSettings {
        let defaultsSettings = FlockSettings()
        let speedSettings = FlockSpeedSettings(
            maximumSpeed: cgFloat(Key.maximumSpeed, defaultValue: defaultsSettings.speedSettings.maximumSpeed),
            minimumSpeedRatio: cgFloat(
                Key.minimumSpeedRatio,
                defaultValue: defaultsSettings.speedSettings.minimumSpeedRatio
            ),
            speedVariation: cgFloat(Key.speedVariation, defaultValue: defaultsSettings.speedSettings.speedVariation)
        )
        let opacitySettings = OpacitySettings(
            mode: stringEnum(Key.opacityMode, defaultValue: defaultsSettings.opacitySettings.mode),
            baseOpacity: cgFloat(Key.baseOpacity, defaultValue: defaultsSettings.opacitySettings.baseOpacity),
            minimumOpacity: cgFloat(Key.minimumOpacity, defaultValue: defaultsSettings.opacitySettings.minimumOpacity),
            fadeExponent: cgFloat(Key.fadeExponent, defaultValue: defaultsSettings.opacitySettings.fadeExponent)
        )
        let classic = ClassicFlockParameters(
            cohesion: cgFloat(Key.classicCohesion, defaultValue: defaultsSettings.classicParameters.cohesion),
            separation: cgFloat(Key.classicSeparation, defaultValue: defaultsSettings.classicParameters.separation),
            alignment: cgFloat(Key.classicAlignment, defaultValue: defaultsSettings.classicParameters.alignment),
            wander: cgFloat(Key.classicWander, defaultValue: defaultsSettings.classicParameters.wander)
        )
        let vFormation = VFormationParameters(
            wingAngleDegrees: cgFloat(Key.vWingAngle, defaultValue: defaultsSettings.vFormationParameters.wingAngleDegrees),
            wingSpacing: cgFloat(Key.vWingSpacing, defaultValue: defaultsSettings.vFormationParameters.wingSpacing),
            formationRigidity: cgFloat(Key.vRigidity, defaultValue: defaultsSettings.vFormationParameters.formationRigidity)
        )
        let scatter = ScatterAndReturnParameters(
            scatterSensitivity: cgFloat(
                Key.scatterSensitivity,
                defaultValue: defaultsSettings.scatterAndReturnParameters.scatterSensitivity
            ),
            returnStrength: cgFloat(
                Key.scatterReturnStrength,
                defaultValue: defaultsSettings.scatterAndReturnParameters.returnStrength
            ),
            idleCompactness: cgFloat(
                Key.scatterIdleCompactness,
                defaultValue: defaultsSettings.scatterAndReturnParameters.idleCompactness
            )
        )
        let orbit = OrbitingFlockParameters(
            orbitRadius: cgFloat(Key.orbitRadius, defaultValue: defaultsSettings.orbitingFlockParameters.orbitRadius),
            orbitSpeed: cgFloat(Key.orbitSpeed, defaultValue: defaultsSettings.orbitingFlockParameters.orbitSpeed),
            orbitBandCount: int(Key.orbitBandCount, defaultValue: defaultsSettings.orbitingFlockParameters.orbitBandCount)
        )
        let scale = ScaleSettings(
            mode: stringEnum(Key.scaleMode, defaultValue: defaultsSettings.scaleSettings.mode),
            baseScale: cgFloat(Key.baseScale, defaultValue: defaultsSettings.scaleSettings.baseScale),
            minimumScale: cgFloat(Key.minimumScale, defaultValue: defaultsSettings.scaleSettings.minimumScale),
            maximumScale: cgFloat(Key.maximumScale, defaultValue: defaultsSettings.scaleSettings.maximumScale),
            variationAmount: cgFloat(Key.variationAmount, defaultValue: defaultsSettings.scaleSettings.variationAmount)
        )

        return FlockSettings(
            enabled: bool(Key.enabled, defaultValue: defaultsSettings.enabled),
            launchAtLoginEnabled: bool(
                Key.launchAtLoginEnabled,
                defaultValue: defaultsSettings.launchAtLoginEnabled
            ),
            cursorCount: int(Key.cursorCount, defaultValue: defaultsSettings.cursorCount),
            maximumRadius: cgFloat(Key.maximumRadius, defaultValue: defaultsSettings.maximumRadius),
            speedSettings: speedSettings,
            pattern: stringEnum(Key.pattern, defaultValue: defaultsSettings.pattern),
            orientationMode: stringEnum(Key.orientationMode, defaultValue: defaultsSettings.orientationMode),
            rotationStrength: cgFloat(Key.rotationStrength, defaultValue: defaultsSettings.rotationStrength),
            turnSmoothing: cgFloat(Key.turnSmoothing, defaultValue: defaultsSettings.turnSmoothing),
            baseAxisAdjustmentDegrees: cgFloat(
                Key.baseAxisAdjustmentDegrees,
                defaultValue: defaultsSettings.baseAxisAdjustmentDegrees
            ),
            rotationEligibilityMode: stringEnum(Key.rotationPolicy, defaultValue: defaultsSettings.rotationEligibilityMode),
            opacitySettings: opacitySettings,
            renderFrameRate: intEnum(Key.frameRate, defaultValue: defaultsSettings.renderFrameRate),
            idleBehavior: stringEnum(Key.idleBehavior, defaultValue: defaultsSettings.idleBehavior),
            idleDelaySeconds: timeInterval(Key.idleDelaySeconds, defaultValue: defaultsSettings.idleDelaySeconds),
            idleMotionScale: cgFloat(Key.idleMotionScale, defaultValue: defaultsSettings.idleMotionScale),
            idleFadeOpacity: cgFloat(Key.idleFadeOpacity, defaultValue: defaultsSettings.idleFadeOpacity),
            classicParameters: classic,
            vFormationParameters: vFormation,
            scatterAndReturnParameters: scatter,
            orbitingFlockParameters: orbit,
            scaleSettings: scale,
            selectedPreset: optionalStringEnum(Key.selectedPreset)
        )
    }

    func save(_ settings: FlockSettings) {
        defaults.set(2, forKey: Key.schemaVersion)
        defaults.set(settings.enabled, forKey: Key.enabled)
        defaults.set(settings.launchAtLoginEnabled, forKey: Key.launchAtLoginEnabled)
        defaults.set(settings.cursorCount, forKey: Key.cursorCount)
        defaults.set(Double(settings.maximumRadius), forKey: Key.maximumRadius)
        defaults.set(Double(settings.speedSettings.maximumSpeed), forKey: Key.maximumSpeed)
        defaults.set(Double(settings.speedSettings.minimumSpeedRatio), forKey: Key.minimumSpeedRatio)
        defaults.set(Double(settings.speedSettings.speedVariation), forKey: Key.speedVariation)
        defaults.set(settings.pattern.rawValue, forKey: Key.pattern)
        defaults.set(settings.renderFrameRate.rawValue, forKey: Key.frameRate)
        defaults.set(settings.opacitySettings.mode.rawValue, forKey: Key.opacityMode)
        defaults.set(Double(settings.opacitySettings.baseOpacity), forKey: Key.baseOpacity)
        defaults.set(Double(settings.opacitySettings.minimumOpacity), forKey: Key.minimumOpacity)
        defaults.set(Double(settings.opacitySettings.fadeExponent), forKey: Key.fadeExponent)
        defaults.set(settings.orientationMode.rawValue, forKey: Key.orientationMode)
        defaults.set(Double(settings.rotationStrength), forKey: Key.rotationStrength)
        defaults.set(Double(settings.turnSmoothing), forKey: Key.turnSmoothing)
        defaults.set(Double(settings.baseAxisAdjustmentDegrees), forKey: Key.baseAxisAdjustmentDegrees)
        defaults.set(settings.rotationEligibilityMode.rawValue, forKey: Key.rotationPolicy)
        defaults.set(settings.idleBehavior.rawValue, forKey: Key.idleBehavior)
        defaults.set(settings.idleDelaySeconds, forKey: Key.idleDelaySeconds)
        defaults.set(Double(settings.idleMotionScale), forKey: Key.idleMotionScale)
        defaults.set(Double(settings.idleFadeOpacity), forKey: Key.idleFadeOpacity)
        defaults.set(Double(settings.classicParameters.cohesion), forKey: Key.classicCohesion)
        defaults.set(Double(settings.classicParameters.separation), forKey: Key.classicSeparation)
        defaults.set(Double(settings.classicParameters.alignment), forKey: Key.classicAlignment)
        defaults.set(Double(settings.classicParameters.wander), forKey: Key.classicWander)
        defaults.set(Double(settings.vFormationParameters.wingAngleDegrees), forKey: Key.vWingAngle)
        defaults.set(Double(settings.vFormationParameters.wingSpacing), forKey: Key.vWingSpacing)
        defaults.set(Double(settings.vFormationParameters.formationRigidity), forKey: Key.vRigidity)
        defaults.set(Double(settings.scatterAndReturnParameters.scatterSensitivity), forKey: Key.scatterSensitivity)
        defaults.set(Double(settings.scatterAndReturnParameters.returnStrength), forKey: Key.scatterReturnStrength)
        defaults.set(Double(settings.scatterAndReturnParameters.idleCompactness), forKey: Key.scatterIdleCompactness)
        defaults.set(Double(settings.orbitingFlockParameters.orbitRadius), forKey: Key.orbitRadius)
        defaults.set(Double(settings.orbitingFlockParameters.orbitSpeed), forKey: Key.orbitSpeed)
        defaults.set(settings.orbitingFlockParameters.orbitBandCount, forKey: Key.orbitBandCount)
        defaults.set(settings.scaleSettings.mode.rawValue, forKey: Key.scaleMode)
        defaults.set(Double(settings.scaleSettings.baseScale), forKey: Key.baseScale)
        defaults.set(Double(settings.scaleSettings.minimumScale), forKey: Key.minimumScale)
        defaults.set(Double(settings.scaleSettings.maximumScale), forKey: Key.maximumScale)
        defaults.set(Double(settings.scaleSettings.variationAmount), forKey: Key.variationAmount)
        if let selectedPreset = settings.selectedPreset {
            defaults.set(selectedPreset.rawValue, forKey: Key.selectedPreset)
        } else {
            defaults.removeObject(forKey: Key.selectedPreset)
        }
    }

    func resetToDefaults() -> FlockSettings {
        let settings = FlockSettings()
        save(settings)
        return settings
    }

    private func bool(_ key: String, defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    private func int(_ key: String, defaultValue: Int) -> Int {
        defaults.object(forKey: key) as? Int ?? defaultValue
    }

    private func cgFloat(_ key: String, defaultValue: CGFloat) -> CGFloat {
        guard let number = defaults.object(forKey: key) as? NSNumber else {
            return defaultValue
        }
        return CGFloat(number.doubleValue)
    }

    private func timeInterval(_ key: String, defaultValue: TimeInterval) -> TimeInterval {
        guard let number = defaults.object(forKey: key) as? NSNumber else {
            return defaultValue
        }
        return number.doubleValue
    }

    private func stringEnum<T: RawRepresentable>(
        _ key: String,
        defaultValue: T
    ) -> T where T.RawValue == String {
        guard let rawValue = defaults.object(forKey: key) as? String,
              let value = T(rawValue: rawValue) else {
            return defaultValue
        }
        return value
    }

    private func intEnum<T: RawRepresentable>(
        _ key: String,
        defaultValue: T
    ) -> T where T.RawValue == Int {
        guard let rawValue = defaults.object(forKey: key) as? Int,
              let value = T(rawValue: rawValue) else {
            return defaultValue
        }
        return value
    }

    private func optionalStringEnum<T: RawRepresentable>(_ key: String) -> T? where T.RawValue == String {
        guard let rawValue = defaults.object(forKey: key) as? String else {
            return nil
        }
        return T(rawValue: rawValue)
    }
}
