import AppKit
import QuartzCore

@MainActor
final class DisplayManager {
    private let settings: Settings
    private var overlays: [CGDirectDisplayID: OverlayWindow] = [:]
    private let simulation: FlockSimulation
    private let cursorSampler = SystemCursorSampler()
    private let cursorRenderResourceCache = CursorRenderResourceCache()
    private let cursorOrientationClassifier = CursorOrientationClassifier()
    private var renderTimer: Timer?
    private var lastFrameTime: TimeInterval?
    private var lastCursorPosition: CGPoint?
    private var scheduledFramesPerSecond: TimeInterval?
    private var notificationObservers: [NSObjectProtocol] = []
    private var workspaceNotificationObservers: [NSObjectProtocol] = []
    private var isSuspendedForSystemState = false
    private var isTerminating = false

    init(settings: Settings) {
        self.settings = settings
        simulation = FlockSimulation(settings: settings)
        installObservers()
    }

    deinit {
        renderTimer?.invalidate()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        for observer in workspaceNotificationObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func setEnabled(_ isEnabled: Bool) {
        settings.isEnabled = isEnabled

        if isEnabled, !isSuspendedForSystemState, !isTerminating {
            rebuildOverlays()
            startRendering()
        } else {
            stopRendering()
            removeOverlays()
        }
    }

    func rebuildOverlays() {
        guard settings.isEnabled, !isSuspendedForSystemState, !isTerminating else {
            return
        }

        let screens = NSScreen.screens
        var activeDisplayIDs = Set<CGDirectDisplayID>()

        for screen in screens {
            guard let displayID = Self.displayID(for: screen) else {
                continue
            }

            activeDisplayIDs.insert(displayID)

            if let existingWindow = overlays[displayID] {
                existingWindow.configure(for: screen)
                existingWindow.orderFrontRegardless()
            } else {
                let window = OverlayWindow(screen: screen, settings: settings)
                overlays[displayID] = window
                window.orderFrontRegardless()
            }
        }

        let removedDisplayIDs = overlays.keys.filter { !activeDisplayIDs.contains($0) }
        for displayID in removedDisplayIDs {
            overlays[displayID]?.overlayView.prepareForRemoval()
            overlays[displayID]?.orderOut(nil)
            overlays[displayID]?.close()
            overlays.removeValue(forKey: displayID)
        }

        RenderInstrumentation.shared.recordOverlayCount(overlays.count)
    }

    func reconfigureRenderTimer() {
        guard settings.isEnabled, renderTimer != nil else {
            return
        }

        renderTimer?.invalidate()
        renderTimer = nil
        lastFrameTime = CACurrentMediaTime()
        scheduleRenderTimer()
    }

    func prepareForTermination() {
        isTerminating = true
        stopRendering()
        removeOverlays()
    }

    private func installObservers() {
        let names: [Notification.Name] = [
            NSApplication.didChangeScreenParametersNotification,
            NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification
        ]

        notificationObservers = names.map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleEnvironmentChange()
                }
            }
        }

        let workspaceNames: [Notification.Name] = [
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidResignActiveNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
            NSWorkspace.activeSpaceDidChangeNotification
        ]
        workspaceNotificationObservers = workspaceNames.map { name in
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.handleWorkspaceNotification(notification.name)
                }
            }
        }
    }

    private func handleEnvironmentChange() {
        guard settings.isEnabled, !isSuspendedForSystemState, !isTerminating else {
            return
        }

        resetFrameTiming()
        rebuildOverlays()
        reconfigureRenderTimer()
    }

    private func handleWorkspaceNotification(_ name: Notification.Name) {
        switch name {
        case NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification:
            isSuspendedForSystemState = true
            stopRendering()
            removeOverlays()

        case NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
            NSWorkspace.activeSpaceDidChangeNotification:
            isSuspendedForSystemState = false
            guard settings.isEnabled, !isTerminating else {
                return
            }
            resetFrameTiming()
            rebuildOverlays()
            startRendering()

        default:
            break
        }
    }

    private func startRendering() {
        guard renderTimer == nil else {
            reconfigureRenderTimer()
            return
        }

        let pointer = NSEvent.mouseLocation
        let now = CACurrentMediaTime()
        simulation.settings = settings.flockSettings
        simulation.reset(to: pointer)
        lastFrameTime = now
        lastCursorPosition = pointer

        scheduleRenderTimer()
    }

    private func scheduleRenderTimer() {
        let interval = 1.0 / effectiveTargetFramesPerSecond
        scheduledFramesPerSecond = effectiveTargetFramesPerSecond
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.renderFrame()
            }
        }
        timer.tolerance = interval * 0.35
        RunLoop.main.add(timer, forMode: .common)
        renderTimer = timer
    }

    private func stopRendering() {
        renderTimer?.invalidate()
        renderTimer = nil
        scheduledFramesPerSecond = nil
        lastFrameTime = nil
        lastCursorPosition = nil
        cursorRenderResourceCache.clear()
    }

    private func renderFrame() {
        guard settings.isEnabled, !isSuspendedForSystemState, !isTerminating else {
            return
        }
        if scheduledFramesPerSecond != effectiveTargetFramesPerSecond {
            reconfigureRenderTimer()
            return
        }

        if overlays.isEmpty {
            rebuildOverlays()
            guard !overlays.isEmpty else {
                return
            }
        }

        let now = CACurrentMediaTime()
        let pointer = NSEvent.mouseLocation
        let rawDeltaTime = lastFrameTime.map { now - $0 } ?? (1.0 / effectiveTargetFramesPerSecond)
        let deltaTime = Self.clampedSimulationDeltaTime(rawDeltaTime)
        lastFrameTime = now
        let cursorVelocity = Self.cursorVelocity(
            from: lastCursorPosition,
            to: pointer,
            deltaTime: max(rawDeltaTime, 1.0 / 240.0)
        )
        lastCursorPosition = pointer

        simulation.settings = settings.flockSettings
        let cursorFrame = cursorSampler.currentFrame(now: now)
        let cursorCanRotate = cursorOrientationClassifier.isSafeToRotate(frame: cursorFrame)
        let members = simulation.update(
            deltaTime: deltaTime,
            cursorPosition: pointer,
            cursorVelocity: cursorVelocity,
            cursorCanRotate: cursorCanRotate
        )
        let debugCenter = Self.averagePosition(of: members) ?? pointer

        for window in overlays.values {
            let contentsScale = window.overlayView.layer?.contentsScale ?? window.backingScaleFactor
            let cursorResource = cursorRenderResourceCache.resource(
                for: cursorFrame,
                contentsScale: contentsScale,
                colorMode: settings.cursorColorMode
            )
            window.overlayView.display(
                members: members,
                cursorFrame: cursorFrame,
                cursorResource: cursorResource,
                debugCenter: debugCenter
            )
        }

        RenderInstrumentation.shared.finishFrame(now: now)
    }

    private func removeOverlays() {
        for window in overlays.values {
            window.overlayView.prepareForRemoval()
            window.orderOut(nil)
            window.close()
        }
        overlays.removeAll()
        RenderInstrumentation.shared.recordOverlayCount(0)
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(number.uint32Value)
    }

    private static func averagePosition(of members: [FlockMember]) -> CGPoint? {
        guard !members.isEmpty else {
            return nil
        }

        let total = members.reduce(CGPoint.zero) { partialResult, member in
            CGPoint(
                x: partialResult.x + member.position.x,
                y: partialResult.y + member.position.y
            )
        }

        return CGPoint(
            x: total.x / CGFloat(members.count),
            y: total.y / CGFloat(members.count)
        )
    }

    private static func cursorVelocity(
        from lastPosition: CGPoint?,
        to currentPosition: CGPoint,
        deltaTime: TimeInterval
    ) -> CGVector {
        guard let lastPosition, deltaTime > 0 else {
            return .zero
        }

        let scale = 1 / CGFloat(deltaTime)
        return CGVector(
            dx: (currentPosition.x - lastPosition.x) * scale,
            dy: (currentPosition.y - lastPosition.y) * scale
        )
    }

    private static func clampedSimulationDeltaTime(_ deltaTime: TimeInterval) -> TimeInterval {
        min(max(deltaTime, 1.0 / 240.0), 1.0 / 30.0)
    }

    private var effectiveTargetFramesPerSecond: TimeInterval {
        ProcessInfo.processInfo.isLowPowerModeEnabled
            ? min(settings.targetFramesPerSecond, 30)
            : settings.targetFramesPerSecond
    }

    private func resetFrameTiming() {
        let pointer = NSEvent.mouseLocation
        lastFrameTime = CACurrentMediaTime()
        lastCursorPosition = pointer
    }
}
