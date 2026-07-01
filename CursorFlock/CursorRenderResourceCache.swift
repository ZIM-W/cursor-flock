import AppKit

struct CursorRenderResource {
    let revision: UInt64
    let contentsScale: CGFloat
    let contents: CGImage
    let imageSizePoints: CGSize
    let hotspotPoints: CGPoint
    let isFallback: Bool
}

@MainActor
final class CursorRenderResourceCache {
    private var cachedRevision: UInt64?
    private var resourcesByScale: [Int: CursorRenderResource] = [:]

    func resource(for frame: CursorFrame, contentsScale: CGFloat) -> CursorRenderResource {
        let normalizedScale = max(contentsScale, 1)
        if cachedRevision != frame.revision {
            resourcesByScale.removeAll(keepingCapacity: true)
            cachedRevision = frame.revision
        }

        let key = Self.scaleKey(normalizedScale)
        if let resource = resourcesByScale[key] {
            return resource
        }

        let resource = makeResource(for: frame, contentsScale: normalizedScale)
        resourcesByScale[key] = resource
        RenderInstrumentation.shared.recordCursorImageConversion()
        return resource
    }

    func clear() {
        resourcesByScale.removeAll(keepingCapacity: true)
        cachedRevision = nil
    }

    private func makeResource(for frame: CursorFrame, contentsScale: CGFloat) -> CursorRenderResource {
        if let image = frame.image {
            var proposedRect = CGRect(origin: .zero, size: frame.imageSizePoints)
            if let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
                return CursorRenderResource(
                    revision: frame.revision,
                    contentsScale: contentsScale,
                    contents: cgImage,
                    imageSizePoints: frame.imageSizePoints,
                    hotspotPoints: frame.hotspotPoints,
                    isFallback: frame.isFallback
                )
            }
        }

        return makeVectorFallbackResource(frame: frame, contentsScale: contentsScale)
    }

    private func makeVectorFallbackResource(
        frame: CursorFrame,
        contentsScale: CGFloat
    ) -> CursorRenderResource {
        let imageSize = CGSize(width: 18.2, height: 23.2)
        let pixelWidth = max(1, Int(ceil(imageSize.width * contentsScale)))
        let pixelHeight = max(1, Int(ceil(imageSize.height * contentsScale)))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return CursorRenderResource(
                revision: frame.revision,
                contentsScale: contentsScale,
                contents: Self.emptyImage,
                imageSizePoints: imageSize,
                hotspotPoints: CGPoint(x: 0, y: imageSize.height),
                isFallback: true
            )
        }

        context.scaleBy(x: contentsScale, y: contentsScale)
        context.translateBy(x: 0, y: imageSize.height)

        context.addPath(Self.cursorPath)
        context.setFillColor(NSColor.white.cgColor)
        context.fillPath()

        context.addPath(Self.cursorPath)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.72).cgColor)
        context.setLineWidth(1.2)
        context.setLineJoin(.round)
        context.strokePath()

        return CursorRenderResource(
            revision: frame.revision,
            contentsScale: contentsScale,
            contents: context.makeImage() ?? Self.emptyImage,
            imageSizePoints: imageSize,
            hotspotPoints: CGPoint(x: 0, y: imageSize.height),
            isFallback: true
        )
    }

    private static func scaleKey(_ scale: CGFloat) -> Int {
        Int((scale * 1000).rounded())
    }

    private static let emptyImage: CGImage = {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        return context?.makeImage() ?? CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data([0, 0, 0, 0]) as CFData)!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }()

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
