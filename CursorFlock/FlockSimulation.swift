import CoreGraphics
import Foundation

final class FlockSimulation {
    var settings: FlockSettings

    private let parameters: FlockParameters

    private var members: [FlockMember] = []
    private var flockCenter = CGPoint.zero
    private var centerVelocity = CGVector.zero
    private var pointerVelocity = CGVector.zero
    private var formationHeading = CGVector(dx: 1, dy: 0)
    private var memberSnapshot: [FlockMember] = []
    private var targetOffsets: [CGVector] = []
    private var smoothedEffectiveFlockRadius: CGFloat
    private var idleElapsedTime: CGFloat = 0
    private var idleBlend: CGFloat = 0

    private var maximumRadius: CGFloat {
        settings.maximumRadius
    }

    init(settings: Settings) {
        self.settings = settings.flockSettings
        parameters = settings.flockParameters
        smoothedEffectiveFlockRadius = settings.flockParameters.movingRadius
    }

    func reset(to position: CGPoint) {
        flockCenter = position
        centerVelocity = .zero
        pointerVelocity = .zero
        formationHeading = CGVector(dx: 1, dy: 0)
        smoothedEffectiveFlockRadius = parameters.movingRadius
        idleElapsedTime = 0
        idleBlend = 0
        members = makeMembers(count: settings.cursorCount, around: position, compact: false)
        prepareTargetOffsets()
    }

    func update(
        deltaTime: TimeInterval,
        cursorPosition: CGPoint,
        cursorVelocity: CGVector,
        cursorCanRotate: Bool
    ) -> [FlockMember] {
        ensureMemberCount(cursorPosition: cursorPosition)

        let dt = CGFloat(min(max(deltaTime, 1.0 / 240.0), 1.0 / 30.0))
        updatePointerVelocity(cursorVelocity, dt: dt)
        updateIdleState(dt: dt)
        updateFlockCenter(cursorPosition: cursorPosition, dt: dt)
        updateFormationHeading(dt: dt)
        advancePhases(dt: dt)

        let context = makeContext(
            cursorPosition: cursorPosition,
            dt: dt,
            cursorCanRotate: cursorCanRotate
        )

        switch settings.pattern {
        case .classicFlock:
            updateClassicFlock(context)
        case .vFormation:
            updateVFormation(context)
        case .scatterAndReturn:
            updateScatterAndReturn(context)
        case .orbitingFlock:
            updateOrbitingFlock(context)
        }

        return members
    }

    private func updateClassicFlock(_ context: SimulationContext) {
        prepareTargetOffsets()
        var radius = parameters.idleRadius
            + (parameters.movingRadius - parameters.idleRadius) * context.speedFactor
        if context.idleBlend > 0, settings.idleBehavior == .gather {
            radius += (parameters.idleRadius * 0.52 - radius) * context.idleBlend
        }

        for index in members.indices {
            targetOffsets[index] = idleAdjustedOffset(
                index: index,
                baseOffset: classicOffset(
                    index: index,
                    count: members.count,
                    phase: members[index].phase,
                    radius: radius,
                    speedFactor: context.speedFactor,
                    motionDirection: context.motionDirection,
                    perpendicular: context.perpendicular
                ),
                context: context
            )
        }
        let classic = settings.classicParameters

        applyDynamics(
            context: context,
            targetOffsets: targetOffsets,
            cohesionStrength: parameters.cohesionStrength * classic.cohesion,
            separationStrength: parameters.separationStrength * classic.separation,
            alignmentStrength: parameters.alignmentStrength * classic.alignment,
            orbitStrength: parameters.orbitStrength,
            wanderStrength: parameters.wanderStrength * classic.wander
        )
    }

    private func updateVFormation(_ context: SimulationContext) {
        prepareTargetOffsets()
        for index in members.indices {
            targetOffsets[index] = idleAdjustedOffset(
                index: index,
                baseOffset: vFormationOffset(index: index, count: members.count, context: context),
                context: context
            )
        }

        applyDynamics(
            context: context,
            targetOffsets: targetOffsets,
            cohesionStrength: parameters.cohesionStrength * 1.12 * settings.vFormationParameters.formationRigidity,
            separationStrength: parameters.separationStrength,
            alignmentStrength: parameters.alignmentStrength * 0.65,
            orbitStrength: parameters.orbitStrength * 0.16,
            wanderStrength: parameters.wanderStrength * 0.32
        )
    }

    private func updateScatterAndReturn(_ context: SimulationContext) {
        prepareTargetOffsets()
        for index in members.indices {
            targetOffsets[index] = idleAdjustedOffset(
                index: index,
                baseOffset: scatterOffset(index: index, count: members.count, context: context),
                context: context
            )
        }

        applyDynamics(
            context: context,
            targetOffsets: targetOffsets,
            cohesionStrength: parameters.cohesionStrength * 0.96 * settings.scatterAndReturnParameters.returnStrength,
            separationStrength: parameters.separationStrength,
            alignmentStrength: parameters.alignmentStrength * 0.48,
            orbitStrength: parameters.orbitStrength * 0.26,
            wanderStrength: parameters.wanderStrength * 0.44
        )
    }

    private func updateOrbitingFlock(_ context: SimulationContext) {
        prepareTargetOffsets()
        for index in members.indices {
            targetOffsets[index] = idleAdjustedOffset(
                index: index,
                baseOffset: orbitingOffset(index: index, count: members.count, context: context),
                context: context
            )
        }

        applyDynamics(
            context: context,
            targetOffsets: targetOffsets,
            cohesionStrength: parameters.cohesionStrength * 1.05,
            separationStrength: parameters.separationStrength,
            alignmentStrength: parameters.alignmentStrength * 0.32,
            orbitStrength: parameters.orbitStrength * 0.10,
            wanderStrength: parameters.wanderStrength * 0.22
        )
    }

    private func applyDynamics(
        context: SimulationContext,
        targetOffsets: [CGVector],
        cohesionStrength: CGFloat,
        separationStrength: CGFloat,
        alignmentStrength: CGFloat,
        orbitStrength: CGFloat,
        wanderStrength: CGFloat
    ) {
        prepareMemberSnapshot()
        let averageVelocity = averageVelocity(of: memberSnapshot)
        let freezeBlend = settings.idleBehavior == .freeze ? context.idleBlend : 0
        let forceScale = 1 - freezeBlend * 0.88
        let organicScale = idleOrganicMotionScale(context: context)

        for index in members.indices {
            let targetOffset = targetOffsets[index].clamped(to: maximumRadius - 4)
            members[index].targetOffset = targetOffset

            let desiredPosition = clampedPosition(
                flockCenter + targetOffset,
                around: context.cursorPosition,
                maximumDistance: maximumRadius - 4
            )
            var acceleration = (desiredPosition - members[index].position) * cohesionStrength * forceScale

            acceleration += separationForce(
                for: index,
                in: memberSnapshot,
                strength: separationStrength
            )
            acceleration += alignmentForce(
                for: index,
                in: memberSnapshot,
                averageVelocity: averageVelocity,
                strength: alignmentStrength * forceScale
            )
            acceleration += organicForce(
                member: members[index],
                phase: members[index].phase,
                center: flockCenter,
                seed: deterministicUnit(index),
                orbitStrength: orbitStrength * organicScale,
                wanderStrength: wanderStrength * organicScale
            )
            acceleration += protectedZoneForce(
                memberPosition: members[index].position,
                cursorPosition: context.cursorPosition
            )
            acceleration += containmentForce(
                memberPosition: members[index].position,
                cursorPosition: context.cursorPosition
            )

            members[index].velocity += acceleration * context.dt
            members[index].velocity *= 1 / (1 + parameters.damping * (1 + freezeBlend * 4) * context.dt)
            members[index].velocity = members[index].velocity.clamped(
                to: maximumMemberSpeed(for: index)
            )
            members[index].position += members[index].velocity * context.dt
            containProtectedZone(at: index, around: context.cursorPosition)
        }

        updateEffectiveFlockRadius(cursorPosition: context.cursorPosition, dt: context.dt)

        for index in members.indices {
            updateScale(at: index, cursorPosition: context.cursorPosition, dt: context.dt)
            updateOpacity(at: index, cursorPosition: context.cursorPosition)
            updateOrientation(at: index, context: context)
        }
    }

    private func makeMembers(count: Int, around position: CGPoint, compact: Bool) -> [FlockMember] {
        let clampedCount = FlockSettings.clampedCursorCount(count)

        return (0..<clampedCount).map { index in
            makeMember(index: index, count: clampedCount, around: position, compact: compact)
        }
    }

    private func makeMember(
        index: Int,
        count: Int,
        around position: CGPoint,
        compact: Bool
    ) -> FlockMember {
        let seed = deterministicUnit(index)
        let phase = Double(seed) * .pi * 2
        let angle = (CGFloat(index) / CGFloat(max(count, 1))) * .pi * 2 + seed * 0.45
        let radius = compact
            ? 10 + seed * 18
            : parameters.idleRadius * (0.72 + seed * 0.44)
        let offset = CGVector(dx: cos(angle) * radius, dy: sin(angle) * radius)

        return FlockMember(
            seed: seed,
            position: position + offset,
            velocity: .zero,
            targetOffset: offset,
            phase: phase,
            opacity: parameters.maxOpacity,
            scale: parameters.maxScale,
            angleRadians: 0,
            formationSide: index.isMultiple(of: 2) ? -1 : 1,
            formationRank: CGFloat(index / 2 + 1)
        )
    }

    private func ensureMemberCount(cursorPosition: CGPoint) {
        let targetCount = FlockSettings.clampedCursorCount(settings.cursorCount)

        if members.isEmpty {
            members = makeMembers(count: targetCount, around: cursorPosition, compact: false)
            prepareTargetOffsets()
            return
        }

        if members.count < targetCount {
            let startIndex = members.count
            for index in startIndex..<targetCount {
                members.append(
                    makeMember(
                        index: index,
                        count: targetCount,
                        around: flockCenter,
                        compact: true
                    )
                )
            }
        } else if members.count > targetCount {
            members.removeLast(members.count - targetCount)
        }
        prepareTargetOffsets()
    }

    private func prepareTargetOffsets() {
        let maximumMemberCount = FlockSettings.clampedCursorCount(30)
        if targetOffsets.capacity < maximumMemberCount {
            targetOffsets.reserveCapacity(maximumMemberCount)
        }
        if targetOffsets.count < members.count {
            targetOffsets.append(
                contentsOf: repeatElement(.zero, count: members.count - targetOffsets.count)
            )
        }
    }

    private func prepareMemberSnapshot() {
        let maximumMemberCount = FlockSettings.clampedCursorCount(30)
        if memberSnapshot.capacity < maximumMemberCount {
            memberSnapshot.reserveCapacity(maximumMemberCount)
        }
        memberSnapshot.removeAll(keepingCapacity: true)
        memberSnapshot.append(contentsOf: members)
    }

    private func updatePointerVelocity(_ cursorVelocity: CGVector, dt: CGFloat) {
        let blend = min(1, dt * 10)
        pointerVelocity = pointerVelocity.interpolated(to: cursorVelocity, amount: blend)
    }

    private func updateIdleState(dt: CGFloat) {
        if pointerVelocity.length < 16 {
            idleElapsedTime += dt
        } else {
            idleElapsedTime = 0
        }

        let targetBlend: CGFloat = idleElapsedTime >= CGFloat(settings.idleDelaySeconds) ? 1 : 0
        let blend = min(1, dt * 3.8)
        idleBlend += (targetBlend - idleBlend) * blend
    }

    private func updateFlockCenter(cursorPosition: CGPoint, dt: CGFloat) {
        (flockCenter, centerVelocity) = springStep(
            position: flockCenter,
            velocity: centerVelocity,
            target: cursorPosition,
            dt: dt,
            angularFrequency: parameters.centerAngularFrequency,
            dampingRatio: parameters.centerDampingRatio
        )

        let offset = flockCenter - cursorPosition
        let distance = offset.length

        guard distance > parameters.maximumCenterLag, distance > 0 else {
            return
        }

        let normal = offset * (1 / distance)
        flockCenter = cursorPosition + normal * parameters.maximumCenterLag
        let outwardVelocity = centerVelocity.dot(normal)
        if outwardVelocity > 0 {
            centerVelocity -= normal * outwardVelocity
        }
    }

    private func updateFormationHeading(dt: CGFloat) {
        guard pointerVelocity.length > 18 else {
            return
        }

        let blend = min(1, dt * 5.5)
        let nextHeading = formationHeading.interpolated(
            to: pointerVelocity.normalized,
            amount: blend
        )
        formationHeading = nextHeading.lengthSquared > 0.001
            ? nextHeading.normalized
            : formationHeading
    }

    private func advancePhases(dt: CGFloat) {
        let idlePhaseScale: CGFloat
        switch settings.idleBehavior {
        case .gather, .fade:
            idlePhaseScale = 1 - idleBlend * (1 - settings.idleMotionScale)
        case .slowOrbit:
            idlePhaseScale = 1 - idleBlend * 0.72
        case .freeze:
            idlePhaseScale = 1 - idleBlend
        }

        for index in members.indices {
            let seed = members[index].seed
            let multiplier: CGFloat
            switch settings.pattern {
            case .classicFlock:
                multiplier = 1
            case .vFormation:
                multiplier = 0.75
            case .scatterAndReturn:
                multiplier = 1.08
            case .orbitingFlock:
                multiplier = 1.45 * settings.orbitingFlockParameters.orbitSpeed
            }

            members[index].phase += Double(dt * multiplier * idlePhaseScale * (0.75 + 0.55 * seed))
        }
    }

    private func makeContext(
        cursorPosition: CGPoint,
        dt: CGFloat,
        cursorCanRotate: Bool
    ) -> SimulationContext {
        let speed = pointerVelocity.length
        let speedFactor = smoothstep(min(max(speed / 1250, 0), 1))
        let direction = pointerVelocity.lengthSquared > 1
            ? pointerVelocity.normalized
            : formationHeading

        return SimulationContext(
            dt: dt,
            cursorPosition: cursorPosition,
            speed: speed,
            speedFactor: speedFactor,
            motionDirection: direction,
            heading: formationHeading,
            perpendicular: CGVector(dx: -direction.dy, dy: direction.dx),
            cursorCanRotate: cursorCanRotate,
            idleBlend: idleBlend
        )
    }

    private func classicOffset(
        index: Int,
        count: Int,
        phase: Double,
        radius: CGFloat,
        speedFactor: CGFloat,
        motionDirection: CGVector,
        perpendicular: CGVector
    ) -> CGVector {
        let seed = members[index].seed
        let baseAngle = CGFloat(index) / CGFloat(max(count, 1)) * .pi * 2
        let phaseAngle = CGFloat(phase)
        let orbitAngle = baseAngle + sin(phaseAngle * 0.73 + seed * 5.1) * 0.38
        let radialJitter = 0.76 + 0.28 * sin(phaseAngle * 0.91 + seed * 7.3)
        let localRadius = radius * radialJitter
        let circular = CGVector(dx: cos(orbitAngle) * localRadius, dy: sin(orbitAngle) * localRadius)

        guard motionDirection.lengthSquared > 0 else {
            return circular
        }

        let side = sin(seed * .pi * 2)
        let frontBack = cos(seed * .pi * 2) * 0.45
        let spread = parameters.directionalSpread * speedFactor
        return circular
            + perpendicular * (side * spread)
            + motionDirection * (frontBack * spread)
    }

    private func vFormationOffset(
        index: Int,
        count: Int,
        context: SimulationContext
    ) -> CGVector {
        let compact = compactOffset(
            index: index,
            count: count,
            phase: members[index].phase,
            radius: parameters.idleRadius * 0.72
        )
        let formationAmount = smoothstep(min(max((context.speed - 80) / 700, 0), 1))

        guard formationAmount > 0.001 else {
            return compact
        }

        let vParameters = settings.vFormationParameters
        let wingAngle: CGFloat = vParameters.wingAngleDegrees * .pi / 180
        let side = members[index].formationSide
        let rank = members[index].formationRank
        let backDirection = context.heading * -1
        let wingDirection = backDirection.rotated(by: side * wingAngle).normalized
        let distance = min((44 + rank * 14) * vParameters.wingSpacing, maximumRadius - 18)
        let seed = members[index].seed
        let wingOffset = wingDirection * distance
            + context.perpendicular * (side * (4 + seed * 6))

        return lerp(compact, wingOffset, amount: formationAmount)
    }

    private func scatterOffset(
        index: Int,
        count: Int,
        context: SimulationContext
    ) -> CGVector {
        let seed = members[index].seed
        let phase = CGFloat(members[index].phase)
        let scatterParameters = settings.scatterAndReturnParameters
        let scatterSpeed = min(max(context.speedFactor * scatterParameters.scatterSensitivity, 0), 1)
        let radius = parameters.idleRadius * 0.62
            + (maximumRadius * 0.78 - parameters.idleRadius * 0.62) * scatterSpeed
        let baseAngle = CGFloat(index) / CGFloat(max(count, 1)) * .pi * 2
        let angle = baseAngle
            + seed * 0.52
            + sin(phase * 0.85 + seed * 9.2) * 0.34
        let jitter = 0.72 + 0.42 * seed + 0.12 * sin(phase * 1.2 + seed * 6.4)
        let circular = CGVector(
            dx: cos(angle) * radius * jitter,
            dy: sin(angle) * radius * jitter
        )
        let directionalSpread = context.motionDirection
            * ((seed - 0.5) * parameters.directionalSpread * scatterSpeed * 1.5)

        return circular + directionalSpread
    }

    private func orbitingOffset(
        index: Int,
        count: Int,
        context: SimulationContext
    ) -> CGVector {
        let seed = members[index].seed
        let orbitParameters = settings.orbitingFlockParameters
        let bandIndex = index % max(orbitParameters.orbitBandCount, 1)
        let bandFraction = CGFloat(bandIndex) / CGFloat(max(orbitParameters.orbitBandCount - 1, 1))
        let bandRadius = (48 + 34 * bandFraction) * orbitParameters.orbitRadius
        let direction: CGFloat = seed > 0.5 ? 1 : -1
        let baseAngle = CGFloat(index) / CGFloat(max(count, 1)) * .pi * 2
        let phase = CGFloat(members[index].phase)
        let angle = baseAngle
            + phase * direction * (0.9 + seed * 0.55)
            + sin(phase * 0.63 + seed * 4.8) * 0.16
        let radius = bandRadius
            + context.speedFactor * 18
            + sin(phase * 1.1 + seed * 7.5) * 5
        let orbit = CGVector(dx: cos(angle) * radius, dy: sin(angle) * radius)
        let responsiveness = context.motionDirection * (context.speedFactor * (seed - 0.5) * 18)

        return orbit + responsiveness
    }

    private func compactOffset(
        index: Int,
        count: Int,
        phase: Double,
        radius: CGFloat
    ) -> CGVector {
        let seed = members[index].seed
        let angle = CGFloat(index) / CGFloat(max(count, 1)) * .pi * 2
            + sin(CGFloat(phase) * 0.8 + seed * 6.3) * 0.25
        let localRadius = radius * (0.65 + seed * 0.28)
        return CGVector(dx: cos(angle) * localRadius, dy: sin(angle) * localRadius)
    }

    private func idleAdjustedOffset(
        index: Int,
        baseOffset: CGVector,
        context: SimulationContext
    ) -> CGVector {
        guard context.idleBlend > 0 else {
            return baseOffset
        }

        let seed = members[index].seed
        let phase = CGFloat(members[index].phase)

        switch settings.idleBehavior {
        case .gather:
            var compactRadius = parameters.idleRadius * 0.52
            if settings.pattern == .scatterAndReturn {
                compactRadius /= max(settings.scatterAndReturnParameters.idleCompactness, 0.1)
            }
            let compact = compactOffset(
                index: index,
                count: members.count,
                phase: members[index].phase,
                radius: compactRadius
            )
            return lerp(baseOffset, compact, amount: context.idleBlend)

        case .slowOrbit:
            let baseAngle = CGFloat(index) / CGFloat(max(members.count, 1)) * .pi * 2
            let orbitAngle = baseAngle
                + phase * (seed > 0.5 ? 0.32 : -0.32)
                + sin(phase * 0.4 + seed * 4.2) * 0.12
            let orbitRadius = parameters.idleRadius * (0.48 + seed * 0.22)
            let orbit = CGVector(dx: cos(orbitAngle) * orbitRadius, dy: sin(orbitAngle) * orbitRadius)
            return lerp(baseOffset, orbit, amount: context.idleBlend)

        case .fade:
            return baseOffset

        case .freeze:
            let currentOffset = members[index].position - flockCenter
            return lerp(baseOffset, currentOffset, amount: context.idleBlend)
        }
    }

    private func idleOrganicMotionScale(context: SimulationContext) -> CGFloat {
        guard context.idleBlend > 0 else {
            return 1
        }

        let targetScale: CGFloat
        switch settings.idleBehavior {
        case .gather, .fade:
            targetScale = settings.idleMotionScale
        case .slowOrbit:
            targetScale = max(settings.idleMotionScale, 0.18)
        case .freeze:
            targetScale = 0
        }

        return 1 - context.idleBlend * (1 - targetScale)
    }

    private func separationForce(
        for index: Int,
        in snapshot: [FlockMember],
        strength: CGFloat
    ) -> CGVector {
        var force = CGVector.zero
        let currentPosition = snapshot[index].position

        for otherIndex in snapshot.indices where otherIndex != index {
            let delta = currentPosition - snapshot[otherIndex].position
            let distance = max(delta.length, 0.001)
            guard distance < parameters.separationDistance else {
                continue
            }

            let separationAmount = 1 - distance / parameters.separationDistance
            force += delta * (strength * separationAmount / distance)
        }

        return force
    }

    private func alignmentForce(
        for index: Int,
        in snapshot: [FlockMember],
        averageVelocity: CGVector,
        strength: CGFloat
    ) -> CGVector {
        var nearbyVelocity = CGVector.zero
        var nearbyCount: CGFloat = 0
        let currentPosition = snapshot[index].position

        for otherIndex in snapshot.indices where otherIndex != index {
            let distance = currentPosition.distance(to: snapshot[otherIndex].position)
            guard distance < parameters.neighborRadius else {
                continue
            }

            nearbyVelocity += snapshot[otherIndex].velocity
            nearbyCount += 1
        }

        let targetVelocity = nearbyCount > 0 ? nearbyVelocity * (1 / nearbyCount) : averageVelocity
        return (targetVelocity - snapshot[index].velocity) * strength
    }

    private func organicForce(
        member: FlockMember,
        phase: Double,
        center: CGPoint,
        seed: CGFloat,
        orbitStrength: CGFloat,
        wanderStrength: CGFloat
    ) -> CGVector {
        let radial = member.position - center
        let radialNormal = radial.lengthSquared > 0.01 ? radial.normalized : unitVector(seed)
        let tangent = CGVector(dx: -radialNormal.dy, dy: radialNormal.dx)
        let orbitDirection: CGFloat = seed > 0.5 ? 1 : -1
        let wander = CGVector(
            dx: cos(CGFloat(phase) * 1.37 + seed * 8.1),
            dy: sin(CGFloat(phase) * 1.11 + seed * 5.7)
        )

        return tangent * (orbitStrength * orbitDirection)
            + wander * wanderStrength
    }

    private func protectedZoneForce(memberPosition: CGPoint, cursorPosition: CGPoint) -> CGVector {
        let delta = memberPosition - cursorPosition
        let distance = max(delta.length, 0.001)
        guard distance < parameters.protectedRadius else {
            return .zero
        }

        let strength = 1 - distance / parameters.protectedRadius
        return delta * (parameters.protectedZoneStrength * strength / distance)
    }

    private func containmentForce(memberPosition: CGPoint, cursorPosition: CGPoint) -> CGVector {
        let offset = memberPosition - cursorPosition
        let distance = offset.length
        guard distance > maximumRadius, distance > 0 else {
            return .zero
        }

        let excess = distance - maximumRadius
        let normal = offset * (1 / distance)
        return normal * (-parameters.containmentStrength * excess)
    }

    private func maximumMemberSpeed(for index: Int) -> CGFloat {
        settings.speedSettings.maximumSpeed(forNormalizedSeed: members[index].seed)
    }

    private func containProtectedZone(at index: Int, around cursorPosition: CGPoint) {
        let offset = members[index].position - cursorPosition
        let distance = offset.length

        if distance < parameters.protectedRadius, distance > 0 {
            let normal = offset * (1 / distance)
            members[index].position = cursorPosition + normal * parameters.protectedRadius
            let inwardVelocity = members[index].velocity.dot(normal)
            if inwardVelocity < 0 {
                members[index].velocity -= normal * inwardVelocity
            }
        } else if distance == 0 {
            let normal = unitVector(members[index].seed)
            members[index].position = cursorPosition + normal * parameters.protectedRadius
            members[index].velocity = .zero
        }
    }

    private func updateEffectiveFlockRadius(cursorPosition: CGPoint, dt: CGFloat) {
        let maximumDistance = members.reduce(parameters.idleRadius) { partialResult, member in
            max(partialResult, member.position.distance(to: cursorPosition))
        }
        let targetRadius = min(max(maximumDistance, parameters.idleRadius), maximumRadius)
        let blend = min(1, dt * 4)
        smoothedEffectiveFlockRadius += (targetRadius - smoothedEffectiveFlockRadius) * blend
    }

    private func updateScale(at index: Int, cursorPosition: CGPoint, dt: CGFloat) {
        let scaleSettings = settings.scaleSettings
        let targetScale: CGFloat
        let distance = members[index].position.distance(to: cursorPosition)
        let seed = members[index].seed

        switch scaleSettings.mode {
        case .uniform:
            targetScale = scaleSettings.baseScale

        case .distanceScale:
            let normalizedDistance = min(max(distance / max(smoothedEffectiveFlockRadius, 1), 0), 1)
            let smoothDistance = smoothstep(normalizedDistance)
            targetScale = scaleSettings.maximumScale
                + (scaleSettings.minimumScale - scaleSettings.maximumScale) * smoothDistance

        case .subtleVariation:
            let variation = (seed - 0.5) * 2 * scaleSettings.variationAmount
            targetScale = scaleSettings.baseScale + variation
        }

        let clampedScale = ScaleSettings.clampedScale(targetScale)
        let blend = min(1, dt * 10)
        members[index].scale += (clampedScale - members[index].scale) * blend
    }

    private func updateOpacity(at index: Int, cursorPosition: CGPoint) {
        let opacitySettings = settings.opacitySettings

        switch opacitySettings.mode {
        case .solid:
            members[index].opacity = 1
        case .distanceFade:
            let distance = members[index].position.distance(to: cursorPosition)
            let normalizedDistance = min(
                max(distance / max(smoothedEffectiveFlockRadius, 1), 0),
                1
            )
            let fade = pow(1 - normalizedDistance, opacitySettings.fadeExponent)
            members[index].opacity = opacitySettings.minimumOpacity
                + (opacitySettings.baseOpacity - opacitySettings.minimumOpacity) * fade
            members[index].opacity = OpacitySettings.clampedOpacity(members[index].opacity)
        }

        if settings.idleBehavior == .fade, idleBlend > 0 {
            let targetOpacity = settings.idleFadeOpacity
            members[index].opacity += (targetOpacity - members[index].opacity) * idleBlend
            members[index].opacity = OpacitySettings.clampedOpacity(members[index].opacity)
        }
    }

    private func updateOrientation(at index: Int, context: SimulationContext) {
        guard context.cursorCanRotate || settings.rotationEligibilityMode == .allowAllCursors else {
            members[index].angleRadians = 0
            return
        }

        switch settings.orientationMode {
        case .preserveSystemOrientation:
            members[index].angleRadians = 0
        case .alignToGroupDirection:
            let targetAngle = rotationTargetAngle(for: context.heading)
            members[index].angleRadians = smoothedAngle(
                from: members[index].angleRadians,
                to: targetAngle,
                dt: context.dt
            )
        case .alignToIndividualDirection:
            guard members[index].velocity.length > 8 else {
                return
            }

            let targetAngle = rotationTargetAngle(for: members[index].velocity.normalized)
            members[index].angleRadians = smoothedAngle(
                from: members[index].angleRadians,
                to: targetAngle,
                dt: context.dt
            )
        }
    }

    private func rotationTargetAngle(for direction: CGVector) -> CGFloat {
        guard direction.lengthSquared > 0.0001 else {
            return 0
        }

        let movementAngle = atan2(direction.dy, direction.dx)
        let intrinsicCursorForwardAngle = settings.baseAxisAdjustmentDegrees * .pi / 180
        let targetAngle = movementAngle - intrinsicCursorForwardAngle
        return shortestAngle(from: 0, to: targetAngle) * settings.rotationStrength
    }

    private func smoothedAngle(from current: CGFloat, to target: CGFloat, dt: CGFloat) -> CGFloat {
        let frameAdjustedSmoothing = 1 - pow(1 - settings.turnSmoothing, dt * 60)
        let delta = shortestAngle(from: current, to: target)
        return current + delta * min(max(frameAdjustedSmoothing, 0), 1)
    }

    private func shortestAngle(from start: CGFloat, to end: CGFloat) -> CGFloat {
        var delta = end - start
        while delta > .pi {
            delta -= .pi * 2
        }
        while delta < -.pi {
            delta += .pi * 2
        }
        return delta
    }

    private func averageVelocity(of snapshot: [FlockMember]) -> CGVector {
        guard !snapshot.isEmpty else {
            return .zero
        }

        let total = snapshot.reduce(CGVector.zero) { $0 + $1.velocity }
        return total * (1 / CGFloat(snapshot.count))
    }

    private func springStep(
        position: CGPoint,
        velocity: CGVector,
        target: CGPoint,
        dt: CGFloat,
        angularFrequency: CGFloat,
        dampingRatio: CGFloat
    ) -> (CGPoint, CGVector) {
        let f = 1 + 2 * dt * dampingRatio * angularFrequency
        let oo = angularFrequency * angularFrequency
        let hoo = dt * oo
        let hhoo = dt * hoo
        let determinantInverse = 1 / (f + hhoo)

        let newX = (f * position.x + dt * velocity.dx + hhoo * target.x) * determinantInverse
        let newY = (f * position.y + dt * velocity.dy + hhoo * target.y) * determinantInverse
        let newVelocityX = (velocity.dx + hoo * (target.x - position.x)) * determinantInverse
        let newVelocityY = (velocity.dy + hoo * (target.y - position.y)) * determinantInverse

        return (
            CGPoint(x: newX, y: newY),
            CGVector(dx: newVelocityX, dy: newVelocityY)
        )
    }

    private func deterministicUnit(_ index: Int) -> CGFloat {
        let value = sin(CGFloat(index + 1) * 12.9898 + 78.233) * 43758.5453
        return value - floor(value)
    }

    private func unitVector(_ seed: CGFloat) -> CGVector {
        let angle = seed * .pi * 2
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    private func smoothstep(_ value: CGFloat) -> CGFloat {
        value * value * (3 - 2 * value)
    }

    private func lerp(_ start: CGVector, _ end: CGVector, amount: CGFloat) -> CGVector {
        start + (end - start) * min(max(amount, 0), 1)
    }

    private func clampedPosition(
        _ position: CGPoint,
        around origin: CGPoint,
        maximumDistance: CGFloat
    ) -> CGPoint {
        let offset = position - origin
        let distance = offset.length
        guard distance > maximumDistance, distance > 0 else {
            return position
        }

        return origin + offset * (maximumDistance / distance)
    }
}

private struct SimulationContext {
    let dt: CGFloat
    let cursorPosition: CGPoint
    let speed: CGFloat
    let speedFactor: CGFloat
    let motionDirection: CGVector
    let heading: CGVector
    let perpendicular: CGVector
    let cursorCanRotate: Bool
    let idleBlend: CGFloat
}

private func + (point: CGPoint, vector: CGVector) -> CGPoint {
    CGPoint(x: point.x + vector.dx, y: point.y + vector.dy)
}

private func += (lhs: inout CGPoint, rhs: CGVector) {
    lhs = lhs + rhs
}

private func - (lhs: CGPoint, rhs: CGPoint) -> CGVector {
    CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
}

private func + (lhs: CGVector, rhs: CGVector) -> CGVector {
    CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
}

private func += (lhs: inout CGVector, rhs: CGVector) {
    lhs = lhs + rhs
}

private func - (lhs: CGVector, rhs: CGVector) -> CGVector {
    CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
}

private func -= (lhs: inout CGVector, rhs: CGVector) {
    lhs = lhs - rhs
}

private func * (vector: CGVector, scalar: CGFloat) -> CGVector {
    CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
}

private func * (scalar: CGFloat, vector: CGVector) -> CGVector {
    vector * scalar
}

private func *= (lhs: inout CGVector, rhs: CGFloat) {
    lhs = lhs * rhs
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        (self - other).length
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

        return self * (1 / length)
    }

    func clamped(to maximumLength: CGFloat) -> CGVector {
        let currentLength = length
        guard currentLength > maximumLength, currentLength > 0 else {
            return self
        }

        return self * (maximumLength / currentLength)
    }

    func interpolated(to other: CGVector, amount: CGFloat) -> CGVector {
        self + (other - self) * amount
    }

    func rotated(by angle: CGFloat) -> CGVector {
        let cosine = cos(angle)
        let sine = sin(angle)
        return CGVector(
            dx: dx * cosine - dy * sine,
            dy: dx * sine + dy * cosine
        )
    }

    func dot(_ other: CGVector) -> CGFloat {
        dx * other.dx + dy * other.dy
    }
}
