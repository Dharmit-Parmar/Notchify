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
    case reverseWalk            // Walking back to left side
}

// MARK: - Kinematic Character Animation Engine
@MainActor
public final class KinematicEngine: ObservableObject {
    public static let shared = KinematicEngine()
    
    // Output Current Pose (Single clock, single pose)
    @Published public var currentPose: SkeletonPose = SkeletonPose()
    
    // Route & Behavior State
    public private(set) var currentBehavior: CompanionBehaviorState = .inDen
    public private(set) var routeStage: ScreenRouteStage = .leftWalk
    public private(set) var behaviorTime: Double = 0.0
    
    // Screen & Notch Geometry Cache
    public var screenWidth: CGFloat = 1470.0
    public var screenHeight: CGFloat = 956.0
    public var notchLeft: CGFloat = 645.5
    public var notchRight: CGFloat = 824.5
    public var notchHeight: CGFloat = 32.0
    public var hasPhysicalNotch: Bool = true
    public var ledgeY: CGFloat { notchHeight }
    
    // Gait Variables (Strict Inverted Pendulum)
    public private(set) var walkStepPhase: Double = 0.0
    public private(set) var isLeftFootPlanted: Bool = true
    public private(set) var leftFootWorldX: CGFloat = 40.0
    public private(set) var rightFootWorldX: CGFloat = 52.0
    public private(set) var rootWorldX: CGFloat = 46.0
    public private(set) var walkStepLength: CGFloat = 12.0
    public private(set) var walkStepDuration: Double = 0.36
    public private(set) var walkDirection: CGFloat = 1.0 // +1 = right, -1 = left
    
    // Monkey-Bar Traversal Variables (Strict Hand-over-Hand Pinning)
    public private(set) var monkeyBarProgress: CGFloat = 0.0
    public private(set) var activeGrippingHand: Int = 0 // 0 = Left gripping, 1 = Right gripping
    public private(set) var handLWorldX: CGFloat = 650.0
    public private(set) var handRWorldX: CGFloat = 664.0
    public private(set) var monkeyBarReach: CGFloat = 14.0
    public private(set) var monkeyBarStepPhase: Double = 0.0
    public private(set) var pendulumAngle: Double = 0.0
    public private(set) var pendulumVelocity: Double = 0.0
    
    // Spring Physics
    private var headAngleSpring = SpringDamper(stiffness: 140.0, damping: 16.0)
    private var eyeTrackXSpring = SpringDamper(stiffness: 180.0, damping: 18.0)
    private var eyeTrackYSpring = SpringDamper(stiffness: 180.0, damping: 18.0)
    
    // Eye Blinking & Breathing
    private var blinkTimer: Double = 3.2
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
            notchLeft = tl.origin.x + tl.width
            notchRight = tr.origin.x
        } else {
            let notchW: CGFloat = hasPhysicalNotch ? 179.0 : 0.0
            notchLeft = (screenWidth - notchW) / 2.0
            notchRight = (screenWidth + notchW) / 2.0
        }
    }
    
    // MARK: - State Setting
    public func setBehavior(_ behavior: CompanionBehaviorState) {
        currentBehavior = behavior
        behaviorTime = 0.0
        
        switch behavior {
        case .inDen:
            resetToDen()
        case .walking:
            setupFullRouteWalk()
        case .dangling, .slipping:
            setupHanging()
        case .peekingLeft:
            setupPeek(side: -1.0)
        case .peekingRight:
            setupPeek(side: 1.0)
        case .thinking, .curious:
            setupThinking()
        case .sleeping:
            setupSleeping()
        case .typingMimic:
            setupTyping()
        case .musicGroove:
            setupMusicGroove()
        case .celebrating:
            setupCelebrating()
        case .crawling, .pullingUp:
            break
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
    
    private func setupFullRouteWalk() {
        routeStage = .leftWalk
        walkDirection = 1.0
        rootWorldX = 35.0
        isLeftFootPlanted = true
        leftFootWorldX = rootWorldX
        rightFootWorldX = rootWorldX - walkStepLength
        walkStepPhase = 0.0
    }
    
    private func setupHanging() {
        routeStage = .lowerToHang
        let midX = (notchLeft + notchRight) / 2.0
        rootWorldX = midX
        handLWorldX = midX - 8.0
        handRWorldX = midX + 8.0
        pendulumAngle = 0.40
        pendulumVelocity = 0.0
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
        pose.root = CGPoint(x: rootWorldX, y: ledgeY - 6.0)
        pose.headCenter = CGPoint(x: rootWorldX, y: ledgeY - 14.0)
        pose.leftEyeOpen = 0.0
        pose.rightEyeOpen = 0.0
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
        blinkTimer -= dt
        if blinkTimer <= 0 {
            isBlinking = true
            blinkTimer = Double.random(in: 2.8...5.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.isBlinking = false
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
            
        case .dangling, .slipping, .pullingUp:
            pose = evaluateHangingUnderNotch(dt: dt)
            
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
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
        }
        
        currentPose = pose
    }
    
    // MARK: - Continuous Full-Screen Choreography
    private func evaluateContinuousRoute(dt: Double) -> SkeletonPose {
        switch routeStage {
        case .leftWalk:
            // Walk from left toward notch
            walkDirection = 1.0
            let targetStop = notchLeft - 18.0
            if rootWorldX >= targetStop {
                if hasPhysicalNotch {
                    routeStage = .approachNotch
                    behaviorTime = 0.0
                } else {
                    // No notch mac: continue walking across!
                    routeStage = .rightWalk
                }
            }
            return computeWalkPose(dt: dt, walkY: ledgeY)
            
        case .approachNotch:
            // Stop at left edge, reach hands over to notch lip
            var pose = SkeletonPose()
            pose.timestamp = behaviorTime
            pose.facingRight = true
            let stopProgress = min(1.0, CGFloat(behaviorTime / 0.8))
            
            pose.torso.root = CGPoint(x: notchLeft - 16.0 + (6.0 * stopProgress), y: ledgeY - 14.0)
            pose.torso.spineAngle = -.pi / 2.0 + 0.15
            pose.headCenter = CGPoint(x: pose.torso.neck.x + 4.0, y: pose.torso.neck.y - 8.0)
            pose.headAngle = 12.0
            
            // Feet planted on ledge
            pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: notchLeft - 22.0, y: ledgeY), bendPositive: false)
            pose.leftLeg.isPlantedOrGripping = true
            pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: notchLeft - 12.0, y: ledgeY), bendPositive: true)
            pose.rightLeg.isPlantedOrGripping = true
            
            // Hands reach over notch bottom-left corner
            let handTargetY = ledgeY + (6.0 * stopProgress)
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: notchLeft - 4.0, y: handTargetY), bendPositive: false)
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: notchLeft + 6.0, y: handTargetY), bendPositive: true)
            
            if behaviorTime >= 1.0 {
                routeStage = .lowerToHang
                behaviorTime = 0.0
                handLWorldX = notchLeft + 4.0
                handRWorldX = notchLeft + 18.0
                pendulumAngle = 0.35
                pendulumVelocity = 0.0
            }
            return pose
            
        case .lowerToHang:
            // Hands grip bottom lip of notch, body lowers under notch
            var pose = SkeletonPose()
            pose.timestamp = behaviorTime
            pose.facingRight = true
            let lowerProgress = min(1.0, CGFloat(behaviorTime / 0.9))
            
            // Hands strictly pinned to notch bottom edge!
            let gripY = ledgeY
            let rootY = ledgeY + (16.0 * lowerProgress)
            let midX = (handLWorldX + handRWorldX) / 2.0
            
            pose.torso.root = CGPoint(x: midX, y: rootY)
            pose.torso.spineAngle = -.pi / 2.0
            pose.headCenter = CGPoint(x: midX, y: rootY - 18.0)
            
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLWorldX, y: gripY), bendPositive: false)
            pose.leftArm.isPlantedOrGripping = true
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRWorldX, y: gripY), bendPositive: true)
            pose.rightArm.isPlantedOrGripping = true
            
            // Legs dangle and swing
            let kick = CGFloat(sin(behaviorTime * 8.0)) * 6.0
            pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: midX - 6.0 + kick, y: rootY + 16.0), bendPositive: false)
            pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: midX + 6.0 - kick, y: rootY + 16.0), bendPositive: true)
            
            if behaviorTime >= 1.0 {
                routeStage = .monkeyBarTraversal
                behaviorTime = 0.0
                monkeyBarStepPhase = 0.0
                activeGrippingHand = 0
            }
            return pose
            
        case .monkeyBarTraversal:
            // Hand over hand along bottom edge of notch from notchLeft to notchRight
            return evaluateMonkeyBarTraversal(dt: dt)
            
        case .climbOntoRightLedge:
            // Reaches up right corner, leg hooks over, rolls onto ledge
            return evaluateClimbOntoRightLedge(dt: dt)
            
        case .rightWalk:
            // Walk from notchRight to right screen corner
            walkDirection = 1.0
            let targetStop = screenWidth - 30.0
            if rootWorldX >= targetStop {
                routeStage = .farCornerPeek
                behaviorTime = 0.0
            }
            return computeWalkPose(dt: dt, walkY: ledgeY)
            
        case .farCornerPeek:
            // Peek at far corner, pivot feet, turn around
            return evaluateFarCornerTurn(dt: dt)
            
        case .reverseWalk:
            // Walk back toward left
            walkDirection = -1.0
            if rootWorldX <= 30.0 {
                routeStage = .leftWalk
                walkDirection = 1.0
            }
            return computeWalkPose(dt: dt, walkY: ledgeY)
        }
    }
    
    // MARK: - Monkey-Bar Traversal (Strict Grip Pinning Invariant)
    private func evaluateMonkeyBarTraversal(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = true
        let gripY = ledgeY
        
        let stepDuration: Double = 0.42
        monkeyBarStepPhase += dt / stepDuration
        
        if monkeyBarStepPhase >= 1.0 {
            monkeyBarStepPhase = 0.0
            activeGrippingHand = (activeGrippingHand == 0) ? 1 : 0
            
            if activeGrippingHand == 0 {
                // Left hand just gripped at forward target!
                handLWorldX = handRWorldX + monkeyBarReach
            } else {
                // Right hand just gripped at forward target!
                handRWorldX = handLWorldX + monkeyBarReach
            }
        }
        
        let u = CGFloat(monkeyBarStepPhase)
        
        // Physics: Body swings forward suspended under the gripping hand
        let anchorHandX = (activeGrippingHand == 0) ? handLWorldX : handRWorldX
        let swingBodyX = anchorHandX + (u - 0.5) * monkeyBarReach
        let bodyY = gripY + 16.0 - CGFloat(cos(Double(u - 0.5) * .pi)) * 3.0
        
        pose.torso.root = CGPoint(x: swingBodyX, y: bodyY)
        pose.torso.spineAngle = -.pi / 2.0 + (activeGrippingHand == 0 ? -0.12 : 0.12)
        pose.headCenter = CGPoint(x: swingBodyX, y: bodyY - 18.0)
        
        // Gripping hand stays 100% LOCKED (grip test invariant: Delta X = 0)
        if activeGrippingHand == 0 {
            // Left hand is gripping
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLWorldX, y: gripY), bendPositive: false)
            pose.leftArm.isPlantedOrGripping = true
            
            // Right hand reaches forward along notch edge
            let reachStart = handLWorldX - monkeyBarReach
            let reachEnd = handLWorldX + monkeyBarReach
            let smoothU = u * u * (3.0 - 2.0 * u)
            let reachX = reachStart + (reachEnd - reachStart) * smoothU
            let reachLift = -5.0 * sin(u * .pi)
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: reachX, y: gripY + reachLift), bendPositive: true)
            pose.rightArm.isPlantedOrGripping = false
            handRWorldX = reachX
            
        } else {
            // Right hand is gripping
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRWorldX, y: gripY), bendPositive: true)
            pose.rightArm.isPlantedOrGripping = true
            
            // Left hand reaches forward
            let reachStart = handRWorldX - monkeyBarReach
            let reachEnd = handRWorldX + monkeyBarReach
            let smoothU = u * u * (3.0 - 2.0 * u)
            let reachX = reachStart + (reachEnd - reachStart) * smoothU
            let reachLift = -5.0 * sin(u * .pi)
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: reachX, y: gripY + reachLift), bendPositive: false)
            pose.leftArm.isPlantedOrGripping = false
            handLWorldX = reachX
        }
        
        // Legs kick rhythmically with swing
        let kickPhase = behaviorTime * 7.0
        let kickL = CGFloat(sin(kickPhase)) * 8.0
        let kickR = CGFloat(-sin(kickPhase)) * 8.0
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: swingBodyX - 5.0 + kickL, y: bodyY + 16.0), bendPositive: false)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: swingBodyX + 5.0 + kickR, y: bodyY + 16.0), bendPositive: true)
        
        // Check if we reached the right edge of the notch!
        let currentMaxHand = max(handLWorldX, handRWorldX)
        if currentMaxHand >= notchRight - 10.0 {
            routeStage = .climbOntoRightLedge
            behaviorTime = 0.0
        }
        
        return pose
    }
    
    // MARK: - Climb Onto Right Ledge
    private func evaluateClimbOntoRightLedge(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = true
        let gripY = ledgeY
        let cornerX = notchRight
        
        if behaviorTime < 0.8 {
            // Arms bend, hoisting torso up
            let liftProgress = CGFloat(behaviorTime / 0.8)
            let rootY = gripY + 16.0 - (12.0 * liftProgress)
            let rootX = cornerX - 6.0 + (6.0 * liftProgress)
            
            pose.torso.root = CGPoint(x: rootX, y: rootY)
            pose.torso.spineAngle = -.pi / 2.0 + (0.2 * Double(liftProgress))
            pose.headCenter = CGPoint(x: rootX + 2.0, y: rootY - 18.0)
            
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 4.0, y: gripY), bendPositive: false)
            pose.leftArm.isPlantedOrGripping = true
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 8.0, y: gripY), bendPositive: true)
            pose.rightArm.isPlantedOrGripping = true
            
            // Leg hooks onto ledge
            let hookProgress = min(1.0, liftProgress * 1.3)
            let hookY = gripY + 16.0 - (16.0 * hookProgress)
            pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: cornerX + 12.0, y: hookY), bendPositive: true)
            pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: rootX - 6.0, y: rootY + 16.0), bendPositive: false)
            
            pose.mouthShape = .gasp
            return pose
            
        } else if behaviorTime < 1.6 {
            // Roll onto ledge
            let rollProgress = CGFloat((behaviorTime - 0.8) / 0.8)
            let rootY = gripY + 4.0 - (18.0 * rollProgress)
            let rootX = cornerX + (16.0 * rollProgress)
            
            pose.torso.root = CGPoint(x: rootX, y: rootY)
            pose.torso.spineAngle = -.pi / 2.0
            pose.headCenter = CGPoint(x: rootX + 4.0, y: rootY - 18.0)
            
            pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: cornerX + 16.0, y: gripY), bendPositive: true)
            pose.rightLeg.isPlantedOrGripping = true
            pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: cornerX + 6.0, y: gripY), bendPositive: false)
            pose.leftLeg.isPlantedOrGripping = true
            
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: rootX - 6.0, y: rootY + 6.0), bendPositive: false)
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: rootX + 6.0, y: rootY + 6.0), bendPositive: true)
            
            pose.mouthShape = .sigh
            return pose
            
        } else {
            // Stood up cleanly on right ledge!
            routeStage = .rightWalk
            behaviorTime = 0.0
            rootWorldX = cornerX + 22.0
            isLeftFootPlanted = true
            leftFootWorldX = rootWorldX
            rightFootWorldX = rootWorldX - walkStepLength
            return computeWalkPose(dt: dt, walkY: ledgeY)
        }
    }
    
    // MARK: - Far Corner Turn & Pivot
    private func evaluateFarCornerTurn(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        let cornerX = screenWidth - 30.0
        
        pose.torso.root = CGPoint(x: cornerX, y: ledgeY - 14.0)
        pose.torso.spineAngle = -.pi / 2.0
        pose.headCenter = CGPoint(x: cornerX, y: ledgeY - 32.0)
        
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: cornerX - 5.0, y: ledgeY), bendPositive: false)
        pose.leftLeg.isPlantedOrGripping = true
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: cornerX + 5.0, y: ledgeY), bendPositive: true)
        pose.rightLeg.isPlantedOrGripping = true
        
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 8.0, y: ledgeY - 6.0), bendPositive: false)
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 8.0, y: ledgeY - 6.0), bendPositive: true)
        
        if behaviorTime < 0.8 {
            // Peek over screen edge
            pose.headAngle = 18.0
            pose.pupilOffset = CGPoint(x: 0.7, y: 0.5)
            pose.facingRight = true
        } else if behaviorTime < 1.6 {
            // Pivot feet
            pose.headAngle = -10.0
            pose.facingRight = false
        } else {
            // Turn complete: walk in reverse!
            routeStage = .reverseWalk
            behaviorTime = 0.0
            walkDirection = -1.0
            rootWorldX = cornerX - 10.0
            isLeftFootPlanted = true
            leftFootWorldX = rootWorldX
            rightFootWorldX = rootWorldX + walkStepLength
        }
        
        return pose
    }
    
    // MARK: - General Walking Gait Computation (Zero Foot Slip Guarantee)
    private func computeWalkPose(dt: Double, walkY: CGFloat) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = (walkDirection > 0)
        
        walkStepPhase += dt / walkStepDuration
        if walkStepPhase >= 1.0 {
            walkStepPhase = 0.0
            isLeftFootPlanted.toggle()
            if isLeftFootPlanted {
                leftFootWorldX = rootWorldX + (walkStepLength / 2.0) * walkDirection
            } else {
                rightFootWorldX = rootWorldX + (walkStepLength / 2.0) * walkDirection
            }
        }
        
        let u = CGFloat(walkStepPhase)
        let plantedFootX = isLeftFootPlanted ? leftFootWorldX : rightFootWorldX
        rootWorldX = plantedFootX + (u - 0.5) * walkStepLength * walkDirection
        
        let bob = -4.0 * CGFloat(cos(Double.pi * 2.0 * Double(u - 0.5)))
        let rootY = walkY - 14.0 + bob
        
        pose.torso.root = CGPoint(x: rootWorldX, y: rootY)
        pose.torso.spineAngle = -.pi / 2.0 + Double(walkDirection) * 0.08
        pose.headCenter = CGPoint(x: pose.torso.neck.x + walkDirection * 2.0, y: pose.torso.neck.y - 8.0)
        pose.headAngle = Double(sin(Double.pi * 2.0 * Double(u))) * 4.0
        
        // Solve Planted & Swing Legs
        if isLeftFootPlanted {
            pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: leftFootWorldX, y: walkY), bendPositive: false)
            pose.leftLeg.isPlantedOrGripping = true
            
            let swingStart = leftFootWorldX - walkStepLength * walkDirection
            let swingEnd = leftFootWorldX + walkStepLength * walkDirection
            let smoothU = u * u * (3.0 - 2.0 * u)
            let swingX = swingStart + (swingEnd - swingStart) * smoothU
            let swingLift = -6.5 * 4.0 * u * (1.0 - u)
            pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: swingX, y: walkY + swingLift), bendPositive: true)
            pose.rightLeg.isPlantedOrGripping = false
            rightFootWorldX = swingX
            
        } else {
            pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rightFootWorldX, y: walkY), bendPositive: true)
            pose.rightLeg.isPlantedOrGripping = true
            
            let swingStart = rightFootWorldX - walkStepLength * walkDirection
            let swingEnd = rightFootWorldX + walkStepLength * walkDirection
            let smoothU = u * u * (3.0 - 2.0 * u)
            let swingX = swingStart + (swingEnd - swingStart) * smoothU
            let swingLift = -6.5 * 4.0 * u * (1.0 - u)
            pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: swingX, y: walkY + swingLift), bendPositive: false)
            pose.leftLeg.isPlantedOrGripping = false
            leftFootWorldX = swingX
        }
        
        // Arm swing in anti-phase
        let armSwingAngle = sin(Double.pi * 2.0 * Double(u)) * 26.0 * Double(walkDirection)
        let swingFactor: CGFloat = isLeftFootPlanted ? 1.0 : -1.0
        let handLY = pose.torso.leftShoulderAnchor.y + 11.0
        let handRY = pose.torso.rightShoulderAnchor.y + 11.0
        let handLX = pose.torso.leftShoulderAnchor.x - CGFloat(sin(armSwingAngle * .pi / 180.0) * 8.0 * Double(swingFactor))
        let handRX = pose.torso.rightShoulderAnchor.x + CGFloat(sin(armSwingAngle * .pi / 180.0) * 8.0 * Double(swingFactor))
        
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLX, y: handLY), bendPositive: false)
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRX, y: handRY), bendPositive: true)
        
        pose.leftEyeOpen = 1.0
        pose.rightEyeOpen = 1.0
        pose.pupilOffset = CGPoint(x: walkDirection * 0.35, y: 0.0)
        
        return pose
    }
    
    // MARK: - Hanging Under Notch
    private func evaluateHangingUnderNotch(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = true
        let gripY = ledgeY
        let midX = (handLWorldX + handRWorldX) / 2.0
        
        let gravity = 18.0
        let armLength: Double = 16.0
        let dampingFactor = 0.85
        let angularAccel = -(gravity / armLength) * sin(pendulumAngle) - (dampingFactor * pendulumVelocity)
        pendulumVelocity += angularAccel * dt
        pendulumAngle += pendulumVelocity * dt
        
        let swayX = CGFloat(armLength * sin(pendulumAngle))
        let swayY = CGFloat(armLength * cos(pendulumAngle))
        let rootY = gripY + swayY
        
        pose.torso.root = CGPoint(x: midX + swayX, y: rootY)
        pose.torso.spineAngle = -.pi / 2.0 + pendulumAngle * 0.6
        pose.headCenter = CGPoint(x: pose.torso.neck.x + swayX * 0.2, y: pose.torso.neck.y - 8.0)
        
        // Pinned hands
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLWorldX, y: gripY), bendPositive: false)
        pose.leftArm.isPlantedOrGripping = true
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRWorldX, y: gripY), bendPositive: true)
        pose.rightArm.isPlantedOrGripping = true
        
        let kick = CGFloat(sin(behaviorTime * 8.0)) * 7.0
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: pose.torso.root.x - 6.0 + kick, y: rootY + 16.0), bendPositive: false)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: pose.torso.root.x + 6.0 - kick, y: rootY + 16.0), bendPositive: true)
        
        pose.leftEyeOpen = 1.35
        pose.rightEyeOpen = 1.35
        pose.mouthShape = .gasp
        return pose
    }
    
    // MARK: - Peeking
    private func evaluatePeek(side: CGFloat, dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = (side < 0)
        let cornerX = (side < 0) ? (notchLeft - 10.0) : (notchRight + 10.0)
        let gripY = ledgeY
        
        if behaviorTime < 0.8 {
            pose.torso.root = CGPoint(x: cornerX, y: -45)
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
            return pose
        } else if behaviorTime < 1.8 {
            let p = CGFloat((behaviorTime - 0.8) / 1.0)
            pose.torso.root = CGPoint(x: cornerX, y: gripY - 24.0)
            pose.headCenter = CGPoint(x: cornerX, y: gripY - 32.0)
            let handY = gripY - 8.0 + (8.0 * p)
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 6.0, y: handY), bendPositive: false)
            pose.leftArm.isPlantedOrGripping = true
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 6.0, y: handY), bendPositive: true)
            pose.rightArm.isPlantedOrGripping = true
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
            return pose
        } else if behaviorTime < 3.4 {
            pose.torso.root = CGPoint(x: cornerX, y: gripY - 18.0)
            pose.headCenter = CGPoint(x: cornerX, y: gripY - 4.0)
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 6.0, y: gripY), bendPositive: false)
            pose.leftArm.isPlantedOrGripping = true
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 6.0, y: gripY), bendPositive: true)
            pose.rightArm.isPlantedOrGripping = true
            if side < 0 {
                pose.rightEyeOpen = 1.0
                pose.leftEyeOpen = 0.0
            } else {
                pose.leftEyeOpen = 1.0
                pose.rightEyeOpen = 0.0
            }
            pose.pupilOffset = CGPoint(x: CGFloat(sin((behaviorTime - 1.8) * 2.5)) * 0.75, y: 0.1)
            return pose
        } else if behaviorTime < 4.2 {
            let p = CGFloat((behaviorTime - 3.4) / 0.8)
            pose.torso.root = CGPoint(x: cornerX, y: gripY - 24.0)
            pose.headCenter = CGPoint(x: cornerX, y: gripY - 4.0 - (8.0 * p))
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 6.0, y: gripY), bendPositive: false)
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 6.0, y: gripY), bendPositive: true)
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
            return pose
        } else {
            let p = min(1.0, CGFloat((behaviorTime - 4.2) / 0.5))
            pose.torso.root = CGPoint(x: cornerX, y: gripY - 16.0)
            pose.headCenter = CGPoint(x: cornerX, y: gripY - 12.0 + (6.0 * p))
            pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 6.0, y: gripY), bendPositive: false)
            pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 6.0, y: gripY), bendPositive: true)
            pose.leftEyeOpen = 1.15
            pose.rightEyeOpen = 1.15
            pose.mouthShape = .smile
            return pose
        }
    }
    
    // MARK: - Cursor Watching & Thinking
    private func evaluateThinking(dt: Double, cursorScreenPos: CGPoint) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        let walkY = ledgeY
        
        pose.torso.root = CGPoint(x: rootWorldX, y: walkY - 14.0)
        pose.torso.spineAngle = -.pi / 2.0
        pose.headCenter = CGPoint(x: rootWorldX, y: walkY - 32.0)
        
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
        let walkY = ledgeY
        pose.torso.root = CGPoint(x: rootWorldX, y: walkY - 6.0)
        pose.headCenter = CGPoint(x: rootWorldX, y: walkY - 14.0)
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: rootWorldX - 8.0, y: walkY - 2.0), bendPositive: false)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rootWorldX + 8.0, y: walkY - 2.0), bendPositive: true)
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: rootWorldX - 5.0, y: walkY - 6.0), bendPositive: false)
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: rootWorldX + 5.0, y: walkY - 6.0), bendPositive: true)
        pose.leftEyeOpen = 0.0
        pose.rightEyeOpen = 0.0
        return pose
    }
    
    private func evaluateTyping(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        let walkY = ledgeY
        pose.torso.root = CGPoint(x: rootWorldX, y: walkY - 14.0)
        pose.headCenter = CGPoint(x: rootWorldX, y: walkY - 32.0)
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
        let walkY = ledgeY
        let beat = sin(behaviorTime * 9.0)
        let bobY = CGFloat(beat) * 2.5
        pose.torso.root = CGPoint(x: rootWorldX, y: walkY - 14.0 + bobY)
        pose.headCenter = CGPoint(x: rootWorldX, y: walkY - 32.0 + bobY * 1.5)
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
        let walkY = ledgeY
        let p = min(1.0, behaviorTime / 0.8)
        let jumpY = CGFloat(sin(p * .pi)) * 20.0
        pose.torso.root = CGPoint(x: rootWorldX, y: walkY - 14.0 - jumpY)
        pose.headCenter = CGPoint(x: rootWorldX, y: walkY - 32.0 - jumpY)
        pose.headAngle = p * 360.0
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: pose.torso.root.x - 5.0, y: pose.torso.root.y + 6.0), bendPositive: false)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: pose.torso.root.x + 5.0, y: pose.torso.root.y + 6.0), bendPositive: true)
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: pose.torso.neck.x - 10.0, y: pose.torso.neck.y - 4.0), bendPositive: false)
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: pose.torso.neck.x + 10.0, y: pose.torso.neck.y - 4.0), bendPositive: true)
        pose.mouthShape = .smile
        return pose
    }
    
    private func evaluateCrawling(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.timestamp = behaviorTime
        pose.facingRight = true
        let crawlY = ledgeY
        rootWorldX += dt * 25.0
        pose.torso.root = CGPoint(x: rootWorldX, y: crawlY - 8.0)
        pose.headCenter = CGPoint(x: rootWorldX + 18.0, y: crawlY - 14.0)
        pose.leftLeg.solveIK(from: pose.torso.leftHipAnchor, toward: CGPoint(x: rootWorldX - 12.0, y: crawlY), bendPositive: false)
        pose.rightLeg.solveIK(from: pose.torso.rightHipAnchor, toward: CGPoint(x: rootWorldX - 4.0, y: crawlY), bendPositive: true)
        pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: rootWorldX + 6.0, y: crawlY), bendPositive: false)
        pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: rootWorldX + 16.0, y: crawlY), bendPositive: true)
        return pose
    }
}
