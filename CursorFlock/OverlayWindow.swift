import AppKit

@MainActor
final class OverlayWindow: NSWindow {
    let overlayView: OverlayView

    init(screen: NSScreen, settings: Settings) {
        overlayView = OverlayView(screenFrame: screen.frame, settings: settings)
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        contentView = overlayView
        configure(for: screen)
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    func configure(for screen: NSScreen) {
        setFrame(screen.frame, display: true)
        overlayView.frame = CGRect(origin: .zero, size: screen.frame.size)
        overlayView.screenFrame = screen.frame
        overlayView.layer?.contentsScale = backingScaleFactor
    }

    private func configureWindow() {
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = false
        hidesOnDeactivate = false
        animationBehavior = .none
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // Floating plus all-spaces behavior keeps the decorative overlay above normal apps
        // without making it key, main, or part of normal window cycling.
        level = .floating
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
    }
}
