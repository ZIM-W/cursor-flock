import Foundation

@MainActor
final class RenderInstrumentation {
    static let shared = RenderInstrumentation()

    var isEnabled = false

    private var lastReportTime: TimeInterval = 0
    private var cursorImageConversions = 0
    private var layerCreations = 0
    private var layerPropertyUpdates = 0
    private var skippedDirtyUpdates = 0
    private var frameCount = 0
    private var activeOverlayCount = 0
    private var membersRenderedByOverlay: [Int] = []

    private init() {}

    func recordCursorImageConversion() {
        guard isEnabled else {
            return
        }
        cursorImageConversions += 1
    }

    func recordLayerCreation(count: Int = 1) {
        guard isEnabled else {
            return
        }
        layerCreations += count
    }

    func recordOverlayCount(_ count: Int) {
        guard isEnabled else {
            return
        }
        activeOverlayCount = count
    }

    func recordLayerUpdate(propertyUpdates: Int, skippedDirtyUpdates: Int, membersRendered: Int) {
        guard isEnabled else {
            return
        }
        layerPropertyUpdates += propertyUpdates
        self.skippedDirtyUpdates += skippedDirtyUpdates
        membersRenderedByOverlay.append(membersRendered)
    }

    func finishFrame(now: TimeInterval) {
        guard isEnabled else {
            return
        }

        frameCount += 1

        if lastReportTime == 0 {
            lastReportTime = now
            resetPerSecondCounters()
            return
        }

        guard now - lastReportTime >= 1 else {
            return
        }

        let renderedSummary = membersRenderedByOverlay
            .map(String.init)
            .joined(separator: ",")
        let safeFrameCount = max(frameCount, 1)
        NSLog(
            "CursorFlock perf: cursorConversions/s=%d layerCreations/s=%d propertyUpdates/frame=%d skippedDirty/frame=%d overlays=%d membersPerOverlay=[%@]",
            cursorImageConversions,
            layerCreations,
            layerPropertyUpdates / safeFrameCount,
            skippedDirtyUpdates / safeFrameCount,
            activeOverlayCount,
            renderedSummary
        )
        lastReportTime = now
        resetPerSecondCounters()
    }

    private func resetPerSecondCounters() {
        cursorImageConversions = 0
        layerCreations = 0
        layerPropertyUpdates = 0
        skippedDirtyUpdates = 0
        frameCount = 0
        membersRenderedByOverlay.removeAll(keepingCapacity: true)
    }
}
