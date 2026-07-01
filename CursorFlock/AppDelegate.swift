import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private var displayManager: DisplayManager?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let manager = DisplayManager(settings: settings)
        displayManager = manager

        menuBarController = MenuBarController(
            settings: settings,
            onEnabledChanged: { [weak manager] isEnabled in
                manager?.setEnabled(isEnabled)
            },
            onFrameRateChanged: { [weak manager] in
                manager?.reconfigureRenderTimer()
            },
            onSettingsChanged: { [weak self] in
                self?.settings.save()
            },
            onResetDefaults: { [weak self, weak manager] in
                guard let self else {
                    return
                }
                self.settings.resetToDefaults()
                manager?.setEnabled(self.settings.isEnabled)
                manager?.reconfigureRenderTimer()
                self.settings.save()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.startCursorFlockAfterMenuBarSetup()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        settings.save()
        displayManager?.prepareForTermination()
    }

    private func startCursorFlockAfterMenuBarSetup() {
        displayManager?.setEnabled(settings.isEnabled)
        menuBarController?.updateMenuState()
    }
}
