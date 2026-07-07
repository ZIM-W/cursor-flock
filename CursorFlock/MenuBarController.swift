import AppKit
import ServiceManagement

@MainActor
final class MenuBarController: NSObject {
    private struct ParameterChoice: Equatable {
        let key: String
        let value: CGFloat
        let intValue: Int?

        init(_ key: String, _ value: CGFloat) {
            self.key = key
            self.value = value
            intValue = nil
        }

        init(_ key: String, intValue: Int) {
            self.key = key
            value = CGFloat(intValue)
            self.intValue = intValue
        }
    }

    private let settings: Settings
    private let launchAtLoginManager: LaunchAtLoginManager
    private let presetManager = PresetManager()
    private let onEnabledChanged: (Bool) -> Void
    private let onFrameRateChanged: () -> Void
    private let onSettingsChanged: () -> Void
    private let onResetDefaults: () -> Void
    private let onQuit: () -> Void

    private var statusItem: NSStatusItem?
    private weak var enableItem: NSMenuItem?
    private weak var launchAtLoginItem: NSMenuItem?
    private var launchAtLoginStatusItem: NSMenuItem?
    private var launchAtLoginMessage: String?
    private var presetItems: [NSMenuItem] = []
    private var patternItems: [NSMenuItem] = []
    private var patternParameterItems: [NSMenuItem] = []
    private var cursorCountItems: [NSMenuItem] = []
    private var flockDistanceItems: [NSMenuItem] = []
    private var flockSpeedItems: [NSMenuItem] = []
    private var speedVariationItems: [NSMenuItem] = []
    private var frameRateItems: [NSMenuItem] = []
    private var opacityModeItems: [NSMenuItem] = []
    private var baseOpacityItems: [NSMenuItem] = []
    private var scaleModeItems: [NSMenuItem] = []
    private var baseScaleItems: [NSMenuItem] = []
    private var depthStrengthItems: [NSMenuItem] = []
    private var orientationItems: [NSMenuItem] = []
    private var rotationStrengthItems: [NSMenuItem] = []
    private var rotationPolicyItems: [NSMenuItem] = []
    private var idleBehaviorItems: [NSMenuItem] = []

    init(
        settings: Settings,
        launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager(),
        onEnabledChanged: @escaping (Bool) -> Void,
        onFrameRateChanged: @escaping () -> Void,
        onSettingsChanged: @escaping () -> Void,
        onResetDefaults: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.settings = settings
        self.launchAtLoginManager = launchAtLoginManager
        self.onEnabledChanged = onEnabledChanged
        self.onFrameRateChanged = onFrameRateChanged
        self.onSettingsChanged = onSettingsChanged
        self.onResetDefaults = onResetDefaults
        self.onQuit = onQuit
        super.init()
        configureStatusItem()
        rebuildMenu()
    }

    func updateMenuState() {
        enableItem?.state = settings.isEnabled ? .on : .off
        statusItem?.button?.alphaValue = settings.isEnabled ? 1 : 0.55
        updateLaunchAtLoginState()

        for item in presetItems {
            item.state = representedValue(item) == settings.flockSettings.selectedPreset ? .on : .off
        }
        for item in patternItems {
            item.state = representedValue(item) == settings.pattern ? .on : .off
        }
        for item in patternParameterItems {
            guard let choice: ParameterChoice = representedValue(item) else {
                continue
            }
            item.state = isActivePatternParameter(choice) ? .on : .off
        }
        for item in cursorCountItems {
            item.state = representedValue(item) == settings.cursorCount ? .on : .off
        }
        for item in flockDistanceItems {
            item.state = representedValue(item) == FlockDistancePreset.matching(
                maximumRadius: settings.flockSettings.maximumRadius
            ) ? .on : .off
        }
        for item in flockSpeedItems {
            item.state = representedValue(item) == FlockSpeedPreset.matching(
                maximumSpeed: settings.flockSettings.speedSettings.maximumSpeed
            ) ? .on : .off
        }
        for item in speedVariationItems {
            item.state = representedValue(item) == SpeedVariationPreset.matching(
                settings: settings.flockSettings.speedSettings
            ) ? .on : .off
        }
        for item in frameRateItems {
            item.state = representedValue(item) == settings.renderFrameRate ? .on : .off
        }
        for item in opacityModeItems {
            item.state = representedValue(item) == settings.opacityMode ? .on : .off
        }
        for item in baseOpacityItems {
            guard let value: CGFloat = representedValue(item) else {
                continue
            }
            item.state = approximately(value, settings.baseOpacity) ? .on : .off
        }
        for item in scaleModeItems {
            item.state = representedValue(item) == settings.flockSettings.scaleSettings.mode ? .on : .off
        }
        for item in baseScaleItems {
            guard let value: CGFloat = representedValue(item) else {
                continue
            }
            item.state = approximately(value, settings.flockSettings.scaleSettings.baseScale) ? .on : .off
        }
        for item in depthStrengthItems {
            guard let choice: ParameterChoice = representedValue(item) else {
                continue
            }
            item.state = isActiveDepthChoice(choice) ? .on : .off
        }
        for item in orientationItems {
            item.state = representedValue(item) == settings.orientationMode ? .on : .off
        }
        for item in rotationStrengthItems {
            guard let value: CGFloat = representedValue(item) else {
                continue
            }
            item.state = approximately(value, settings.rotationStrength) ? .on : .off
        }
        for item in rotationPolicyItems {
            item.state = representedValue(item) == settings.rotationEligibilityMode ? .on : .off
        }
        for item in idleBehaviorItems {
            item.state = representedValue(item) == settings.flockSettings.idleBehavior ? .on : .off
        }
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.title = ""
            let icon = Self.makeStatusIcon()
            icon.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageOnly
            button.alphaValue = 1
            button.toolTip = "Cursor Flock"
        }
    }

    private func rebuildMenu() {
        presetItems = []
        patternItems = []
        patternParameterItems = []
        cursorCountItems = []
        flockDistanceItems = []
        flockSpeedItems = []
        speedVariationItems = []
        frameRateItems = []
        opacityModeItems = []
        baseOpacityItems = []
        scaleModeItems = []
        baseScaleItems = []
        depthStrengthItems = []
        orientationItems = []
        rotationStrengthItems = []
        rotationPolicyItems = []
        idleBehaviorItems = []

        let menu = NSMenu()
        menu.autoenablesItems = false
        let titleItem = NSMenuItem(title: "Cursor Flock", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let enableItem = NSMenuItem(
            title: "Enable Cursor Flock",
            action: #selector(toggleCursorFlock),
            keyEquivalent: ""
        )
        enableItem.target = self
        menu.addItem(enableItem)
        self.enableItem = enableItem
        menu.addItem(makeLaunchAtLoginItem())
        if let launchAtLoginStatusItem {
            menu.addItem(launchAtLoginStatusItem)
        }

        menu.addItem(.separator())
        menu.addItem(makePresetItem())
        menu.addItem(makePatternItem())
        menu.addItem(makePatternParametersItem())
        menu.addItem(makeCursorCountItem())
        menu.addItem(makeFlockDistanceItem())
        menu.addItem(makeFlockSpeedItem())
        menu.addItem(makeSpeedVariationItem())
        menu.addItem(makeFrameRateItem())
        menu.addItem(.separator())
        menu.addItem(makeOpacityItem())
        menu.addItem(makeBaseOpacityItem())
        menu.addItem(makeScaleItem())
        menu.addItem(.separator())
        menu.addItem(makeOrientationItem())
        menu.addItem(makeRotationStrengthItem())
        menu.addItem(makeRotationPolicyItem())
        menu.addItem(makeIdleBehaviorItem())
        menu.addItem(.separator())

        let resetItem = NSMenuItem(
            title: "Restore Default Settings",
            action: #selector(restoreDefaults),
            keyEquivalent: ""
        )
        resetItem.target = self
        menu.addItem(resetItem)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        updateMenuState()
    }

    @objc private func toggleCursorFlock() {
        onEnabledChanged(!settings.isEnabled)
        persistAndRefresh()
    }

    @objc private func toggleLaunchAtLogin() {
        let status = launchAtLoginManager.currentStatus()
        let shouldEnable: Bool

        if status == .enabled {
            shouldEnable = false
        } else if settings.flockSettings.launchAtLoginEnabled, status == .requiresApproval {
            shouldEnable = false
        } else {
            shouldEnable = true
        }

        settings.flockSettings.launchAtLoginEnabled = shouldEnable
        do {
            try launchAtLoginManager.setEnabled(shouldEnable)
            launchAtLoginMessage = nil
        } catch {
            launchAtLoginMessage = "Launch at Login: \(error.localizedDescription)"
        }
        persistAndRefresh()
    }

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let preset: FlockPreset = representedValue(sender) else {
            return
        }

        settings.flockSettings = presetManager.applying(preset, to: settings.flockSettings)
        onFrameRateChanged()
        rebuildMenu()
        persistAndRefresh()
    }

    @objc private func setPattern(_ sender: NSMenuItem) {
        guard let pattern: FlockPattern = representedValue(sender) else {
            return
        }

        settings.pattern = pattern
        settings.flockSettings.selectedPreset = nil
        rebuildMenu()
        persistAndRefresh()
    }

    @objc private func setPatternParameter(_ sender: NSMenuItem) {
        guard let choice: ParameterChoice = representedValue(sender) else {
            return
        }

        applyPatternParameter(choice)
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setCursorCount(_ sender: NSMenuItem) {
        guard let count: Int = representedValue(sender) else {
            return
        }

        settings.cursorCount = count
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setFlockDistance(_ sender: NSMenuItem) {
        guard let preset: FlockDistancePreset = representedValue(sender) else {
            return
        }

        settings.flockSettings.maximumRadius = preset.maximumRadius
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setFlockSpeed(_ sender: NSMenuItem) {
        guard let preset: FlockSpeedPreset = representedValue(sender) else {
            return
        }

        settings.flockSettings.speedSettings.maximumSpeed = preset.maximumSpeed
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setSpeedVariation(_ sender: NSMenuItem) {
        guard let preset: SpeedVariationPreset = representedValue(sender) else {
            return
        }

        settings.flockSettings.speedSettings.minimumSpeedRatio = preset.minimumSpeedRatio
        settings.flockSettings.speedSettings.speedVariation = preset.speedVariation
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setFrameRate(_ sender: NSMenuItem) {
        guard let frameRate: RenderFrameRate = representedValue(sender) else {
            return
        }

        settings.renderFrameRate = frameRate
        settings.flockSettings.selectedPreset = nil
        onFrameRateChanged()
        persistAndRefresh()
    }

    @objc private func setOpacityMode(_ sender: NSMenuItem) {
        guard let opacityMode: OpacityMode = representedValue(sender) else {
            return
        }

        settings.opacityMode = opacityMode
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setBaseOpacity(_ sender: NSMenuItem) {
        guard let opacity: CGFloat = representedValue(sender) else {
            return
        }

        settings.baseOpacity = opacity
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setScaleMode(_ sender: NSMenuItem) {
        guard let scaleMode: ScaleMode = representedValue(sender) else {
            return
        }

        settings.flockSettings.scaleSettings.mode = scaleMode
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setBaseScale(_ sender: NSMenuItem) {
        guard let scale: CGFloat = representedValue(sender) else {
            return
        }

        settings.flockSettings.scaleSettings.baseScale = scale
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setDepthStrength(_ sender: NSMenuItem) {
        guard let choice: ParameterChoice = representedValue(sender) else {
            return
        }

        applyDepthChoice(choice)
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setOrientationMode(_ sender: NSMenuItem) {
        guard let orientationMode: OrientationMode = representedValue(sender) else {
            return
        }

        settings.orientationMode = orientationMode
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setRotationStrength(_ sender: NSMenuItem) {
        guard let strength: CGFloat = representedValue(sender) else {
            return
        }

        settings.rotationStrength = strength
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setRotationPolicy(_ sender: NSMenuItem) {
        guard let policy: RotationEligibilityMode = representedValue(sender) else {
            return
        }

        settings.rotationEligibilityMode = policy
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func setIdleBehavior(_ sender: NSMenuItem) {
        guard let behavior: IdleBehavior = representedValue(sender) else {
            return
        }

        settings.flockSettings.idleBehavior = behavior
        settings.flockSettings.selectedPreset = nil
        persistAndRefresh()
    }

    @objc private func restoreDefaults() {
        onResetDefaults()
        do {
            try launchAtLoginManager.setEnabled(settings.flockSettings.launchAtLoginEnabled)
            launchAtLoginMessage = nil
        } catch {
            launchAtLoginMessage = "Launch at Login: \(error.localizedDescription)"
        }
        rebuildMenu()
    }

    @objc private func quit() {
        onSettingsChanged()
        onQuit()
    }

    private func persistAndRefresh() {
        onSettingsChanged()
        updateMenuState()
    }

    private func updateLaunchAtLoginState() {
        let status = launchAtLoginManager.currentStatus()
        launchAtLoginItem?.state = status == .enabled ? .on : .off
        if status == .enabled {
            launchAtLoginMessage = nil
        }

        let statusMessage = launchAtLoginMessage
            ?? launchAtLoginManager.menuStatusMessage(for: status)
        launchAtLoginStatusItem?.title = statusMessage ?? ""
        launchAtLoginStatusItem?.isHidden = statusMessage == nil
    }

    private func makeLaunchAtLoginItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        item.target = self
        launchAtLoginItem = item

        let statusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        statusItem.isHidden = true
        launchAtLoginStatusItem = statusItem

        return item
    }

    private func makePresetItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Quick Presets", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        presetItems = FlockPreset.allCases.map { preset in
            makeMenuItem(title: preset.displayName, action: #selector(applyPreset), value: preset)
        }
        presetItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makePatternItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Pattern", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        patternItems = FlockPattern.allCases.map { pattern in
            makeMenuItem(title: pattern.displayName, action: #selector(setPattern), value: pattern)
        }
        patternItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makePatternParametersItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Pattern Parameters", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        switch settings.pattern {
        case .classicFlock:
            addChoiceGroup(
                title: "Cohesion",
                choices: [
                    ("Low", ParameterChoice("classic.cohesion", 0.75)),
                    ("Medium", ParameterChoice("classic.cohesion", 1.0)),
                    ("High", ParameterChoice("classic.cohesion", 1.25))
                ],
                to: submenu
            )
            addChoiceGroup(
                title: "Separation",
                choices: [
                    ("Low", ParameterChoice("classic.separation", 0.75)),
                    ("Medium", ParameterChoice("classic.separation", 1.0)),
                    ("High", ParameterChoice("classic.separation", 1.25))
                ],
                to: submenu
            )
            addChoiceGroup(
                title: "Wander",
                choices: [
                    ("Calm", ParameterChoice("classic.wander", 0.65)),
                    ("Natural", ParameterChoice("classic.wander", 1.0)),
                    ("Playful", ParameterChoice("classic.wander", 1.45))
                ],
                to: submenu
            )

        case .vFormation:
            addChoiceGroup(
                title: "Wing Angle",
                choices: [
                    ("Narrow", ParameterChoice("v.angle", 26)),
                    ("Standard", ParameterChoice("v.angle", 35)),
                    ("Wide", ParameterChoice("v.angle", 46))
                ],
                to: submenu
            )
            addChoiceGroup(
                title: "Wing Spacing",
                choices: [
                    ("Tight", ParameterChoice("v.spacing", 0.82)),
                    ("Medium", ParameterChoice("v.spacing", 1.0)),
                    ("Wide", ParameterChoice("v.spacing", 1.22))
                ],
                to: submenu
            )
            addChoiceGroup(
                title: "Formation Rigidity",
                choices: [
                    ("Soft", ParameterChoice("v.rigidity", 0.75)),
                    ("Balanced", ParameterChoice("v.rigidity", 1.0)),
                    ("Strong", ParameterChoice("v.rigidity", 1.32))
                ],
                to: submenu
            )

        case .scatterAndReturn:
            addChoiceGroup(
                title: "Scatter Sensitivity",
                choices: [
                    ("Low", ParameterChoice("scatter.sensitivity", 0.75)),
                    ("Medium", ParameterChoice("scatter.sensitivity", 1.0)),
                    ("High", ParameterChoice("scatter.sensitivity", 1.35))
                ],
                to: submenu
            )
            addChoiceGroup(
                title: "Return Speed",
                choices: [
                    ("Gentle", ParameterChoice("scatter.return", 0.78)),
                    ("Balanced", ParameterChoice("scatter.return", 1.0)),
                    ("Fast", ParameterChoice("scatter.return", 1.32))
                ],
                to: submenu
            )
            addChoiceGroup(
                title: "Idle Compactness",
                choices: [
                    ("Loose", ParameterChoice("scatter.idleCompactness", 0.75)),
                    ("Balanced", ParameterChoice("scatter.idleCompactness", 1.0)),
                    ("Tight", ParameterChoice("scatter.idleCompactness", 1.35))
                ],
                to: submenu
            )

        case .orbitingFlock:
            addChoiceGroup(
                title: "Orbit Radius",
                choices: [
                    ("Small", ParameterChoice("orbit.radius", 0.78)),
                    ("Medium", ParameterChoice("orbit.radius", 1.0)),
                    ("Large", ParameterChoice("orbit.radius", 1.24))
                ],
                to: submenu
            )
            addChoiceGroup(
                title: "Orbit Speed",
                choices: [
                    ("Slow", ParameterChoice("orbit.speed", 0.65)),
                    ("Medium", ParameterChoice("orbit.speed", 1.0)),
                    ("Fast", ParameterChoice("orbit.speed", 1.35))
                ],
                to: submenu
            )
            addChoiceGroup(
                title: "Orbit Bands",
                choices: [
                    ("1", ParameterChoice("orbit.bands", intValue: 1)),
                    ("2", ParameterChoice("orbit.bands", intValue: 2)),
                    ("3", ParameterChoice("orbit.bands", intValue: 3))
                ],
                to: submenu
            )
        }

        item.submenu = submenu
        return item
    }

    private func addChoiceGroup(
        title: String,
        choices: [(String, ParameterChoice)],
        to menu: NSMenu
    ) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for choice in choices {
            let menuItem = makeMenuItem(
                title: choice.0,
                action: #selector(setPatternParameter),
                value: choice.1
            )
            patternParameterItems.append(menuItem)
            submenu.addItem(menuItem)
        }
        item.submenu = submenu
        menu.addItem(item)
    }

    private func makeCursorCountItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Cursor Count", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        cursorCountItems = [1, 3, 5, 8, 10, 15, 20, 30].map { count in
            makeMenuItem(title: "\(count)", action: #selector(setCursorCount), value: count)
        }
        cursorCountItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makeFlockDistanceItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Flock Distance", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        flockDistanceItems = FlockDistancePreset.allCases.map { preset in
            makeMenuItem(title: preset.displayName, action: #selector(setFlockDistance), value: preset)
        }
        flockDistanceItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makeFlockSpeedItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Flock Speed", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        flockSpeedItems = FlockSpeedPreset.allCases.map { preset in
            makeMenuItem(title: preset.displayName, action: #selector(setFlockSpeed), value: preset)
        }
        flockSpeedItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makeSpeedVariationItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Speed Variation", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        speedVariationItems = SpeedVariationPreset.allCases.map { preset in
            makeMenuItem(title: preset.displayName, action: #selector(setSpeedVariation), value: preset)
        }
        speedVariationItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makeFrameRateItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Frame Rate", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        frameRateItems = RenderFrameRate.allCases.map { frameRate in
            makeMenuItem(title: frameRate.displayName, action: #selector(setFrameRate), value: frameRate)
        }
        frameRateItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makeOpacityItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        opacityModeItems = OpacityMode.allCases.map { mode in
            makeMenuItem(title: mode.displayName, action: #selector(setOpacityMode), value: mode)
        }
        opacityModeItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makeBaseOpacityItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Base Opacity", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        baseOpacityItems = [
            makeMenuItem(title: "50%", action: #selector(setBaseOpacity), value: CGFloat(0.50)),
            makeMenuItem(title: "70%", action: #selector(setBaseOpacity), value: CGFloat(0.70)),
            makeMenuItem(title: "85%", action: #selector(setBaseOpacity), value: CGFloat(0.85)),
            makeMenuItem(title: "100%", action: #selector(setBaseOpacity), value: CGFloat(1.00))
        ]
        baseOpacityItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makeScaleItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Scale & Depth", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        scaleModeItems = ScaleMode.allCases.map { mode in
            makeMenuItem(title: mode.displayName, action: #selector(setScaleMode), value: mode)
        }
        scaleModeItems.forEach { submenu.addItem($0) }
        submenu.addItem(.separator())

        let baseScaleItem = NSMenuItem(title: "Base Scale", action: nil, keyEquivalent: "")
        let baseScaleMenu = NSMenu()
        baseScaleItems = [
            makeMenuItem(title: "70%", action: #selector(setBaseScale), value: CGFloat(0.70)),
            makeMenuItem(title: "85%", action: #selector(setBaseScale), value: CGFloat(0.85)),
            makeMenuItem(title: "100%", action: #selector(setBaseScale), value: CGFloat(1.00)),
            makeMenuItem(title: "115%", action: #selector(setBaseScale), value: CGFloat(1.15))
        ]
        baseScaleItems.forEach { baseScaleMenu.addItem($0) }
        baseScaleItem.submenu = baseScaleMenu
        submenu.addItem(baseScaleItem)

        let depthItem = NSMenuItem(title: "Depth Strength", action: nil, keyEquivalent: "")
        let depthMenu = NSMenu()
        depthStrengthItems = [
            makeMenuItem(title: "Low", action: #selector(setDepthStrength), value: ParameterChoice("depth", 0.04)),
            makeMenuItem(title: "Medium", action: #selector(setDepthStrength), value: ParameterChoice("depth", 0.08)),
            makeMenuItem(title: "High", action: #selector(setDepthStrength), value: ParameterChoice("depth", 0.14))
        ]
        depthStrengthItems.forEach { depthMenu.addItem($0) }
        depthItem.submenu = depthMenu
        submenu.addItem(depthItem)

        item.submenu = submenu
        return item
    }

    private func makeOrientationItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Orientation", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        orientationItems = OrientationMode.allCases.map { mode in
            makeMenuItem(title: mode.displayName, action: #selector(setOrientationMode), value: mode)
        }
        orientationItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makeRotationStrengthItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Rotation Strength", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        rotationStrengthItems = [
            makeMenuItem(title: "25%", action: #selector(setRotationStrength), value: CGFloat(0.25)),
            makeMenuItem(title: "50%", action: #selector(setRotationStrength), value: CGFloat(0.50)),
            makeMenuItem(title: "75%", action: #selector(setRotationStrength), value: CGFloat(0.75)),
            makeMenuItem(title: "100%", action: #selector(setRotationStrength), value: CGFloat(1.00))
        ]
        rotationStrengthItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makeRotationPolicyItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Cursor Rotation Policy", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        rotationPolicyItems = RotationEligibilityMode.allCases.map { policy in
            makeMenuItem(title: policy.displayName, action: #selector(setRotationPolicy), value: policy)
        }
        rotationPolicyItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func makeIdleBehaviorItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Idle Behaviour", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        idleBehaviorItems = IdleBehavior.allCases.map { behavior in
            makeMenuItem(title: behavior.displayName, action: #selector(setIdleBehavior), value: behavior)
        }
        idleBehaviorItems.forEach { submenu.addItem($0) }
        item.submenu = submenu
        return item
    }

    private func applyPatternParameter(_ choice: ParameterChoice) {
        switch choice.key {
        case "classic.cohesion":
            settings.flockSettings.classicParameters.cohesion = choice.value
        case "classic.separation":
            settings.flockSettings.classicParameters.separation = choice.value
        case "classic.wander":
            settings.flockSettings.classicParameters.wander = choice.value
        case "v.angle":
            settings.flockSettings.vFormationParameters.wingAngleDegrees = choice.value
        case "v.spacing":
            settings.flockSettings.vFormationParameters.wingSpacing = choice.value
        case "v.rigidity":
            settings.flockSettings.vFormationParameters.formationRigidity = choice.value
        case "scatter.sensitivity":
            settings.flockSettings.scatterAndReturnParameters.scatterSensitivity = choice.value
        case "scatter.return":
            settings.flockSettings.scatterAndReturnParameters.returnStrength = choice.value
        case "scatter.idleCompactness":
            settings.flockSettings.scatterAndReturnParameters.idleCompactness = choice.value
        case "orbit.radius":
            settings.flockSettings.orbitingFlockParameters.orbitRadius = choice.value
        case "orbit.speed":
            settings.flockSettings.orbitingFlockParameters.orbitSpeed = choice.value
        case "orbit.bands":
            settings.flockSettings.orbitingFlockParameters.orbitBandCount = choice.intValue ?? Int(choice.value)
        default:
            break
        }
    }

    private func applyDepthChoice(_ choice: ParameterChoice) {
        settings.flockSettings.scaleSettings.variationAmount = choice.value
        settings.flockSettings.scaleSettings.minimumScale = max(
            settings.flockSettings.scaleSettings.baseScale - choice.value * 2.4,
            0.4
        )
        settings.flockSettings.scaleSettings.maximumScale = min(
            settings.flockSettings.scaleSettings.baseScale + choice.value,
            1.5
        )
    }

    private func isActivePatternParameter(_ choice: ParameterChoice) -> Bool {
        switch choice.key {
        case "classic.cohesion":
            return approximately(settings.flockSettings.classicParameters.cohesion, choice.value)
        case "classic.separation":
            return approximately(settings.flockSettings.classicParameters.separation, choice.value)
        case "classic.wander":
            return approximately(settings.flockSettings.classicParameters.wander, choice.value)
        case "v.angle":
            return approximately(settings.flockSettings.vFormationParameters.wingAngleDegrees, choice.value)
        case "v.spacing":
            return approximately(settings.flockSettings.vFormationParameters.wingSpacing, choice.value)
        case "v.rigidity":
            return approximately(settings.flockSettings.vFormationParameters.formationRigidity, choice.value)
        case "scatter.sensitivity":
            return approximately(settings.flockSettings.scatterAndReturnParameters.scatterSensitivity, choice.value)
        case "scatter.return":
            return approximately(settings.flockSettings.scatterAndReturnParameters.returnStrength, choice.value)
        case "scatter.idleCompactness":
            return approximately(settings.flockSettings.scatterAndReturnParameters.idleCompactness, choice.value)
        case "orbit.radius":
            return approximately(settings.flockSettings.orbitingFlockParameters.orbitRadius, choice.value)
        case "orbit.speed":
            return approximately(settings.flockSettings.orbitingFlockParameters.orbitSpeed, choice.value)
        case "orbit.bands":
            return settings.flockSettings.orbitingFlockParameters.orbitBandCount == choice.intValue
        default:
            return false
        }
    }

    private func isActiveDepthChoice(_ choice: ParameterChoice) -> Bool {
        approximately(settings.flockSettings.scaleSettings.variationAmount, choice.value)
    }

    private func makeMenuItem<T>(title: String, action: Selector, value: T) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = value
        return item
    }

    private func representedValue<T>(_ item: NSMenuItem) -> T? {
        item.representedObject as? T
    }

    private func approximately(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.001
    }

    private static func makeStatusIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            drawCursorClusterIcon()
            return true
        }

        image.isTemplate = true
        return image
    }

    private static func drawCursorClusterIcon() {
        NSColor.black.setFill()
        drawCursorIcon(offsetX: 0, offsetY: 6, scale: 0.80)

        NSColor.black.withAlphaComponent(0.70).setFill()
        drawCursorIcon(offsetX: -1, offsetY: -1.8, scale: 0.70)

        NSColor.black.withAlphaComponent(0.70).setFill()
        drawCursorIcon(offsetX: 10, offsetY: 6, scale: 0.70)

        NSColor.black.withAlphaComponent(0.70).setFill()
        drawCursorIcon(offsetX: 7.3, offsetY: -1, scale: 0.70)
    }

    private static func drawCursorIcon(offsetX: CGFloat, offsetY: CGFloat, scale: CGFloat) {
        let points = [
            NSPoint(x: 1.2, y: 15.8),
            NSPoint(x: 1.2, y: 2.0),
            NSPoint(x: 5.3, y: 6.0),
            NSPoint(x: 7.7, y: 1.7),
            NSPoint(x: 10.0, y: 3.0),
            NSPoint(x: 7.5, y: 7.2),
            NSPoint(x: 12.7, y: 7.2)
        ]

        let path = NSBezierPath()
        for (index, point) in points.enumerated() {
            let transformedPoint = NSPoint(
                x: offsetX + point.x * scale,
                y: offsetY + point.y * scale
            )

            if index == 0 {
                path.move(to: transformedPoint)
            } else {
                path.line(to: transformedPoint)
            }
        }
        path.close()
        path.fill()
    }
}
