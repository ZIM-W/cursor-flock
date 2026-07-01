import AppKit

final class CursorOrientationClassifier {
    func isSafeToRotate(frame: CursorFrame) -> Bool {
        if frame.image == nil {
            return true
        }

        if frame.isFallback {
            return true
        }

        let size = frame.imageSizePoints
        guard size.width > 0, size.height > 0 else {
            return false
        }

        let hotspot = frame.hotspotPoints
        let width = size.width
        let height = size.height
        let aspect = width / height
        let centerDistance = hypot(
            (hotspot.x - width / 2) / max(width, 1),
            (hotspot.y - height / 2) / max(height, 1)
        )

        if aspect < 0.48 || aspect > 2.2 {
            return false
        }

        if centerDistance < 0.23 {
            return false
        }

        let hotspotNearPointerCorner = hotspot.x <= width * 0.45
            && hotspot.y <= height * 0.45
        if hotspotNearPointerCorner {
            return true
        }

        let hotspotNearEdge = hotspot.x <= width * 0.18
            || hotspot.y <= height * 0.18
            || hotspot.x >= width * 0.82
            || hotspot.y >= height * 0.82

        return hotspotNearEdge && centerDistance > 0.34
    }
}
