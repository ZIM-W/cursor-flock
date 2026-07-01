import CoreGraphics

struct FlockParameters {
    let idleRadius: CGFloat = 54
    let movingRadius: CGFloat = 108
    let protectedRadius: CGFloat = 30

    let centerAngularFrequency: CGFloat = 18
    let centerDampingRatio: CGFloat = 0.82
    let maximumCenterLag: CGFloat = 36

    let cohesionStrength: CGFloat = 38
    let separationStrength: CGFloat = 920
    let alignmentStrength: CGFloat = 5.5
    let orbitStrength: CGFloat = 34
    let wanderStrength: CGFloat = 22
    let protectedZoneStrength: CGFloat = 980
    let containmentStrength: CGFloat = 42
    let damping: CGFloat = 7.2

    let neighborRadius: CGFloat = 82
    let separationDistance: CGFloat = 28
    let directionalSpread: CGFloat = 30

    let minOpacity: CGFloat = 0.24
    let maxOpacity: CGFloat = 0.72
    let minScale: CGFloat = 0.80
    let maxScale: CGFloat = 1.00
}
