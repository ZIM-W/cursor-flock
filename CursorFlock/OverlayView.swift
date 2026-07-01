import AppKit
import QuartzCore

@MainActor
final class OverlayView: NSView {
    var screenFrame: CGRect {
        didSet {
            frame = CGRect(origin: .zero, size: screenFrame.size)
            updateBackingScale()
            if isDebugVisible {
                needsDisplay = true
            }
        }
    }

    private struct LayerState {
        var position = CGPoint(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude)
        var opacity: Float = -1
        var scale: CGFloat = -1
        var angle: CGFloat = CGFloat.greatestFiniteMagnitude
        var zPosition: CGFloat = CGFloat.greatestFiniteMagnitude
        var revision: UInt64?
        var contentsScale: CGFloat = 0
        var imageSize = CGSize.zero
        var hotspot = CGPoint.zero
        var isHidden = true
    }

    private final class MemberLayerSlot {
        let layer = CALayer()
        var state = LayerState()

        init() {
            layer.isOpaque = false
            layer.masksToBounds = false
            layer.contentsGravity = .resize
            layer.backgroundColor = nil
            layer.shadowOpacity = 0
            layer.isHidden = true
        }
    }

    private let settings: Settings
    private var layerSlots: [MemberLayerSlot] = []
    private var debugMembers: [FlockMember] = []
    private var cursorFrame: CursorFrame?
    private var debugCenter = CGPoint.zero
    private var isDebugVisible = false

    init(screenFrame: CGRect, settings: Settings) {
        self.screenFrame = screenFrame
        self.settings = settings
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layer?.masksToBounds = false
        preallocateMemberLayers()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isOpaque: Bool {
        false
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateBackingScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateBackingScale()
    }

    func display(
        members: [FlockMember],
        cursorFrame: CursorFrame,
        cursorResource: CursorRenderResource,
        debugCenter: CGPoint
    ) {
        self.cursorFrame = cursorFrame
        self.debugCenter = debugCenter

        updateMemberLayers(members: members, cursorResource: cursorResource)

        let shouldShowDebug = settings.showCursorDebugOverlay || settings.showOrientationDebug
        if shouldShowDebug {
            debugMembers = members
            needsDisplay = true
        } else if isDebugVisible {
            debugMembers.removeAll(keepingCapacity: true)
            needsDisplay = true
        }
        isDebugVisible = shouldShowDebug
    }

    func prepareForRemoval() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for slot in layerSlots {
            slot.layer.isHidden = true
            slot.layer.contents = nil
            slot.state = LayerState()
        }
        CATransaction.commit()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.clear(dirtyRect)

        guard isDebugVisible else {
            return
        }

        if settings.showCursorDebugOverlay, let cursorFrame {
            drawDebugOverlay(for: cursorFrame)
        }

        if settings.showOrientationDebug {
            drawOrientationDebug(in: context)
        }
    }

    private func preallocateMemberLayers() {
        guard let rootLayer = layer else {
            return
        }

        let targetCount = FlockSettings.clampedCursorCount(30)
        layerSlots.reserveCapacity(targetCount)
        for _ in 0..<targetCount {
            let slot = MemberLayerSlot()
            rootLayer.addSublayer(slot.layer)
            layerSlots.append(slot)
        }
        RenderInstrumentation.shared.recordLayerCreation(count: targetCount)
    }

    private func updateMemberLayers(
        members: [FlockMember],
        cursorResource: CursorRenderResource
    ) {
        let visibleBounds = bounds
        var visibleLayerIndex = 0
        var propertyUpdates = 0
        var skippedDirtyUpdates = 0

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for memberIndex in members.indices {
            guard visibleLayerIndex < layerSlots.count else {
                break
            }

            let member = members[memberIndex]
            let localPosition = convertGlobalPointToLocal(member.position)
            let padding = visibilityPadding(for: cursorResource, scale: member.scale)
            guard visibleBounds.insetBy(dx: -padding, dy: -padding).contains(localPosition) else {
                continue
            }

            let slot = layerSlots[visibleLayerIndex]
            propertyUpdates += update(
                slot: slot,
                member: member,
                memberIndex: memberIndex,
                localPosition: localPosition,
                cursorResource: cursorResource,
                skippedDirtyUpdates: &skippedDirtyUpdates
            )
            visibleLayerIndex += 1
        }

        for index in visibleLayerIndex..<layerSlots.count {
            let slot = layerSlots[index]
            guard !slot.state.isHidden else {
                continue
            }

            slot.layer.isHidden = true
            slot.state.isHidden = true
            propertyUpdates += 1
        }

        CATransaction.commit()

        RenderInstrumentation.shared.recordLayerUpdate(
            propertyUpdates: propertyUpdates,
            skippedDirtyUpdates: skippedDirtyUpdates,
            membersRendered: visibleLayerIndex
        )
    }

    private func update(
        slot: MemberLayerSlot,
        member: FlockMember,
        memberIndex: Int,
        localPosition: CGPoint,
        cursorResource: CursorRenderResource,
        skippedDirtyUpdates: inout Int
    ) -> Int {
        var propertyUpdates = 0
        let layer = slot.layer

        if slot.state.isHidden {
            layer.isHidden = false
            slot.state.isHidden = false
            propertyUpdates += 1
        }

        if needsContentsUpdate(state: slot.state, resource: cursorResource) {
            layer.contents = cursorResource.contents
            layer.contentsScale = cursorResource.contentsScale
            layer.bounds = CGRect(origin: .zero, size: cursorResource.imageSizePoints)
            layer.anchorPoint = normalizedHotspot(
                cursorResource.hotspotPoints,
                imageSize: cursorResource.imageSizePoints
            )
            slot.state.revision = cursorResource.revision
            slot.state.contentsScale = cursorResource.contentsScale
            slot.state.imageSize = cursorResource.imageSizePoints
            slot.state.hotspot = cursorResource.hotspotPoints
            propertyUpdates += 4
        }

        if slot.state.position.distance(to: localPosition) > 0.1 {
            layer.position = localPosition
            slot.state.position = localPosition
            propertyUpdates += 1
        } else {
            skippedDirtyUpdates += 1
        }

        let targetOpacity = Float(member.opacity)
        if abs(slot.state.opacity - targetOpacity) > 0.002 {
            layer.opacity = targetOpacity
            slot.state.opacity = targetOpacity
            propertyUpdates += 1
        } else {
            skippedDirtyUpdates += 1
        }

        if abs(slot.state.angle - member.angleRadians) > 0.002
            || abs(slot.state.scale - member.scale) > 0.002 {
            layer.transform = CATransform3DMakeAffineTransform(
                CGAffineTransform(rotationAngle: member.angleRadians)
                    .scaledBy(x: member.scale, y: member.scale)
            )
            slot.state.angle = member.angleRadians
            slot.state.scale = member.scale
            propertyUpdates += 1
        } else {
            skippedDirtyUpdates += 1
        }

        let zPosition = CGFloat(layerSlots.count - memberIndex)
        if abs(slot.state.zPosition - zPosition) > 0.001 {
            layer.zPosition = zPosition
            slot.state.zPosition = zPosition
            propertyUpdates += 1
        } else {
            skippedDirtyUpdates += 1
        }

        return propertyUpdates
    }

    private func needsContentsUpdate(
        state: LayerState,
        resource: CursorRenderResource
    ) -> Bool {
        state.revision != resource.revision
            || abs(state.contentsScale - resource.contentsScale) > 0.001
            || state.imageSize != resource.imageSizePoints
            || state.hotspot != resource.hotspotPoints
    }

    private func normalizedHotspot(_ hotspot: CGPoint, imageSize: CGSize) -> CGPoint {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        return CGPoint(
            x: min(max(hotspot.x / imageSize.width, 0), 1),
            y: min(max(hotspot.y / imageSize.height, 0), 1)
        )
    }

    private func visibilityPadding(for resource: CursorRenderResource, scale: CGFloat) -> CGFloat {
        max(resource.imageSizePoints.width, resource.imageSizePoints.height) * max(scale, 1) * 1.6 + 8
    }

    private func convertGlobalPointToLocal(_ globalPoint: CGPoint) -> CGPoint {
        // NSEvent.mouseLocation and NSScreen.frame share AppKit's global screen space.
        CGPoint(
            x: globalPoint.x - screenFrame.minX,
            y: globalPoint.y - screenFrame.minY
        )
    }

    private func drawDebugOverlay(for frame: CursorFrame) {
        let localCenter = convertGlobalPointToLocal(debugCenter)
        guard bounds.insetBy(dx: -180, dy: -90).contains(localCenter) else {
            return
        }

        let lines = [
            "size \(Int(frame.imageSizePoints.width))x\(Int(frame.imageSizePoints.height)) pt",
            "hotspot \(format(frame.hotspotPoints.x)), \(format(frame.hotspotPoints.y))",
            "revision \(frame.revision)",
            frame.isFallback ? "fallback active" : "sampled cursor"
        ]
        let text = lines.joined(separator: "\n") as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        let backgroundRect = CGRect(
            x: localCenter.x + 16,
            y: localCenter.y + 16,
            width: textSize.width + 12,
            height: textSize.height + 10
        )

        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(
            roundedRect: backgroundRect,
            xRadius: 4,
            yRadius: 4
        ).fill()

        text.draw(
            in: backgroundRect.insetBy(dx: 6, dy: 5),
            withAttributes: attributes
        )
    }

    private func drawOrientationDebug(in context: CGContext) {
        let intrinsicForwardAngle = settings.flockSettings.baseAxisAdjustmentDegrees * .pi / 180
        let forwardLength: CGFloat = 32
        let velocityLength: CGFloat = 28

        for member in debugMembers {
            let localPosition = convertGlobalPointToLocal(member.position)
            guard bounds.insetBy(dx: -50, dy: -50).contains(localPosition) else {
                continue
            }

            drawHotspotCross(in: context, at: localPosition)

            if member.velocity.length > 1 {
                let velocityDirection = member.velocity.normalized
                drawDebugLine(
                    in: context,
                    from: localPosition,
                    direction: velocityDirection,
                    length: velocityLength,
                    color: NSColor.systemGreen.withAlphaComponent(0.85).cgColor,
                    dashed: false
                )
            }

            let renderedForwardDirection = CGVector(
                dx: cos(member.angleRadians + intrinsicForwardAngle),
                dy: sin(member.angleRadians + intrinsicForwardAngle)
            )
            drawDebugLine(
                in: context,
                from: localPosition,
                direction: renderedForwardDirection,
                length: forwardLength,
                color: NSColor.systemBlue.withAlphaComponent(0.85).cgColor,
                dashed: true
            )
        }

        drawOrientationDebugLabel(intrinsicForwardAngle: intrinsicForwardAngle)
        drawOrientationDebugSamples(in: context, intrinsicForwardAngle: intrinsicForwardAngle)
    }

    private func drawHotspotCross(in context: CGContext, at point: CGPoint) {
        let size: CGFloat = 4

        context.saveGState()
        context.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.95).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: point.x - size, y: point.y))
        context.addLine(to: CGPoint(x: point.x + size, y: point.y))
        context.move(to: CGPoint(x: point.x, y: point.y - size))
        context.addLine(to: CGPoint(x: point.x, y: point.y + size))
        context.strokePath()
        context.restoreGState()
    }

    private func drawDebugLine(
        in context: CGContext,
        from origin: CGPoint,
        direction: CGVector,
        length: CGFloat,
        color: CGColor,
        dashed: Bool
    ) {
        let normalized = direction.normalized
        guard normalized.lengthSquared > 0 else {
            return
        }

        context.saveGState()
        context.setStrokeColor(color)
        context.setLineWidth(1)
        context.setLineCap(.round)
        if dashed {
            context.setLineDash(phase: 0, lengths: [4, 3])
        }
        context.move(to: origin)
        context.addLine(
            to: CGPoint(
                x: origin.x + normalized.dx * length,
                y: origin.y + normalized.dy * length
            )
        )
        context.strokePath()
        context.restoreGState()
    }

    private func drawOrientationDebugLabel(intrinsicForwardAngle: CGFloat) {
        let localCenter = convertGlobalPointToLocal(debugCenter)
        guard bounds.insetBy(dx: -220, dy: -120).contains(localCenter) else {
            return
        }

        let referenceMember = debugMembers.first { $0.velocity.length > 1 } ?? debugMembers.first
        let movementAngle = referenceMember.map { atan2($0.velocity.dy, $0.velocity.dx) } ?? 0
        let renderAngle = referenceMember?.angleRadians ?? 0
        let renderedForwardAngle = renderAngle + intrinsicForwardAngle
        let lines = [
            "green velocity",
            "blue dashed cursor tip",
            "movement \(degreesString(movementAngle))",
            "base \(degreesString(intrinsicForwardAngle))",
            "render \(degreesString(renderAngle))",
            "tip \(degreesString(renderedForwardAngle))"
        ]
        let text = lines.joined(separator: "\n") as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        let backgroundRect = CGRect(
            x: localCenter.x + 16,
            y: localCenter.y - textSize.height - 28,
            width: textSize.width + 12,
            height: textSize.height + 10
        )

        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(
            roundedRect: backgroundRect,
            xRadius: 4,
            yRadius: 4
        ).fill()

        text.draw(
            in: backgroundRect.insetBy(dx: 6, dy: 5),
            withAttributes: attributes
        )
    }

    private func drawOrientationDebugSamples(in context: CGContext, intrinsicForwardAngle: CGFloat) {
        guard let cursorFrame else {
            return
        }

        let localCenter = convertGlobalPointToLocal(debugCenter)
        let headings: [(String, CGFloat)] = [
            ("R", 0),
            ("L", .pi),
            ("U", .pi / 2),
            ("D", -.pi / 2),
            ("NE", .pi / 4)
        ]
        let spacing: CGFloat = 42
        let startX = localCenter.x - spacing * CGFloat(headings.count - 1) / 2
        let y = localCenter.y - 112

        guard bounds.insetBy(dx: -180, dy: -150).contains(CGPoint(x: localCenter.x, y: y)) else {
            return
        }

        for (index, sample) in headings.enumerated() {
            let point = CGPoint(x: startX + CGFloat(index) * spacing, y: y)
            drawHotspotCross(in: context, at: point)

            let renderAngle = sample.1 - intrinsicForwardAngle
            if let image = cursorFrame.image {
                drawDebugCursorImage(
                    image,
                    frame: cursorFrame,
                    at: point,
                    angle: renderAngle
                )
            } else {
                drawDebugVectorCursor(at: point, angle: renderAngle)
            }

            let label = sample.0 as NSString
            label.draw(
                at: CGPoint(x: point.x - 7, y: point.y - 28),
                withAttributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .medium),
                    .foregroundColor: NSColor.white
                ]
            )
        }
    }

    private func drawDebugCursorImage(
        _ image: NSImage,
        frame: CursorFrame,
        at point: CGPoint,
        angle: CGFloat
    ) {
        let scale: CGFloat = 0.72
        let size = CGSize(
            width: frame.imageSizePoints.width * scale,
            height: frame.imageSizePoints.height * scale
        )
        let hotspot = CGPoint(
            x: frame.hotspotPoints.x * scale,
            y: frame.hotspotPoints.y * scale
        )

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: angle)
        context.translateBy(x: -hotspot.x, y: -hotspot.y)
        image.draw(
            in: CGRect(origin: .zero, size: size),
            from: CGRect(origin: .zero, size: frame.imageSizePoints),
            operation: .sourceOver,
            fraction: 0.72,
            respectFlipped: false,
            hints: nil
        )
        context.restoreGState()
    }

    private func drawDebugVectorCursor(at point: CGPoint, angle: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: angle)
        context.scaleBy(x: 0.72, y: 0.72)
        context.setAlpha(0.72)
        context.addPath(Self.cursorPath)
        context.setFillColor(NSColor.white.cgColor)
        context.fillPath()
        context.restoreGState()
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    private func degreesString(_ radians: CGFloat) -> String {
        String(format: "%.0f deg", Double(normalizedDegrees(radians)))
    }

    private func normalizedDegrees(_ radians: CGFloat) -> CGFloat {
        var degrees = radians * 180 / .pi
        while degrees > 180 {
            degrees -= 360
        }
        while degrees <= -180 {
            degrees += 360
        }
        return degrees
    }

    private func updateBackingScale() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        layer?.contentsScale = scale
        for slot in layerSlots {
            slot.layer.contentsScale = scale
        }
    }

    private static let cursorPath: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -23))
        path.addLine(to: CGPoint(x: 6.2, y: -16.4))
        path.addLine(to: CGPoint(x: 10.3, y: -23.2))
        path.addLine(to: CGPoint(x: 14.2, y: -20.9))
        path.addLine(to: CGPoint(x: 10.1, y: -14.1))
        path.addLine(to: CGPoint(x: 18.2, y: -14.1))
        path.closeSubpath()
        return path.copy()!
    }()
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        hypot(x - point.x, y - point.y)
    }
}

private extension CGVector {
    var lengthSquared: CGFloat {
        dx * dx + dy * dy
    }

    var length: CGFloat {
        sqrt(lengthSquared)
    }

    var normalized: CGVector {
        let length = length
        guard length > 0 else {
            return .zero
        }

        return CGVector(dx: dx / length, dy: dy / length)
    }
}
