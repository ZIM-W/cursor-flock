import CoreGraphics
import Foundation

final class Settings {
    private let store: SettingsStore

    var flockSettings: FlockSettings
    var showCursorDebugOverlay = false
    var showOrientationDebug = false

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        flockSettings = store.load()
    }

    var targetFramesPerSecond: TimeInterval {
        TimeInterval(flockSettings.renderFrameRate.rawValue)
    }

    let cursorHeight: CGFloat = 23
    let flockParameters = FlockParameters()

    var isEnabled: Bool {
        get {
            flockSettings.enabled
        }
        set {
            flockSettings.enabled = newValue
        }
    }

    var cursorCount: Int {
        get {
            flockSettings.cursorCount
        }
        set {
            flockSettings.cursorCount = newValue
        }
    }

    var pattern: FlockPattern {
        get {
            flockSettings.pattern
        }
        set {
            flockSettings.pattern = newValue
        }
    }

    var orientationMode: OrientationMode {
        get {
            flockSettings.orientationMode
        }
        set {
            flockSettings.orientationMode = newValue
        }
    }

    var rotationStrength: CGFloat {
        get {
            flockSettings.rotationStrength
        }
        set {
            flockSettings.rotationStrength = newValue
        }
    }

    var rotationEligibilityMode: RotationEligibilityMode {
        get {
            flockSettings.rotationEligibilityMode
        }
        set {
            flockSettings.rotationEligibilityMode = newValue
        }
    }

    var opacityMode: OpacityMode {
        get {
            flockSettings.opacitySettings.mode
        }
        set {
            flockSettings.opacitySettings.mode = newValue
        }
    }

    var baseOpacity: CGFloat {
        get {
            flockSettings.opacitySettings.baseOpacity
        }
        set {
            flockSettings.opacitySettings.baseOpacity = newValue
        }
    }

    var renderFrameRate: RenderFrameRate {
        get {
            flockSettings.renderFrameRate
        }
        set {
            flockSettings.renderFrameRate = newValue
        }
    }

    var cursorColorMode: CursorColorMode {
        get {
            flockSettings.cursorColorMode
        }
        set {
            flockSettings.cursorColorMode = newValue
        }
    }

    func save() {
        store.save(flockSettings)
    }

    func resetToDefaults() {
        flockSettings = store.resetToDefaults()
    }
}
