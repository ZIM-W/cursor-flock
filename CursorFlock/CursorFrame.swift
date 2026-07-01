import AppKit

struct CursorFrame {
    let image: NSImage?
    let imageSizePoints: CGSize
    let hotspotPoints: CGPoint
    let revision: UInt64
    let sampledAt: TimeInterval
    let isFallback: Bool
}
