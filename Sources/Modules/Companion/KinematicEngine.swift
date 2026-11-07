import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Full-Screen Choreographed Route Stages
public enum ScreenRouteStage: String, Equatable {
    case leftWalk               // Walking along left ledge line toward notch
    case approachNotch          // Stops at left notch edge, looks at gap
    case lowerToHang            // Reaches hands over, lowers body to hang under notch
    case monkeyBarTraversal     // Moving hand-over-hand along bottom edge of notch
    case climbOntoRightLedge    // Reaches up, leg hook, rolls onto right ledge
    case rightWalk              // Walking along right ledge toward right corner
    case farCornerPeek          // At far corner, peeks, pivots feet, turns
    case routeComplete          // Safe endpoint after the far-corner turn
}

// MARK: - Kinematic Character Animation Engine
@MainActor
public final class KinematicEngine: ObservableObject {
    public static let shared = KinematicEngine()
    
    // Output Current Pose (Single clock, single pose)
    @Published public var currentPose: SkeletonPose = SkeletonPose()
    
    // Route & Behavior State
    public private(set) var currentBehavior: CompanionBehaviorState = .inDen
    private var mirroredRoute = false
    public private(set) var routeStage: ScreenRouteStage = .leftWalk
    public private(set) var completedRouteCount = 0
    public private(set) var behaviorTime: Double = 0.0
    public private(set) var isPullingUpWorkout: Bool = false
    
    // Screen & Notch Geometry Cache
    public var screenWidth: CGFloat = 1470.0
    public var screenHeight: CGFloat = 956.0
    public var notchLeft: CGFloat = 645.5
    public var notchRight: CGFloat = 824.5
    public var notchHeight: CGFloat = 32.0
    public var hasPhysicalNotch: Bool = true
    public var ledgeY: CGFloat { notchHeight }
    private var walkLedgeY: CGFloat { ledgeY + 24.0 }
    
    // Gait Variables (Strict Inverted Pendulum)
    public private(set) var walkStepPhase: Double = 0.0
    public private(set) var isLeftFootPlanted: Bool = true
    public private(set) var leftFootWorldX: CGFloat = 40.0
    public private(set) var leftFootWorldY: CGFloat = 56.0
    public private(set) var rightFootWorldX: CGFloat = 52.0
    public private(set) var rightFootWorldY: CGFloat = 56.0
    public private(set) var rootWorldX: CGFloat = 46.0
    public private(set) var walkStepLength: CGFloat = 12.0
    public private(set) var walkStepDuration: Double = 0.36
    public private(set) var walkDirection: CGFloat = 1.0 // +1 = right, -1 = left
    private var hangStartX: CGFloat = 0.0
    private var hangStartY: CGFloat = 0.0
    private var targetHangX: CGFloat = 0.0
    private var climbStartX: CGFloat = 0.0
    private var climbStartY: CGFloat = 0.0
    private var approachStartX: CGFloat = 0.0
    private var approachStartY: CGFloat = 0.0
    private var approachStartHeadY: CGFloat = 0.0
    private var pullUpStartY: CGFloat = 0.0
    private var turnStartX: CGFloat = 0.0
    private var turnStartY: CGFloat = 0.0
    private var crawlStepPhase: Double = 0.0
    private var crawlSupportPhase = false
    private var crawlRootStartX: CGFloat = 46.0
    private var crawlDirection: CGFloat = 1.0
    private var crawlWingIsLeft = true
    private var crawlBoundary: CGFloat = 0.0
    private var crawlStride: CGFloat = 14.0
    
    // Monkey-Bar Traversal Variables (Strict Hand-over-Hand Pinning)
    public private(set) var monkeyBarProgress: CGFloat = 0.0
    public private(set) var activeGrippingHand: Int = 0 // 0 = Left gripping, 1 = Right gripping
    public private(set) var handLWorldX: CGFloat = 650.0
    public private(set) var handRWorldX: CGFloat = 664.0
    public private(set) var monkeyBarReach: CGFloat = 14.0
    public private(set) var monkeyBarStepPhase: Double = 0.0
    private var monkeyBarReachStartX: CGFloat = 0.0
    public private(set) var pendulumAngle: Double = 0.0
    public private(set) var pendulumVelocity: Double = 0.0
    
    // Spring Physics
    private var headAngleSpring = SpringDamper(stiffness: 140.0, damping: 16.0)
    private var eyeTrackXSpring = SpringDamper(stiffness: 180.0, damping: 18.0)
    private var eyeTrackYSpring = SpringDamper(stiffness: 180.0, damping: 18.0)
    
    // Eye Blinking & Breathing
    private var blinkTimer: Double = 3.2
    private var blinkDurationRemaining: Double = 0.0
    private var isBlinking: Bool = false
    private var breathingCycle: Double = 0.0
    
    public init() {
        refreshScreenGeometry()
        resetToDen()
    }
    
    public func refreshScreenGeometry() {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]
        screenWidth = screen.frame.width
        screenHeight = screen.frame.height
        
        let insets = screen.safeAreaInsets
        hasPhysicalNotch = insets.top > 0
        notchHeight = hasPhysicalNotch ? insets.top : 24.0
        
        if hasPhysicalNotch, let tl = screen.auxiliaryTopLeftArea, let tr = screen.auxiliaryTopRightArea {
            notchLeft = tl.maxX - screen.frame.minX
            notchRight = tr.minX - screen.frame.minX
        } else {
            let notchW: CGFloat = hasPhysicalNotch ? 179.0 : 0.0
            notchLeft = (screenWidth - notchW) / 2.0
            notchRight = (screenWidth + notchW) / 2.0
        }
    }

    private func visibleRouteHead(at point: CGPoint, allowPullUp: Bool = false) -> CGPoint {
        guard hasPhysicalNotch, point.x + 16 > notchLeft, point.x - 16 < notchRight else { return point }
        if allowPullUp { return point }
        return CGPoint(x: point.x, y: max(point.y, ledgeY + 12.0))
    }

    private func visibleBodyRoot(at point: CGPoint) -> CGPoint {
        guard hasPhysicalNotch, point.x + 12.0 > notchLeft, point.x - 12.0 < notchRight else { return point }
        return CGPoint(x: point.x, y: max(point.y, ledgeY + 24.0))
    }
    
    // MARK: - State Setting
    public func setBehavior(_ behavior: CompanionBehaviorState, startingFromRight: Bool = false) {
        let previousBehavior = currentBehavior
        let preserveGrip = [.walking, .dangling, .slipping, .pullingUp].contains(previousBehavior)
            && [.lowerToHang, .monkeyBarTraversal, .climbOntoRightLedge].contains(routeStage)
        currentBehavior = behavior
        behaviorTime = 0.0
        mirroredRoute = false
        
        switch behavior {
        case .inDen:
            resetToDen()
        case .walking:
            setupFullRouteWalk(startingFromRight: startingFromRight)
        case .dangling, .slipping:
            setupHanging(preservingGrip: preserveGrip)
        case .peekingLeft:
            setupPeek(side: -1.0)
        case .peekingRight:
            setupPeek(side: 1.0)
        case .thinking, .curious:
            setupThinking()
        case .pullingUp:
            pullUpStartY = max(currentPose.root.y, ledgeY + 60.0)
        case .crawling:
            crawlStepPhase = 0.0
            crawlSupportPhase = false
            let startsNearNotch = hasPhysicalNotch && rootWorldX >= notchLeft - 42.0 && rootWorldX <= notchRight + 42.0
            if startsNearNotch { rootWorldX = rootWorldX < (notchLeft + notchRight) / 2.0 ? notchLeft - 42.0 : notchRight + 42.0 }
            crawlRootStartX = rootWorldX
            crawlWingIsLeft = !hasPhysicalNotch || rootWorldX < notchLeft
            crawlDirection = startsNearNotch
                ? (crawlWingIsLeft ? -1.0 : 1.0)
                : (hasPhysicalNotch ? (crawlWingIsLeft ? 1.0 : -1.0) : (rootWorldX < screenWidth / 2.0 ? 1.0 : -1.0))
            crawlBoundary = hasPhysicalNotch
                ? (crawlWingIsLeft ? (crawlDirection > 0 ? notchLeft - 42.0 : 44.0) : (crawlDirection < 0 ? notchRight + 42.0 : screenWidth - 44.0))
                : (crawlDirection > 0 ? screenWidth - 44.0 : 44.0)
            crawlStride = nextCrawlStride()
        case .sleeping:
            setupSleeping()
        case .typingMimic:
            setupTyping()
        case .musicGroove:
            setupMusicGroove()
        case .celebrating:
            setupCelebrating()
        }
    }
    
    private func resetToDen() {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.root = CGPoint(x: (notchLeft + notchRight) / 2.0, y: -45)
        pose.headCenter = CGPoint(x: pose.root.x, y: -58)
        pose.leftEyeOpen = 0.0
        pose.rightEyeOpen = 0.0
        currentPose = pose
    }
    
    private func setupFullRouteWalk(startingFromRight: Bool = false) {
        if startingFromRight {
            walkDirection = -1.0
            rootWorldX = screenWidth - 45.0
            isLeftFootPlanted = true
            leftFootWorldX = rootWorldX
            leftFootWorldY = walkLedgeY
            rightFootWorldX = rootWorldX + walkStepLength
            rightFootWorldY = walkLedgeY
            routeStage = .rightWalk
        } else {
            walkDirection = 1.0
            rootWorldX = 35.0
            isLeftFootPlanted = true
            leftFootWorldX = rootWorldX
            leftFootWorldY = walkLedgeY
            rightFootWorldX = rootWorldX - walkStepLength
            rightFootWorldY = walkLedgeY
            routeStage = .leftWalk
        }
        walkStepPhase = 0.0
        isPullingUpWorkout = false
    }
    
    private func setupHanging(preservingGrip: Bool = false) {
        if !preservingGrip {
            routeStage = .lowerToHang
            let midX = (notchLeft + notchRight) / 2.0
            rootWorldX = midX
            handLWorldX = midX - 14.0
            handRWorldX = midX + 14.0
        } else {
            rootWorldX = (handLWorldX + handRWorldX) / 2.0
        }
        pendulumAngle = 0.12
        pendulumVelocity = 0.9
    }
    
    private func setupPeek(side: CGFloat) {
        rootWorldX = (side < 0) ? (notchLeft - 12.0) : (notchRight + 12.0)
    }
    
    private func setupThinking() {
        headAngleSpring.target = 0.12
    }
    
    private func setupSleeping() {
        rootWorldX = (notchLeft + notchRight) / 2.0
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = true
        pose.torso.spineAngle = 0.0
        pose.torso.spineLength = 14.0
        pose.torso.root = CGPoint(x: rootWorldX, y: walkLedgeY - 6.0)
        pose.headCenter = CGPoint(x: pose.torso.neck.x + 3.0, y: walkLedgeY - 4.0)
        pose.leftEyeOpen = 0.0
        pose.rightEyeOpen = 0.0
        pose.mouthShape = .openW
        currentPose = pose
    }
    
    private func setupTyping() {
        currentPose.mouthShape = .openW
    }
    
    private func setupMusicGroove() {
        currentPose.mouthShape = .smile
    }
    
    private func setupCelebrating() {
        currentPose.mouthShape = .smile
    }
    
    // MARK: - Single-Clock Frame Update
    public func update(deltaTime: Double, cursorScreenPos: CGPoint) {
        let dt = min(0.05, max(0.001, deltaTime))
        behaviorTime += dt
        
        // 1. Natural Breathing Cycle
        breathingCycle += dt * 2.2
        
        // 2. Periodic Blinking
        if isBlinking {
            blinkDurationRemaining -= dt
            if blinkDurationRemaining <= 0 {
                isBlinking = false
            }
        } else {
            blinkTimer -= dt
            if blinkTimer <= 0 {
                isBlinking = true
                blinkDurationRemaining = 0.12
                blinkTimer = Double.random(in: 2.8...5.0)
            }
        }
        
        // 3. Compute Pose from Timeline
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        
        switch currentBehavior {
        case .inDen:
            pose = currentPose
            pose.timestamp = behaviorTime
            pose.root.y = -45
            
        case .walking:
            pose = evaluateContinuousRoute(dt: dt)
            
        case .dangling, .slipping:
            pose = evaluateHangingUnderNotch(dt: dt)

        case .pullingUp:
            pose = evaluatePullingUp()
            
        case .peekingLeft:
            pose = evaluatePeek(side: -1.0, dt: dt)
            
        case .peekingRight:
            pose = evaluatePeek(side: 1.0, dt: dt)
            
        case .thinking, .curious:
            pose = evaluateThinking(dt: dt, cursorScreenPos: cursorScreenPos)
            
        case .sleeping:
            pose = evaluateSleeping(dt: dt)
            
        case .typingMimic:
            pose = evaluateTyping(dt: dt)
            
        case .musicGroove:
            pose = evaluateMusicGroove(dt: dt)
            
        case .celebrating:
            pose = evaluateCelebrating(dt: dt)
            
        case .crawling:
            pose = evaluateCrawling(dt: dt)
        }
        
        if isBlinking {
            if pose.leftEyeOpen > 0 { pose.leftEyeOpen = 0.0 }
            if pose.rightEyeOpen > 0 { pose.rightEyeOpen = 0.0 }
        }

        if mirroredRoute && [.walking, .dangling, .slipping, .pullingUp].contains(currentBehavior) {
            pose = mirrored(pose)
        }
        pose = keepInsideScreen(pose)
        
        currentPose = pose
    }

    private func mirrored(_ source: SkeletonPose) -> SkeletonPose {
        var pose = source
        func reflect(_ point: CGPoint) -> CGPoint { CGPoint(x: screenWidth - point.x, y: point.y) }
        func reflect(_ limb: LimbBones) -> LimbBones {
            var result = limb
            result.anchor = reflect(limb.anchor)
            result.joint = reflect(limb.joint)
            result.end = reflect(limb.end)
            return result
        }
        pose.torso.root = reflect(source.torso.root)
        pose.torso.spineAngle = .pi - source.torso.spineAngle
        pose.headCenter = reflect(source.headCenter)
        pose.headAngle = -source.headAngle
        pose.pupilOffset.x = -source.pupilOffset.x
        pose.tailSegments = source.tailSegments.map(reflect)
        pose.leftArm = reflect(source.rightArm)
        pose.rightArm = reflect(source.leftArm)
        pose.leftLeg = reflect(source.rightLeg)
        pose.rightLeg = reflect(source.leftLeg)
        swap(&pose.leftEyeOpen, &pose.rightEyeOpen)
        pose.facingRight.toggle()
        return pose
    }

    private func keepInsideScreen(_ source: SkeletonPose) -> SkeletonPose {
        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        func include(_ x: CGFloat) {
            minX = min(minX, x)
            maxX = max(maxX, x)
        }
        if source.drawsHead { include(source.headCenter.x - 16); include(source.headCenter.x + 16) }
        if source.drawsTorso {
            include(source.root.x - 12); include(source.root.x + 12)
            include(source.torso.neck.x - 12); include(source.torso.neck.x + 12)
        }
        if source.drawsArms {
            include(source.leftArm.anchor.x); include(source.leftArm.joint.x); include(source.leftArm.end.x)
            include(source.rightArm.anchor.x); include(source.rightArm.joint.x); include(source.rightArm.end.x)
        }
        if source.drawsLegs {
            include(source.leftLeg.anchor.x); include(source.leftLeg.joint.x); include(source.leftLeg.end.x)
            include(source.rightLeg.anchor.x); include(source.rightLeg.joint.x); include(source.rightLeg.end.x)
        }
        guard minX.isFinite else { return source }
        let shift = minX < 2 ? 2 - minX : (maxX > screenWidth - 2 ? screenWidth - 2 - maxX : 0)
        guard shift != 0 else { return source }
        var pose = source
        func translate(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x + shift, y: point.y) }
        pose.torso.root = translate(pose.root)
        pose.headCenter = translate(pose.headCenter)
        pose.leftArm.anchor = translate(pose.leftArm.anchor); pose.leftArm.joint = translate(pose.leftArm.joint); pose.leftArm.end = translate(pose.leftArm.end)
        pose.rightArm.anchor = translate(pose.rightArm.anchor); pose.rightArm.joint = translate(pose.rightArm.joint); pose.rightArm.end = translate(pose.rightArm.end)
        pose.leftLeg.anchor = translate(pose.leftLeg.anchor); pose.leftLeg.joint = translate(pose.leftLeg.joint); pose.leftLeg.end = translate(pose.leftLeg.end)
        pose.rightLeg.anchor = translate(pose.rightLeg.anchor); pose.rightLeg.joint = translate(pose.rightLeg.joint); pose.rightLeg.end = translate(pose.rightLeg.end)
        pose.tailSegments = pose.tailSegments.map(translate)
        return pose
    }
    
    // MARK: - Continuous Full-Screen Choreography
    private func evaluateContinuousRoute(dt: Double) -> SkeletonPose {
        switch routeStage {
        case .leftWalk:
            if walkDirection > 0 {
                // Walking right from screen left toward the notch
                if hasPhysicalNotch && rootWorldX >= notchLeft - 16.0 {
                    routeStage = .lowerToHang
                    behaviorTime = 0.0
                    hangStartX = currentPose.root.x
                    hangStartY = currentPose.root.y
                    targetHangX = notchLeft + 14.0
                    handLWorldX = notchLeft + 2.0
                    handRWorldX = notchLeft + 26.0
                    rootWorldX = targetHangX
                    return evaluateLowerToHang(dt: dt)
                } else if !hasPhysicalNotch && rootWorldX >= screenWidth - 45.0 {
                    routeStage = .farCornerPeek
                    behaviorTime = 0.0
                    turnStartX = currentPose.root.x
                    turnStartY = currentPose.root.y
                    return evaluateFarCornerTurn(dt: dt)
                }
            } else {
                // Walking left from notch toward screen left edge
                if rootWorldX <= 45.0 {
                    routeStage = .farCornerPeek
                    behaviorTime = 0.0
                    turnStartX = currentPose.root.x
                    turnStartY = currentPose.root.y
                    return evaluateFarCornerTurn(dt: dt)
                }
            }
            return computeWalkPose(dt: dt, walkY: walkLedgeY)
            
        case .rightWalk:
            if walkDirection > 0 {
                // Walking right from notch toward screen right edge
                if rootWorldX >= screenWidth - 45.0 {
                    routeStage = .farCornerPeek
                    behaviorTime = 0.0
                    turnStartX = currentPose.root.x
                    turnStartY = currentPose.root.y
                    return evaluateFarCornerTurn(dt: dt)
                }
            } else {
                // Walking left from screen right toward the notch
                if hasPhysicalNotch && rootWorldX <= notchRight + 16.0 {
                    routeStage = .lowerToHang
                    behaviorTime = 0.0
                    hangStartX = currentPose.root.x
                    hangStartY = currentPose.root.y
                    targetHangX = notchRight - 14.0
                    handLWorldX = notchRight - 26.0
                    handRWorldX = notchRight - 2.0
                    rootWorldX = targetHangX
                    return evaluateLowerToHang(dt: dt)
                } else if !hasPhysicalNotch && rootWorldX <= 45.0 {
                    routeStage = .farCornerPeek
                    behaviorTime = 0.0
                    turnStartX = currentPose.root.x
                    turnStartY = currentPose.root.y
                    return evaluateFarCornerTurn(dt: dt)
                }
            }
            return computeWalkPose(dt: dt, walkY: walkLedgeY)
            
        case .approachNotch, .lowerToHang:
            return evaluateLowerToHang(dt: dt)
            
        case .monkeyBarTraversal:
            if behaviorTime >= 3.6 {
                routeStage = .climbOntoRightLedge
                behaviorTime = 0.0
                climbStartX = currentPose.root.x
                climbStartY = currentPose.root.y
            }
            return evaluateHangingWorkout(dt: dt)
            
        case .climbOntoRightLedge:
            return evaluateClimbOntoLedge(dt: dt)
            
        case .farCornerPeek:
            return evaluateFarCornerTurn(dt: dt)
            
        case .routeComplete:
            var pose = currentPose
            pose.timestamp = behaviorTime
            return pose
        }
    }
    
    // MARK: - Lower Gracefully Into Notch Lip Hang
    private func evaluateLowerToHang(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = (walkDirection > 0)
        let gripY = ledgeY + 3.0
        
        let duration: Double = 1.4
        let halfDuration: Double = 0.7
        let targetY = gripY + 58.0 // 93.0 pt
        
        let rootX: CGFloat
        let rootY: CGFloat
        
        if behaviorTime < halfDuration {
            // Phase 1: Lower down vertically outside notch housing until safely below notch line
            let p = CGFloat(behaviorTime / halfDuration)
            let ease = p * p * (3.0 - 2.0 * p)
            rootX = hangStartX
            rootY = hangStartY + (targetY - hangStartY) * ease
            pose.mouthShape = .openW
        } else {
            // Phase 2: Now safely below notch depth, swing under the notch lip to target grip position
            let p = min(1.0, CGFloat((behaviorTime - halfDuration) / (duration - halfDuration)))
            let ease = p * p * (3.0 - 2.0 * p)
            rootX = hangStartX + (targetHangX - hangStartX) * ease
            rootY = targetY
            pose.mouthShape = .smile
        }
        
        pose.torso.root = CGPoint(x: rootX, y: rootY)
        pose.torso.spineLength = 24.0
        pose.torso.spineAngle = -.pi / 2.0
        pose.headCenter = visibleRouteHead(at: CGPoint(x: rootX, y: max(rootY - 18.0, ledgeY + 16.0)))
        
        pose.leftArm.length1 = 26.0
        pose.leftArm.length2 = 26.0
        pose.rightArm.length1 = 26.0
        pose.rightArm.length2 = 26.0
        
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLWorldX, y: gripY), bendPositive: false)
        pose.leftArm.isPlantedOrGripping = true
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRWorldX, y: gripY), bendPositive: true)
        pose.rightArm.isPlantedOrGripping = true
        
        let kickPhase = behaviorTime * 6.0
        let kickL = CGFloat(sin(kickPhase)) * 4.0
        let kickR = CGFloat(-sin(kickPhase)) * 4.0
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: rootX - 5.0 + kickL, y: rootY + 16.0), bendPositive: false)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rootX + 5.0 + kickR, y: rootY + 16.0), bendPositive: true)
        
        if behaviorTime >= duration {
            routeStage = .monkeyBarTraversal
            behaviorTime = 0.0
        }
        
        return pose
    }
    
    // MARK: - Notch Lip Hang & Athletic Pull-Up Workout
    private func evaluateHangingWorkout(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = (walkDirection > 0)
        let gripY = ledgeY + 3.0
        let midX = (handLWorldX + handRWorldX) / 2.0
        
        pose.leftArm.length1 = 26.0
        pose.leftArm.length2 = 26.0
        pose.rightArm.length1 = 26.0
        pose.rightArm.length2 = 26.0
        
        let hangStartY = gripY + 58.0 // 93.0 pt
        let topPullUpY = gripY + 26.0 // 61.0 pt
        
        let t = behaviorTime
        let curRootY: CGFloat
        let chinRise: CGFloat
        
        if t < 0.8 {
            isPullingUpWorkout = false
            curRootY = hangStartY
            chinRise = 0.0
            pose.mouthShape = .smile
            pose.leftEyeOpen = 1.0
            pose.rightEyeOpen = 1.0
        } else if t < 2.0 {
            // Athletic pull-up lifting chin to notch lip
            isPullingUpWorkout = true
            let p = CGFloat((t - 0.8) / 1.2)
            let ease = p * p * (3.0 - 2.0 * p)
            curRootY = hangStartY - (hangStartY - topPullUpY) * ease
            chinRise = ease
            pose.mouthShape = .smile
            pose.leftEyeOpen = 0.0 // Joyful crescent eyes (^ ‿ ^)
            pose.rightEyeOpen = 0.0
        } else if t < 2.6 {
            // Holding top of pull-up with proud smile
            isPullingUpWorkout = true
            curRootY = topPullUpY
            chinRise = 1.0
            pose.mouthShape = .smile
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
        } else {
            // Sinking back down smoothly with happy sigh
            isPullingUpWorkout = false
            let p = min(1.0, CGFloat((t - 2.6) / 1.0))
            let ease = p * p * (3.0 - 2.0 * p)
            curRootY = topPullUpY + (hangStartY - topPullUpY) * ease
            chinRise = 1.0 - ease
            pose.mouthShape = .sigh
            pose.leftEyeOpen = 1.0
            pose.rightEyeOpen = 1.0
        }
        
        let sway = CGFloat(sin(t * 3.5)) * (isPullingUpWorkout ? 1.0 : 3.0)
        pose.torso.root = CGPoint(x: midX + sway, y: curRootY)
        pose.torso.spineLength = 24.0
        pose.torso.spineAngle = -.pi / 2.0 + Double(sway) * 0.02
        
        let chinTargetY = gripY - 4.0
        let chinY = pose.torso.neck.y - 10.0 + (chinTargetY - (pose.torso.neck.y - 10.0)) * chinRise
        pose.headCenter = visibleRouteHead(at: CGPoint(x: pose.torso.neck.x, y: min(pose.torso.neck.y - 4.0, chinY)), allowPullUp: isPullingUpWorkout)
        
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLWorldX, y: gripY), bendPositive: false)
        pose.leftArm.isPlantedOrGripping = true
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRWorldX, y: gripY), bendPositive: true)
        pose.rightArm.isPlantedOrGripping = true
        
        let kickPhase = t * 7.5
        let kickL = CGFloat(sin(kickPhase)) * (isPullingUpWorkout ? 3.5 : 6.0)
        let kickR = CGFloat(sin(kickPhase + 1.4)) * (isPullingUpWorkout ? 3.5 : 5.0)
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: pose.torso.root.x - 6.0 + kickL, y: curRootY + 16.0), bendPositive: false)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: pose.torso.root.x + 7.0 + kickR, y: curRootY + 18.0), bendPositive: true)
        
        return pose
    }
    
    // MARK: - Traverse Notch & Climb Onto Ledge
    private func evaluateClimbOntoLedge(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = (walkDirection > 0)
        let gripY = ledgeY + 3.0
        
        let targetLedgeX = (walkDirection > 0) ? (notchRight + 24.0) : (notchLeft - 24.0)
        let clearCornerX = (walkDirection > 0) ? (notchRight + 16.0) : (notchLeft - 16.0)
        
        let traverseDuration: Double = 3.6
        let liftDuration: Double = 0.9
        let totalDuration = traverseDuration + liftDuration
        
        let rootX: CGFloat
        let rootY: CGFloat
        
        if behaviorTime < traverseDuration {
            // Phase 1: Graceful swinging traversal under the notch lip from one corner to the other
            let p = CGFloat(behaviorTime / traverseDuration)
            let ease = p * p * (3.0 - 2.0 * p)
            rootX = climbStartX + (clearCornerX - climbStartX) * ease
            rootY = climbStartY // Stay suspended safely below notch lip
            
            // Hands track along the notch lip
            handLWorldX = rootX - 6.0
            handRWorldX = rootX + 6.0
            
            pose.mouthShape = .openW
            
            // Midpoint pull-up moment during traversal!
            let midProgress = sin(p * .pi)
            if midProgress > 0.6 {
                pose.leftEyeOpen = 0.0 // (^ ‿ ^)
                pose.rightEyeOpen = 0.0
                pose.mouthShape = .smile
            }
        } else {
            // Phase 2: Now safely cleared outside notch bezel, lift up onto the menu bar shelf
            let p = min(1.0, CGFloat((behaviorTime - traverseDuration) / liftDuration))
            let ease = p * p * (3.0 - 2.0 * p)
            rootX = clearCornerX + (targetLedgeX - clearCornerX) * ease
            rootY = climbStartY + (walkLedgeY - 11.0 - climbStartY) * ease
            pose.mouthShape = p >= 0.8 ? .sigh : .openW
            
            handLWorldX = rootX - 6.0
            handRWorldX = rootX + 6.0
        }
        
        pose.torso.root = CGPoint(x: rootX, y: rootY)
        pose.torso.spineLength = 24.0
        pose.torso.spineAngle = -.pi / 2.0
        pose.headCenter = visibleRouteHead(at: CGPoint(x: rootX + (walkDirection * 2.0), y: rootY - 18.0))
        
        pose.leftArm.length1 = 26.0
        pose.leftArm.length2 = 26.0
        pose.rightArm.length1 = 26.0
        pose.rightArm.length2 = 26.0
        
        let handTargetY = min(gripY, rootY + 6.0)
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLWorldX, y: handTargetY), bendPositive: false)
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRWorldX, y: handTargetY), bendPositive: true)
        pose.leftArm.isPlantedOrGripping = false
        pose.rightArm.isPlantedOrGripping = false
        
        let kickPhase = behaviorTime * 7.0
        let kickL = CGFloat(sin(kickPhase)) * 4.0
        let kickR = CGFloat(-sin(kickPhase)) * 4.0
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: rootX - 5.0 + kickL, y: rootY + 14.0), bendPositive: false)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rootX + 5.0 + kickR, y: rootY + 14.0), bendPositive: true)
        pose.leftLeg.isPlantedOrGripping = true
        pose.rightLeg.isPlantedOrGripping = true
        
        if behaviorTime >= totalDuration {
            // Stood up cleanly on ledge! Transition to walking across opposite side.
            if walkDirection > 0 {
                routeStage = .rightWalk
            } else {
                routeStage = .leftWalk
            }
            behaviorTime = 0.0
            rootWorldX = targetLedgeX
            isLeftFootPlanted = true
            leftFootWorldX = rootWorldX
            leftFootWorldY = walkLedgeY
            rightFootWorldX = rootWorldX - walkStepLength * walkDirection
            rightFootWorldY = walkLedgeY
            walkStepPhase = 0.5
        }
        
        return pose
    }
    
    // MARK: - Far Corner Turn & Pivot
    private func evaluateFarCornerTurn(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        let targetX = (walkDirection > 0) ? (screenWidth - 30.0) : 30.0
        
        let settle = min(1.0, CGFloat(behaviorTime / 0.25))
        let settleEase = settle * settle * (3.0 - 2.0 * settle)
        let curX = turnStartX + (targetX - turnStartX) * settleEase
        let rootY = turnStartY + (walkLedgeY - 11.0 - turnStartY) * settleEase
        pose.torso.root = CGPoint(x: curX, y: rootY)
        pose.torso.spineAngle = -.pi / 2.0
        pose.headCenter = visibleRouteHead(at: CGPoint(x: curX, y: walkLedgeY - 32.0))
        
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: curX - 5.0, y: walkLedgeY), bendPositive: false)
        pose.leftLeg.isPlantedOrGripping = true
        let pivotProgress = CGFloat(min(1.0, max(0.0, (behaviorTime - 0.8) / 0.8)))
        let pivotEase = pivotProgress * pivotProgress * (3.0 - 2.0 * pivotProgress)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: curX + 5.0 - 10.0 * pivotEase, y: walkLedgeY), bendPositive: true)
        pose.rightLeg.isPlantedOrGripping = behaviorTime < 0.8
        
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: curX - 8.0, y: walkLedgeY - 6.0), bendPositive: false)
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: curX + 8.0, y: walkLedgeY - 6.0), bendPositive: true)
        
        if behaviorTime < 0.8 {
            // Peek over screen edge
            pose.headAngle = 18.0 * (walkDirection > 0 ? 1.0 : -1.0)
            pose.pupilOffset = CGPoint(x: (walkDirection > 0 ? 0.7 : -0.7), y: 0.5)
            pose.facingRight = (walkDirection > 0)
        } else if behaviorTime < 1.6 {
            // Pivot feet
            pose.headAngle = -10.0 * (walkDirection > 0 ? 1.0 : -1.0)
            pose.facingRight = !(walkDirection > 0)
        } else {
            // End at the far corner; the coordinator retreats to the den.
            routeStage = .routeComplete
            behaviorTime = 0.0
            completedRouteCount += 1
            pose.drawsTorso = false
            pose.drawsHead = false
            pose.drawsArms = false
            pose.drawsLegs = false
        }
        
        return pose
    }
    
    // MARK: - General Walking Gait Computation (Zero Foot Slip Guarantee & Chubby Waddle)
    private func computeWalkPose(dt: Double, walkY: CGFloat) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = (walkDirection > 0)
        pose.leftLeg.length1 = 11.0
        pose.leftLeg.length2 = 11.0
        pose.rightLeg.length1 = 11.0
        pose.rightLeg.length2 = 11.0
        
        walkStepPhase += dt / walkStepDuration
        if walkStepPhase >= 1.0 {
            walkStepPhase = 0.0
            isLeftFootPlanted.toggle()
            if isLeftFootPlanted {
                leftFootWorldX = rootWorldX + (walkStepLength / 2.0) * walkDirection
                leftFootWorldY = walkY
            } else {
                rightFootWorldX = rootWorldX + (walkStepLength / 2.0) * walkDirection
                rightFootWorldY = walkY
            }
        }
        
        let u = CGFloat(walkStepPhase)
        let plantedFootX = isLeftFootPlanted ? leftFootWorldX : rightFootWorldX
        rootWorldX = plantedFootX + (u - 0.5) * walkStepLength * walkDirection
        
        // Subtle body roll (rotational sway ±3.5° linked to step phase)
        let swayDirection: Double = isLeftFootPlanted ? 1.0 : -1.0
        let swayAmplitudeRad: Double = 3.5 * .pi / 180.0
        let bodyRoll = sin(Double.pi * Double(u)) * swayAmplitudeRad * swayDirection * Double(walkDirection)
        
        // Gentle vertical root bob with step rhythm
        let rootBob = -1.6 * CGFloat(sin(Double.pi * Double(u)))
        let rootY = walkY - 11.0 + rootBob
        
        pose.torso.root = visibleBodyRoot(at: CGPoint(x: rootWorldX, y: rootY))
        pose.torso.spineAngle = -.pi / 2.0 + Double(walkDirection) * 0.04 + bodyRoll
        
        // Head bobs gently with step rhythm and counter-tilts with waddle
        let headBobY = -1.2 * sin(Double.pi * Double(u))
        let headCounterTilt = -bodyRoll * (180.0 / .pi) * 0.5
        let headNod = sin(Double.pi * Double(u)) * 2.0
        pose.headCenter = visibleRouteHead(at: CGPoint(x: pose.torso.neck.x + walkDirection * 1.5, y: pose.torso.neck.y - 7.5 + headBobY))
        pose.headAngle = headCounterTilt + headNod
        
        // Solve Planted & Swing Legs with soft foot lift (~2.8pt)
        let swingLift = -2.8 * 4.0 * u * (1.0 - u)
        
        if isLeftFootPlanted {
            pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: leftFootWorldX, y: leftFootWorldY), bendPositive: false)
            pose.leftLeg.isPlantedOrGripping = true
            
            let swingStart = leftFootWorldX - walkStepLength * walkDirection
            let swingEnd = leftFootWorldX + walkStepLength * walkDirection
            let smoothU = u * u * (3.0 - 2.0 * u)
            let swingX = swingStart + (swingEnd - swingStart) * smoothU
            pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: swingX, y: walkY + swingLift), bendPositive: true)
            pose.rightLeg.isPlantedOrGripping = false
            rightFootWorldX = swingX
            rightFootWorldY = walkY
            
        } else {
            pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rightFootWorldX, y: rightFootWorldY), bendPositive: true)
            pose.rightLeg.isPlantedOrGripping = true
            
            let swingStart = rightFootWorldX - walkStepLength * walkDirection
            let swingEnd = rightFootWorldX + walkStepLength * walkDirection
            let smoothU = u * u * (3.0 - 2.0 * u)
            let swingX = swingStart + (swingEnd - swingStart) * smoothU
            pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: swingX, y: walkY + swingLift), bendPositive: false)
            pose.leftLeg.isPlantedOrGripping = false
            leftFootWorldX = swingX
            leftFootWorldY = walkY
        }
        
        // Paws stay close to the chubby body (gentle paddle waddle rather than wild flailing)
        let pawSwingX = CGFloat(sin(Double.pi * Double(u))) * 2.0 * CGFloat(swayDirection) * walkDirection
        let pawBobY = CGFloat(cos(Double.pi * Double(u))) * 0.8
        let handLY = pose.torso.leftShoulderAnchor.y + 7.5 + pawBobY
        let handRY = pose.torso.rightShoulderAnchor.y + 7.5 - pawBobY
        let handLX = pose.torso.leftShoulderAnchor.x + pawSwingX + walkDirection * 1.0
        let handRX = pose.torso.rightShoulderAnchor.x - pawSwingX + walkDirection * 1.0
        
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLX, y: handLY), bendPositive: false)
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRX, y: handRY), bendPositive: true)
        
        pose.leftEyeOpen = 1.0
        pose.rightEyeOpen = 1.0
        pose.pupilOffset = CGPoint(x: walkDirection * 0.35, y: 0.0)
        pose.mouthShape = .openW
        
        return pose
    }
    
    // MARK: - Hanging Under Notch
    private func evaluateHangingUnderNotch(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = true
        let gripY = ledgeY + 3.0
        let midX = (handLWorldX + handRWorldX) / 2.0
        
        let gravity = 18.0
        let armLength: Double = 60.0
        let dampingFactor = 0.85
        let angularAccel = -(gravity / armLength) * sin(pendulumAngle) - (dampingFactor * pendulumVelocity)
        pendulumVelocity += angularAccel * dt
        pendulumAngle += pendulumVelocity * dt
        if abs(pendulumAngle) > 0.32 {
            pendulumAngle = max(-0.32, min(0.32, pendulumAngle))
            pendulumVelocity *= -0.45
        }
        
        let swayX = CGFloat(armLength * sin(pendulumAngle))
        let swayY = CGFloat(armLength * cos(pendulumAngle))
        let rootY = gripY + swayY
        
        pose.torso.root = CGPoint(x: midX + swayX, y: rootY)
        pose.torso.spineLength = 24.0
        pose.torso.spineAngle = -.pi / 2.0 + pendulumAngle * 0.6
        pose.headCenter = visibleRouteHead(at: CGPoint(x: pose.torso.neck.x + swayX * 0.2, y: pose.torso.neck.y - 10.0))
        pose.leftArm.length1 = 26.0
        pose.leftArm.length2 = 26.0
        pose.rightArm.length1 = 26.0
        pose.rightArm.length2 = 26.0
        
        // Pinned hands to bottom edge of notch (ledgeY + 3.0)
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLWorldX, y: gripY), bendPositive: false)
        pose.leftArm.isPlantedOrGripping = true
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRWorldX, y: gripY), bendPositive: true)
        pose.rightArm.isPlantedOrGripping = true
        
        // Stubby legs kick cutely (small playful kicks, not extreme flailing)
        let kickPhase = behaviorTime * 6.0
        let leftKick = CGFloat(sin(kickPhase)) * 6.5
        let rightKick = CGFloat(sin(kickPhase + .pi * 0.7)) * 5.0
        let leftLift = CGFloat(max(0.0, sin(kickPhase))) * 3.5
        let rightLift = CGFloat(max(0.0, sin(kickPhase + .pi * 0.7))) * 3.0
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: pose.torso.root.x - 6.0 + leftKick, y: rootY + 18.0 + leftLift), bendPositive: false)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: pose.torso.root.x + 7.0 + rightKick, y: rootY + 20.0 + rightLift), bendPositive: true)
        
        let startled = currentBehavior == .slipping
        pose.leftEyeOpen = startled ? 1.2 : 1.0
        pose.rightEyeOpen = startled ? 1.2 : 1.0
        pose.mouthShape = startled ? .gasp : .smile
        return pose
    }

    private func evaluatePullingUp() -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = true

        let gripY = ledgeY + 3.0
        let rootX = (handLWorldX + handRWorldX) / 2.0

        if behaviorTime > 2.5 {
            // Leap / vault up into the notch den rather than vanishing mid-air
            let vaultProgress = min(1.0, CGFloat((behaviorTime - 2.5) / 0.65))
            let vaultEase = vaultProgress * vaultProgress * (3.0 - 2.0 * vaultProgress)
            let topY = ledgeY + 28.0
            let denY: CGFloat = -45.0
            let vaultedRootY = topY + (denY - topY) * vaultEase
            pose.torso.root = CGPoint(x: rootX, y: vaultedRootY)
            pose.torso.spineAngle = -.pi / 2.0
            pose.headCenter = CGPoint(x: pose.torso.neck.x, y: pose.torso.neck.y - 8.0)
            
            pose.leftArm.length1 = 14.0
            pose.leftArm.length2 = 14.0
            pose.rightArm.length1 = 14.0
            pose.rightArm.length2 = 14.0
            let armPushY = min(gripY + 8.0, vaultedRootY + 6.0)
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLWorldX + 6.0 * vaultEase, y: armPushY), bendPositive: false)
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRWorldX - 6.0 * vaultEase, y: armPushY), bendPositive: true)
            pose.leftArm.isPlantedOrGripping = vaultProgress < 0.2
            pose.rightArm.isPlantedOrGripping = vaultProgress < 0.2
            
            pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: rootX - 5.0, y: vaultedRootY + 12.0), bendPositive: false)
            pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rootX + 5.0, y: vaultedRootY + 12.0), bendPositive: true)
            
            pose.mouthShape = .openW
            pose.leftEyeOpen = 1.0
            pose.rightEyeOpen = 1.0
            
            if vaultProgress >= 0.95 {
                pose.drawsTorso = false
                pose.drawsHead = false
                pose.drawsArms = false
                pose.drawsLegs = false
            }
            return pose
        }

        let liftProgress = min(1.0, CGFloat(behaviorTime / 1.6))
        let easedLift = liftProgress * liftProgress * (3.0 - 2.0 * liftProgress)
        let rootY = pullUpStartY + (ledgeY + 28.0 - pullUpStartY) * easedLift

        pose.torso.root = CGPoint(x: rootX, y: rootY)
        pose.torso.spineAngle = -.pi / 2.0 + sin(Double(liftProgress) * .pi) * 0.12
        
        // Chin lifts smoothly up toward notch edge level (gripY - 4.0), clearing the ledge
        let chinTargetY = gripY - 4.0
        let chinRiseY = pose.torso.neck.y - 10.0 + (chinTargetY - (pose.torso.neck.y - 10.0)) * easedLift
        pose.headCenter = visibleRouteHead(at: CGPoint(x: pose.torso.neck.x, y: min(pose.torso.neck.y - 4.0, chinRiseY)), allowPullUp: true)
        
        // Arms flare naturally out (bendPositive: false on left arm, true on right arm)
        pose.leftArm.length1 = 26.0
        pose.leftArm.length2 = 26.0
        pose.rightArm.length1 = 26.0
        pose.rightArm.length2 = 26.0
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLWorldX, y: gripY), bendPositive: false)
        pose.leftArm.isPlantedOrGripping = true
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRWorldX, y: gripY), bendPositive: true)
        pose.rightArm.isPlantedOrGripping = true

        // Stubby legs tuck up with cute effort
        let tuck = 13.0 * liftProgress
        let effortWiggle = CGFloat(sin(behaviorTime * 8.0)) * (1.0 - liftProgress) * 3.0
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: rootX - 6.5 + effortWiggle, y: rootY + 18.0 - tuck), bendPositive: false)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rootX + 6.5 - effortWiggle, y: rootY + 18.0 - tuck * 0.65), bendPositive: true)
        pose.mouthShape = liftProgress >= 0.9 ? .sigh : .smile
        return pose
    }
    
    // MARK: - Peeking
    private func evaluatePeek(side: CGFloat, dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = (side < 0)
        let cornerX = (side < 0) ? (notchLeft - 16.0) : (notchRight + 16.0)
        let gripY = ledgeY + 3.0
        
        if behaviorTime < 0.6 {
            pose.torso.root = CGPoint(x: cornerX, y: -45)
            pose.drawsTorso = false
            pose.drawsHead = false
            pose.drawsArms = false
            pose.drawsLegs = false
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
            return pose
        } else if behaviorTime < 1.6 {
            // Paws pop up first and curl over the notch edge (ledgeY)
            let p = CGFloat((behaviorTime - 0.6) / 1.0)
            let ease = p * p * (3.0 - 2.0 * p)
            pose.torso.root = CGPoint(x: cornerX, y: gripY + 24.0)
            pose.torso.spineAngle = -.pi / 2.0
            pose.drawsTorso = false
            pose.drawsHead = false
            pose.drawsArms = true
            pose.drawsLegs = false
            let handY = (gripY + 8.0) - 8.0 * ease
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 6.0, y: handY), bendPositive: false)
            pose.leftArm.isPlantedOrGripping = handY <= gripY + 0.5
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 6.0, y: handY), bendPositive: true)
            pose.rightArm.isPlantedOrGripping = handY <= gripY + 0.5
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
            return pose
        } else if behaviorTime < 3.4 {
            // Chubby head smoothly slides up from behind the notch with ease-in-out curve
            let pRise = min(1.0, CGFloat((behaviorTime - 1.6) / 0.6))
            let riseEase = pRise * pRise * (3.0 - 2.0 * pRise)
            let rootY = (gripY + 36.0) - 10.0 * riseEase
            pose.torso.root = CGPoint(x: cornerX, y: rootY)
            pose.torso.spineAngle = -.pi / 2.0 + Double(-side) * 0.06 * Double(1.0 - riseEase)
            pose.headCenter = visibleRouteHead(at: CGPoint(x: pose.torso.neck.x, y: pose.torso.neck.y - 6.0))
            pose.drawsTorso = true
            pose.drawsHead = true
            pose.drawsArms = true
            pose.drawsLegs = false
            pose.leftArm.length1 = 11.0; pose.leftArm.length2 = 11.0
            pose.rightArm.length1 = 11.0; pose.rightArm.length2 = 11.0
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 6.0, y: gripY), bendPositive: false)
            pose.leftArm.isPlantedOrGripping = true
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 6.0, y: gripY), bendPositive: true)
            pose.rightArm.isPlantedOrGripping = true
            
            // Single-eye curious peek looking around
            if side < 0 {
                pose.rightEyeOpen = 1.0
                pose.leftEyeOpen = 0.0
            } else {
                pose.leftEyeOpen = 1.0
                pose.rightEyeOpen = 0.0
            }
            let lookPhase = (behaviorTime - 1.6) * 2.8
            pose.pupilOffset = CGPoint(x: CGFloat(sin(lookPhase)) * 0.65, y: CGFloat(cos(lookPhase * 0.5)) * 0.2)
            pose.headAngle = Double(sin(lookPhase)) * 4.0
            pose.mouthShape = .openW
            return pose
        } else if behaviorTime < 4.2 {
            // Cute transition dip and blink before full reveal
            let pMid = CGFloat((behaviorTime - 3.4) / 0.8)
            let midEase = pMid * pMid * (3.0 - 2.0 * pMid)
            let rootY = (gripY + 26.0) + 3.0 * sin(midEase * .pi)
            pose.torso.root = CGPoint(x: cornerX, y: rootY)
            pose.torso.spineAngle = -.pi / 2.0
            pose.headCenter = visibleRouteHead(at: CGPoint(x: pose.torso.neck.x, y: pose.torso.neck.y - 6.0))
            pose.drawsTorso = true
            pose.drawsHead = true
            pose.drawsArms = true
            pose.drawsLegs = false
            pose.leftArm.length1 = 11.0; pose.leftArm.length2 = 11.0
            pose.rightArm.length1 = 11.0; pose.rightArm.length2 = 11.0
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 6.0, y: gripY), bendPositive: false)
            pose.leftArm.isPlantedOrGripping = true
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 6.0, y: gripY), bendPositive: true)
            pose.rightArm.isPlantedOrGripping = true
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
            pose.mouthShape = .smile
            return pose
        } else if behaviorTime < 5.8 {
            // Full face peek: both eyes wide open, smiling, looking left & right
            let pFull = min(1.0, CGFloat((behaviorTime - 4.2) / 0.6))
            let fullEase = pFull * pFull * (3.0 - 2.0 * pFull)
            let rootY = (gripY + 26.0) - 8.0 * fullEase
            pose.torso.root = CGPoint(x: cornerX, y: rootY)
            pose.torso.spineAngle = -.pi / 2.0 + Double(-side) * 0.08 * Double(1.0 - fullEase)
            pose.headCenter = visibleRouteHead(at: CGPoint(x: pose.torso.neck.x, y: pose.torso.neck.y - 6.0))
            pose.drawsTorso = true
            pose.drawsHead = true
            pose.drawsArms = true
            pose.drawsLegs = false
            pose.leftArm.length1 = 14.0; pose.leftArm.length2 = 14.0
            pose.rightArm.length1 = 14.0; pose.rightArm.length2 = 14.0
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 6.0, y: gripY), bendPositive: false)
            pose.leftArm.isPlantedOrGripping = true
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 6.0, y: gripY), bendPositive: true)
            pose.rightArm.isPlantedOrGripping = true
            pose.leftEyeOpen = 1.15
            pose.rightEyeOpen = 1.15
            pose.mouthShape = .smile
            let lookCycle = (behaviorTime - 4.2) * 2.5
            pose.pupilOffset = CGPoint(x: CGFloat(sin(lookCycle)) * 0.6, y: 0.1)
            pose.headAngle = Double(sin(lookCycle)) * 3.5
            return pose
        } else {
            // Ducking smoothly back down into den without jumps
            let pDuck = min(1.0, CGFloat((behaviorTime - 5.8) / 0.8))
            let duckEase = pDuck * pDuck * (3.0 - 2.0 * pDuck)
            let rootY = (gripY + 18.0) + 40.0 * duckEase
            pose.torso.root = CGPoint(x: cornerX, y: rootY)
            pose.torso.spineAngle = -.pi / 2.0
            pose.headCenter = visibleRouteHead(at: CGPoint(x: pose.torso.neck.x, y: pose.torso.neck.y - 6.0))
            pose.drawsTorso = pDuck < 0.6
            pose.drawsHead = pDuck < 0.8
            pose.drawsArms = pDuck < 1.0
            pose.drawsLegs = false
            let handY = gripY + 12.0 * duckEase
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 6.0, y: handY), bendPositive: false)
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 6.0, y: handY), bendPositive: true)
            pose.mouthShape = .openW
            pose.leftEyeOpen = max(0.0, 1.0 - pDuck * 2.0)
            pose.rightEyeOpen = max(0.0, 1.0 - pDuck * 2.0)
            return pose
        }
    }
    
    // MARK: - Cursor Watching & Thinking
    private func evaluateThinking(dt: Double, cursorScreenPos: CGPoint) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        let walkY = walkLedgeY

        pose.torso.root = visibleBodyRoot(at: CGPoint(x: rootWorldX, y: walkY - 14.0))
        pose.torso.spineAngle = -.pi / 2.0
        pose.headCenter = visibleRouteHead(at: CGPoint(x: rootWorldX, y: max(pose.torso.neck.y - 8.0, ledgeY + 17.0)))
        
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: rootWorldX - 6.0, y: walkY), bendPositive: false)
        pose.leftLeg.isPlantedOrGripping = true
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rootWorldX + 6.0, y: walkY), bendPositive: true)
        pose.rightLeg.isPlantedOrGripping = true
        
        // Hand to chin
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: pose.headCenter.x + 3.0, y: pose.headCenter.y + 6.0), bendPositive: true)
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: pose.torso.root.x - 7.0, y: pose.torso.root.y - 2.0), bendPositive: false)
        
        // Tracking spring
        let targetAngle = atan2(cursorScreenPos.y - pose.headCenter.y, cursorScreenPos.x - pose.headCenter.x)
        headAngleSpring.target = min(0.6, max(-0.6, Double(targetAngle) * 0.4))
        headAngleSpring.update(dt: dt)
        pose.headAngle = headAngleSpring.position * 180.0 / .pi
        
        let px = min(0.85, max(-0.85, (cursorScreenPos.x - pose.headCenter.x) / 120.0))
        let py = min(0.85, max(-0.85, (cursorScreenPos.y - pose.headCenter.y) / 120.0))
        pose.pupilOffset = CGPoint(x: px, y: py)
        
        return pose
    }
    
    private func evaluateSleeping(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = true
        
        // Gentle breathing: subtle vertical scale/offset oscillation sin(breathingCycle) * 0.8
        let breathing = CGFloat(sin(breathingCycle) * 0.8)
        let rootY = walkLedgeY - 6.0 + breathing
        let headY = walkLedgeY - 4.0 + breathing * 0.4
        
        // Torso is horizontal (spineAngle = 0), root at (rootWorldX, walkLedgeY - 6.0)
        pose.torso.root = CGPoint(x: rootWorldX, y: rootY)
        pose.torso.spineAngle = 0.0
        pose.torso.spineLength = 14.0
        
        // Head resting directly on the ledge (walkLedgeY - 4.0) with peaceful tilt
        let headX = pose.torso.neck.x + 3.0
        pose.headCenter = CGPoint(x: headX, y: headY)
        pose.headAngle = sin(breathingCycle * 0.6) * 2.0
        
        let floorY = walkLedgeY
        
        // Front paws rest gently forward beside chin
        pose.leftArm.length1 = 7.0
        pose.leftArm.length2 = 7.0
        pose.rightArm.length1 = 7.0
        pose.rightArm.length2 = 7.0
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: headX - 1.0, y: floorY - 1.0), bendPositive: false)
        pose.leftArm.isPlantedOrGripping = true
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: headX + 4.5, y: floorY - 1.0), bendPositive: true)
        pose.rightArm.isPlantedOrGripping = true
        
        // Stubby back legs resting comfortably behind tummy
        pose.leftLeg.length1 = 7.0
        pose.leftLeg.length2 = 7.0
        pose.rightLeg.length1 = 7.0
        pose.rightLeg.length2 = 7.0
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: rootWorldX - 8.0, y: floorY - 1.0), bendPositive: false)
        pose.leftLeg.isPlantedOrGripping = true
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rootWorldX - 4.0, y: floorY - 1.0), bendPositive: true)
        pose.rightLeg.isPlantedOrGripping = true
        
        // Closed relaxed eyes & cute relaxed cat mouth
        pose.leftEyeOpen = 0.0
        pose.rightEyeOpen = 0.0
        pose.mouthShape = .openW
        
        // Gentle tail twitch/wag
        let tailTwitch = CGFloat(sin(breathingCycle * 1.2)) * 1.5
        pose.tailSegments = [
            CGPoint(x: -8, y: 1 + tailTwitch * 0.2),
            CGPoint(x: -14, y: 1 + tailTwitch * 0.5),
            CGPoint(x: -18, y: 0 + tailTwitch),
            CGPoint(x: -21, y: -2 + tailTwitch * 1.4)
        ]
        
        return pose
    }
    
    private func evaluateTyping(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        let walkY = walkLedgeY
        pose.torso.root = visibleBodyRoot(at: CGPoint(x: rootWorldX, y: walkY - 14.0))
        pose.headCenter = visibleRouteHead(at: CGPoint(x: rootWorldX, y: max(pose.torso.neck.y - 8.0, ledgeY + 17.0)))
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: rootWorldX - 6.0, y: walkY), bendPositive: false)
        pose.leftLeg.isPlantedOrGripping = true
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rootWorldX + 6.0, y: walkY), bendPositive: true)
        pose.rightLeg.isPlantedOrGripping = true
        
        let pawAlt = sin(behaviorTime * 18.0) > 0
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: rootWorldX - 4.0, y: walkY - 7.0 + (pawAlt ? -3.0 : 0.0)), bendPositive: false)
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: rootWorldX + 4.0, y: walkY - 7.0 + (pawAlt ? 0.0 : -3.0)), bendPositive: true)
        pose.mouthShape = .openW
        return pose
    }
    
    private func evaluateMusicGroove(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        let walkY = walkLedgeY
        let beat = sin(behaviorTime * 9.0)
        let bobY = CGFloat(beat) * 2.5
        pose.torso.root = visibleBodyRoot(at: CGPoint(x: rootWorldX, y: walkY - 14.0 + bobY))
        pose.headCenter = visibleRouteHead(at: CGPoint(x: rootWorldX, y: max(pose.torso.neck.y - 8.0 + bobY * 0.5, ledgeY + 17.0)))
        pose.headAngle = beat * 8.0
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: rootWorldX - 6.0, y: walkY), bendPositive: false)
        pose.leftLeg.isPlantedOrGripping = true
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rootWorldX + 6.0, y: walkY), bendPositive: true)
        pose.rightLeg.isPlantedOrGripping = true
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: pose.headCenter.x - 11.0, y: pose.headCenter.y + 4.0), bendPositive: false)
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: pose.headCenter.x + 11.0, y: pose.headCenter.y + 4.0), bendPositive: true)
        pose.mouthShape = .smile
        return pose
    }
    
    private func evaluateCelebrating(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        let walkY = walkLedgeY
        let duration: Double = 0.85
        let p = min(1.0, behaviorTime / duration)
        let jumpY = CGFloat(sin(p * .pi)) * 22.0
        pose.torso.root = visibleBodyRoot(at: CGPoint(x: rootWorldX, y: walkY - 14.0 - jumpY))
        
        // Full 360-degree acrobatic backflip rotation
        let flipAngle = Double(p) * 2.0 * .pi
        pose.torso.spineAngle = -.pi / 2.0 - flipAngle
        
        let neckPoint = pose.torso.neck
        pose.headCenter = visibleRouteHead(at: CGPoint(x: neckPoint.x, y: neckPoint.y - 6.0 * cos(flipAngle)))
        pose.headAngle = -sin(Double(p) * .pi) * 15.0
        
        // Tucked limbs during flip rotation, extending gracefully on landing
        let tuck: CGFloat = CGFloat(sin(p * .pi)) * 4.0
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: pose.torso.root.x - 4.0, y: pose.torso.root.y + 4.0 - tuck), bendPositive: false)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: pose.torso.root.x + 4.0, y: pose.torso.root.y + 4.0 - tuck), bendPositive: true)
        
        let armFlare: CGFloat = (1.0 - CGFloat(sin(p * .pi))) * 5.0
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: pose.torso.neck.x - 7.0 - armFlare, y: pose.torso.neck.y - tuck), bendPositive: false)
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: pose.torso.neck.x + 7.0 + armFlare, y: pose.torso.neck.y - tuck), bendPositive: true)
        
        pose.mouthShape = p < 0.75 ? .openW : .smile
        pose.leftEyeOpen = 1.1
        pose.rightEyeOpen = 1.1
        return pose
    }
    
    private func nextCrawlStride() -> CGFloat {
        min(14.0, max(0.0, (crawlBoundary - crawlRootStartX) * crawlDirection))
    }

    private func evaluateCrawling(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = crawlDirection > 0
        let stepDuration = 0.52
        crawlStepPhase += dt / stepDuration
        if crawlStepPhase >= 1.0 {
            crawlStepPhase -= 1.0
            crawlSupportPhase.toggle()
            crawlRootStartX += crawlStride * crawlDirection
            if abs(crawlRootStartX - crawlBoundary) < 0.1 {
                if hasPhysicalNotch && crawlWingIsLeft {
                    crawlDirection = -crawlDirection
                    crawlBoundary = crawlDirection < 0 ? 44.0 : notchLeft - 42.0
                } else if hasPhysicalNotch {
                    crawlDirection = -crawlDirection
                    crawlBoundary = crawlDirection > 0 ? screenWidth - 44.0 : notchRight + 42.0
                } else {
                    crawlDirection = -crawlDirection
                    crawlBoundary = crawlDirection > 0 ? screenWidth - 44.0 : 44.0
                }
            }
            crawlStride = nextCrawlStride()
        }

        let u = CGFloat(crawlStepPhase)
        let reach = u * u * (3.0 - 2.0 * u)
        let crawlY = walkLedgeY
        rootWorldX = crawlRootStartX + crawlStride * reach * crawlDirection
        pose.torso.root = CGPoint(x: rootWorldX, y: crawlY - 8.0 + sin(Double(u) * .pi * 2.0) * 0.8)
        pose.torso.spineAngle = crawlDirection > 0 ? 0.04 : .pi - 0.04
        pose.headCenter = CGPoint(x: pose.torso.neck.x + crawlDirection * 8.0, y: pose.torso.neck.y - 8.0)
        pose.leftArm.length1 = 11.0
        pose.leftArm.length2 = 11.0
        pose.rightArm.length1 = 11.0
        pose.rightArm.length2 = 11.0
        pose.leftLeg.length1 = 15.0
        pose.leftLeg.length2 = 15.0
        pose.rightLeg.length1 = 15.0
        pose.rightLeg.length2 = 15.0

        let handY = crawlY - 3.0
        let handLift = 6.0 * sin(Double.pi * Double(u))
        let footLift = 7.0 * sin(Double.pi * Double(u))
        let swingHandX = crawlRootStartX + 16.0 * crawlDirection + crawlStride * reach * crawlDirection
        let supportHandX = crawlRootStartX + 16.0 * crawlDirection
        let supportFootX = crawlRootStartX - 10.0 * crawlDirection
        let swingFootX = crawlRootStartX - 10.0 * crawlDirection + crawlStride * reach * crawlDirection

        if crawlSupportPhase {
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: supportHandX, y: handY), bendPositive: true)
            pose.rightArm.isPlantedOrGripping = true
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: swingHandX, y: handY - handLift), bendPositive: false)
            pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: supportFootX, y: crawlY), bendPositive: true)
            pose.leftLeg.isPlantedOrGripping = true
            pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: swingFootX, y: crawlY - footLift), bendPositive: false)
        } else {
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: supportHandX, y: handY), bendPositive: false)
            pose.leftArm.isPlantedOrGripping = true
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: swingHandX, y: handY - handLift), bendPositive: true)
            pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: supportFootX, y: crawlY), bendPositive: false)
            pose.rightLeg.isPlantedOrGripping = true
            pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: swingFootX, y: crawlY - footLift), bendPositive: true)
        }
        return pose
    }
}
