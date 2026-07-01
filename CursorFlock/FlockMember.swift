import CoreGraphics

struct FlockMember {
    var seed: CGFloat
    var position: CGPoint
    var velocity: CGVector
    var targetOffset: CGVector
    var phase: Double
    var opacity: CGFloat
    var scale: CGFloat
    var angleRadians: CGFloat
    var formationSide: CGFloat
    var formationRank: CGFloat
}
