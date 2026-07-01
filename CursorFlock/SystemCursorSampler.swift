import AppKit

@MainActor
final class SystemCursorSampler {
    private let sampleInterval: TimeInterval = 1.0 / 30.0

    private var nextSampleTime: TimeInterval = 0
    private var lastSignature: CursorSignature?
    private var latestValidFrame: CursorFrame?
    private var arrowFallbackFrame: CursorFrame?
    private var vectorFallbackFrame: CursorFrame?
    private var revision: UInt64 = 0
    private var hasAttemptedSample = false

    func currentFrame(now: TimeInterval) -> CursorFrame {
        if !hasAttemptedSample || now >= nextSampleTime {
            hasAttemptedSample = true
            nextSampleTime = now + sampleInterval
            sampleCurrentSystemCursor(now: now)
        }

        if let latestValidFrame {
            return latestValidFrame
        }

        if let arrowFallbackFrame {
            return arrowFallbackFrame
        }

        return makeArrowFallbackFrame(now: now) ?? makeVectorFallbackFrame(now: now)
    }

    private func sampleCurrentSystemCursor(now: TimeInterval) {
        assert(Thread.isMainThread)

        guard let cursor = NSCursor.currentSystem else {
            return
        }

        let image = cursor.image
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return
        }

        let signature = CursorSignature(cursor: cursor, image: image)
        guard signature != lastSignature || latestValidFrame == nil else {
            return
        }

        revision += 1
        lastSignature = signature
        latestValidFrame = CursorFrame(
            image: image,
            imageSizePoints: imageSize,
            hotspotPoints: Self.drawingHotspot(from: cursor.hotSpot, imageSize: imageSize),
            revision: revision,
            sampledAt: now,
            isFallback: false
        )
    }

    private func makeArrowFallbackFrame(now: TimeInterval) -> CursorFrame? {
        let cursor = NSCursor.arrow
        let image = cursor.image
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return nil
        }

        let frame = CursorFrame(
            image: image,
            imageSizePoints: imageSize,
            hotspotPoints: Self.drawingHotspot(from: cursor.hotSpot, imageSize: imageSize),
            revision: revision,
            sampledAt: now,
            isFallback: true
        )
        arrowFallbackFrame = frame
        return frame
    }

    private func makeVectorFallbackFrame(now: TimeInterval) -> CursorFrame {
        if let vectorFallbackFrame {
            return vectorFallbackFrame
        }

        let frame = CursorFrame(
            image: nil,
            imageSizePoints: CGSize(width: 18.2, height: 23.2),
            hotspotPoints: .zero,
            revision: revision,
            sampledAt: now,
            isFallback: true
        )
        vectorFallbackFrame = frame
        return frame
    }

    private static func drawingHotspot(from cursorHotspot: CGPoint, imageSize: CGSize) -> CGPoint {
        let hotspot = CGPoint(
            x: cursorHotspot.x,
            y: imageSize.height - cursorHotspot.y
        )

        return CGPoint(
            x: min(max(hotspot.x, 0), imageSize.width),
            y: min(max(hotspot.y, 0), imageSize.height)
        )
    }
}

private struct CursorSignature: Equatable {
    let cursorID: ObjectIdentifier
    let imageSize: CGSize
    let hotspot: CGPoint
    let representationMetrics: [RepresentationMetrics]

    init(cursor: NSCursor, image: NSImage) {
        cursorID = ObjectIdentifier(cursor)
        imageSize = image.size
        hotspot = cursor.hotSpot
        representationMetrics = image.representations.map { representation in
            RepresentationMetrics(
                pixelsWide: representation.pixelsWide,
                pixelsHigh: representation.pixelsHigh,
                pointsWide: representation.size.width,
                pointsHigh: representation.size.height
            )
        }
    }
}

private struct RepresentationMetrics: Equatable {
    let pixelsWide: Int
    let pixelsHigh: Int
    let pointsWide: CGFloat
    let pointsHigh: CGFloat
}
