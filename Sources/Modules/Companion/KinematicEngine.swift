import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Animation Timeline Behavior Stages
public enum PeekStage {
    case hidden
    case handsAppearing
    case singleEyePeeking
    case singleEyeDucking
    case fullFacePopping
    case deciding
}

public enum HangingStage {
    case danglingSway
    case struggleKick
    case armPullUp
    case legHook
    case rollOntoLedge
    case sighOfRelief
}

public enum TurnStage {
    case notTurning
    case stopAtCorner
    case peekOverEdge
    case pivotFeet
    case finishTurn
}

// MARK: - Kinematic Character Animation Engine
@MainActor
public final class KinematicEngine: ObservableObject {
    public static let shared = KinematicEngine()
    
    // Output Current Pose
    @Published public var currentPose: SkeletonPose = SkeletonPose()
    
    // Internal Animation Timelines
    public private(set) var currentBehavior: CompanionBehaviorState = .inDen
    public private(set) var behaviorTime: Double = 0.0
    
    // Gait / Walk State
    public private(set) var walkStepPhase: Double = 0.0       // 0 to 1 per half-stride
    public private(set) var isLeftFootPlanted: Bool = true
    public private(set) var leftFootWorldX: CGFloat = -40.0
    public private(set) var rightFootWorldX: CGFloat = -28.0
    public private(set) var rootWorldX: CGFloat = -34.0
    public private(set) var walkStepLength: CGFloat = 12.0
    public private(set) var walkStepDuration: Double = 0.36
    public private(set) var walkDirection: CGFloat = 1.0      // +1 = right, -1 = left
    public private(set) var turnStage: TurnStage = .notTurning
    public private(set) var turnTimer: Double = 0.0
    
    // Crawl State
    public private(set) var crawlStepPhase: Double = 0.0
    public private(set) var crawlDiagonalPair: Int = 0        // 0 = LH+RF planted, 1 = RH+LF planted
    public private(set) var crawlHandLX: CGFloat = -30.0
    public private(set) var crawlHandRX: CGFloat = -20.0
    public private(set) var crawlFootLX: CGFloat = -42.0
    public private(set) var crawlFootRX: CGFloat = -32.0
    
    // Hanging State
    public private(set) var hangingStage: HangingStage = .danglingSway
    public private(set) var hangingHandLX: CGFloat = 0.0
    public private(set) var hangingHandRX: CGFloat = 18.0
    public private(set) var pendulumAngle: Double = 0.0
    public private(set) var pendulumVelocity: Double = 0.0
    
    // Peek State
    public private(set) var peekStage: PeekStage = .hidden
    public private(set) var peekSide: CGFloat = -1.0          // -1 = left corner, +1 = right corner
    
    // Cursor Tracking Spring Damper
    private var headAngleSpring = SpringDamper(stiffness: 140.0, damping: 16.0)
    private var eyeTrackXSpring = SpringDamper(stiffness: 180.0, damping: 18.0)
    private var eyeTrackYSpring = SpringDamper(stiffness: 180.0, damping: 18.0)
    private var bodyBobSpring = SpringDamper(stiffness: 260.0, damping: 20.0)
    
    // Blink & Breathing Timers
    private var blinkTimer: Double = 3.0
    private var isBlinking: Bool = false
    private var breathingCycle: Double = 0.0
    
    public init() {
        resetToDen()
    }
    
    // MARK: - Behavior Transition
    public func setBehavior(_ behavior: CompanionBehaviorState, notchWidth: CGFloat = 185.0) {
        currentBehavior = behavior
        behaviorTime = 0.0
        
        switch behavior {
        case .inDen:
            resetToDen()
            
        case .peekingLeft:
            peekSide = -1.0
            setupPeek(notchWidth: notchWidth)
            
        case .peekingRight:
            peekSide = 1.0
            setupPeek(notchWidth: notchWidth)
            
        case .walking:
            setupWalking(notchWidth: notchWidth)
            
        case .crawling:
            setupCrawling(notchWidth: notchWidth)
            
        case .slipping, .dangling:
            setupHanging()
            
        case .pullingUp:
            hangingStage = .armPullUp
            behaviorTime = 0.0
            
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
        }
    }
    
    // MARK: - Setup Helpers
    private func resetToDen() {
        currentPose = SkeletonPose()
        currentPose.root = CGPoint(x: 0, y: -45)
        currentPose.head = CGPoint(x: 0, y: -58)
        currentPose.chest = CGPoint(x: 0, y: -50)
        currentPose.leftEyeOpen = 0.0
        currentPose.rightEyeOpen = 0.0
    }
    
    private func setupPeek(notchWidth: CGFloat) {
        peekStage = .handsAppearing
        let cornerX = (notchWidth / 2.0 - 10.0) * peekSide
        rootWorldX = cornerX
        currentPose.facingRight = (peekSide < 0)
        hangingHandLX = cornerX - 7.0
        hangingHandRX = cornerX + 7.0
    }
    
    private func setupWalking(notchWidth: CGFloat) {
        turnStage = .notTurning
        walkDirection = Bool.random() ? 1.0 : -1.0
        let halfNotch = max(notchWidth / 2.0 - 25.0, 50.0)
        rootWorldX = walkDirection > 0 ? -halfNotch : halfNotch
        isLeftFootPlanted = true
        leftFootWorldX = rootWorldX
        rightFootWorldX = rootWorldX - walkStepLength * walkDirection
        walkStepPhase = 0.0
        currentPose.facingRight = (walkDirection > 0)
    }
    
    private func setupCrawling(notchWidth: CGFloat) {
        walkDirection = 1.0
        let halfNotch = max(notchWidth / 2.0 - 25.0, 50.0)
        rootWorldX = -halfNotch
        crawlHandLX = rootWorldX + 6.0
        crawlHandRX = rootWorldX + 16.0
        crawlFootLX = rootWorldX - 14.0
        crawlFootRX = rootWorldX - 4.0
        crawlStepPhase = 0.0
        crawlDiagonalPair = 0
        currentPose.facingRight = true
    }
    
    private func setupHanging() {
        hangingStage = .danglingSway
        let cornerX = CGFloat.random(in: -30...30)
        rootWorldX = cornerX
        hangingHandLX = cornerX - 8.0
        hangingHandRX = cornerX + 8.0
        pendulumAngle = 0.45 // Initial displacement in radians
        pendulumVelocity = 0.0
    }
    
    private func setupThinking() {
        currentPose.mouthShape = .neutral
        headAngleSpring.target = 0.12
    }
    
    private func setupSleeping() {
        rootWorldX = 0.0
        currentPose.root = CGPoint(x: 0, y: -6)
        currentPose.head = CGPoint(x: 0, y: -10)
        currentPose.leftEyeOpen = 0.0
        currentPose.rightEyeOpen = 0.0
        currentPose.mouthShape = .neutral
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
    
    // MARK: - Frame-by-Frame Engine Update
    public func update(deltaTime: Double, cursorNotchPos: CGPoint, notchWidth: CGFloat = 185.0) {
        let dt = min(0.05, max(0.001, deltaTime))
        behaviorTime += dt
        
        // 1. Natural Breathing Cycle
        breathingCycle += dt * 2.2
        let breathScale = 1.0 + 0.03 * CGFloat(sin(breathingCycle))
        
        // 2. Periodic Blinking
        blinkTimer -= dt
        if blinkTimer <= 0 {
            isBlinking = true
            blinkTimer = Double.random(in: 2.8...5.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.isBlinking = false
            }
        }
        
        // 3. Behavior-Specific Kinematics
        var pose = SkeletonPose()
        pose.breathScale = breathScale
        
        switch currentBehavior {
        case .inDen:
            pose = currentPose
            pose.root.y = -45
            
        case .peekingLeft, .peekingRight:
            pose = evaluatePeek(dt: dt, notchWidth: notchWidth)
            
        case .walking:
            pose = evaluateWalking(dt: dt, notchWidth: notchWidth)
            
        case .crawling:
            pose = evaluateCrawling(dt: dt, notchWidth: notchWidth)
            
        case .slipping, .dangling, .pullingUp:
            pose = evaluateHanging(dt: dt)
            
        case .thinking, .curious:
            pose = evaluateThinking(dt: dt, cursorNotchPos: cursorNotchPos)
            
        case .sleeping:
            pose = evaluateSleeping(dt: dt)
            
        case .typingMimic:
            pose = evaluateTyping(dt: dt)
            
        case .musicGroove:
            pose = evaluateMusicGroove(dt: dt)
            
        case .celebrating:
            pose = evaluateCelebrating(dt: dt)
        }
        
        // Eye Blinks
        if isBlinking {
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
        }
        
        currentPose = pose
    }
    
    // MARK: - 1. PEEK Choreography Engine
    private func evaluatePeek(dt: Double, notchWidth: CGFloat) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.facingRight = (peekSide < 0)
        
        let cornerX = (notchWidth / 2.0 - 12.0) * peekSide
        let lipY: CGFloat = 0.0 // Notch bottom edge
        
        // Stage Timings:
        // 0.0 - 0.8: wait in den
        // 0.8 - 1.8: two hands appear on lip, curling over
        // 1.8 - 3.4: ONE eye rises above edge, looks left and right
        // 3.4 - 4.2: eye ducks down
        // 4.2 - 6.2: head pops up with BOTH eyes, blinks
        
        if behaviorTime < 0.8 {
            // Nothing visible
            peekStage = .hidden
            pose.root = CGPoint(x: cornerX, y: -45)
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
            return pose
            
        } else if behaviorTime < 1.8 {
            // Hands appear on edge
            peekStage = .handsAppearing
            let progress = CGFloat((behaviorTime - 0.8) / 1.0)
            let handY = lipY - 8.0 + (8.0 * progress)
            
            pose.root = CGPoint(x: cornerX, y: -25)
            pose.chest = CGPoint(x: cornerX, y: -28)
            pose.head = CGPoint(x: cornerX, y: -34)
            
            pose.leftHand = CGPoint(x: cornerX - 7.0, y: handY)
            pose.rightHand = CGPoint(x: cornerX + 7.0, y: handY)
            pose.leftHandPlanted = true
            pose.rightHandPlanted = true
            
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
            
            solveArms(pose: &pose)
            solveLegsTucked(pose: &pose)
            return pose
            
        } else if behaviorTime < 3.4 {
            // ONE eye appears above the edge, pupil sweeps
            peekStage = .singleEyePeeking
            let eyeTime = behaviorTime - 1.8
            
            // Hands firmly planted on edge!
            pose.leftHand = CGPoint(x: cornerX - 7.0, y: lipY)
            pose.rightHand = CGPoint(x: cornerX + 7.0, y: lipY)
            pose.leftHandPlanted = true
            pose.rightHandPlanted = true
            
            // Raise head just enough for one eye to crest lip
            let headY = lipY - 3.0
            pose.root = CGPoint(x: cornerX, y: -18)
            pose.chest = CGPoint(x: cornerX, y: -22)
            pose.head = CGPoint(x: cornerX, y: headY)
            
            // One eye open, other eye still below edge
            if peekSide < 0 {
                pose.rightEyeOpen = 1.0
                pose.leftEyeOpen = 0.0
            } else {
                pose.leftEyeOpen = 1.0
                pose.rightEyeOpen = 0.0
            }
            
            // Pupil sweeps smoothly left then right
            let sweepPhase = CGFloat(sin(eyeTime * 2.5))
            pose.pupilOffset = CGPoint(x: sweepPhase * 0.75, y: 0.1)
            
            solveArms(pose: &pose)
            solveLegsTucked(pose: &pose)
            return pose
            
        } else if behaviorTime < 4.2 {
            // Eye ducks down
            peekStage = .singleEyeDucking
            let duckProgress = CGFloat((behaviorTime - 3.4) / 0.8)
            
            pose.leftHand = CGPoint(x: cornerX - 7.0, y: lipY)
            pose.rightHand = CGPoint(x: cornerX + 7.0, y: lipY)
            pose.leftHandPlanted = true
            pose.rightHandPlanted = true
            
            let headY = (lipY - 3.0) - (8.0 * duckProgress)
            pose.root = CGPoint(x: cornerX, y: -24)
            pose.chest = CGPoint(x: cornerX, y: -27)
            pose.head = CGPoint(x: cornerX, y: headY)
            
            pose.leftEyeOpen = 0.0
            pose.rightEyeOpen = 0.0
            
            solveArms(pose: &pose)
            solveLegsTucked(pose: &pose)
            return pose
            
        } else {
            // Head pops up with BOTH eyes!
            peekStage = .fullFacePopping
            let popProgress = min(1.0, CGFloat((behaviorTime - 4.2) / 0.5))
            
            pose.leftHand = CGPoint(x: cornerX - 7.0, y: lipY)
            pose.rightHand = CGPoint(x: cornerX + 7.0, y: lipY)
            pose.leftHandPlanted = true
            pose.rightHandPlanted = true
            
            let headY = -12.0 + (6.0 * popProgress)
            pose.root = CGPoint(x: cornerX, y: -16)
            pose.chest = CGPoint(x: cornerX, y: -20)
            pose.head = CGPoint(x: cornerX, y: headY)
            
            // Both eyes open!
            pose.leftEyeOpen = 1.15
            pose.rightEyeOpen = 1.15
            pose.pupilOffset = CGPoint(x: (peekSide < 0 ? 0.3 : -0.3), y: 0.1)
            pose.mouthShape = .smile
            
            solveArms(pose: &pose)
            solveLegsTucked(pose: &pose)
            return pose
        }
    }
    
    // MARK: - 2. HANGING & PULL-UP Engine
    private func evaluateHanging(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.facingRight = true
        let lipY: CGFloat = 0.0
        
        // Pinned hands on notch edge
        pose.leftHand = CGPoint(x: hangingHandLX, y: lipY)
        pose.rightHand = CGPoint(x: hangingHandRX, y: lipY)
        pose.leftHandPlanted = true
        pose.rightHandPlanted = true
        
        let anchorMidX = (hangingHandLX + hangingHandRX) / 2.0
        
        if currentBehavior == .pullingUp || hangingStage == .armPullUp || behaviorTime > 3.0 {
            // Pull-up sequence:
            let pullTime = behaviorTime - 3.0
            
            if pullTime < 0.8 {
                // Arms bend, hoisting torso up
                let liftProgress = CGFloat(pullTime / 0.8)
                let rootY = 16.0 - (10.0 * liftProgress)
                
                pose.root = CGPoint(x: anchorMidX, y: rootY)
                pose.chest = CGPoint(x: anchorMidX, y: rootY - 10.0)
                pose.head = CGPoint(x: anchorMidX, y: rootY - 18.0)
                
                // Eyes wide with strain
                pose.leftEyeOpen = 1.3
                pose.rightEyeOpen = 1.3
                pose.mouthShape = .openW
                
                // One leg hooks up to edge
                let hookProgress = min(1.0, liftProgress * 1.4)
                pose.rightFoot = CGPoint(x: anchorMidX + 14.0, y: 16.0 - (16.0 * hookProgress))
                pose.leftFoot = CGPoint(x: anchorMidX - 6.0, y: 22.0)
                
                solveArms(pose: &pose)
                solveLegs(pose: &pose)
                return pose
                
            } else if pullTime < 1.6 {
                // Rolled onto ledge
                let rollProgress = CGFloat((pullTime - 0.8) / 0.8)
                let rootY = 6.0 - (18.0 * rollProgress)
                
                pose.root = CGPoint(x: anchorMidX, y: rootY)
                pose.chest = CGPoint(x: anchorMidX, y: rootY - 12.0)
                pose.head = CGPoint(x: anchorMidX, y: rootY - 20.0)
                
                pose.rightFoot = CGPoint(x: anchorMidX + 10.0, y: lipY)
                pose.leftFoot = CGPoint(x: anchorMidX - 10.0, y: lipY)
                pose.rightFootPlanted = true
                pose.leftFootPlanted = true
                
                // Relief sigh
                pose.mouthShape = .sigh
                pose.leftEyeOpen = 0.8
                pose.rightEyeOpen = 0.8
                
                solveArms(pose: &pose)
                solveLegs(pose: &pose)
                return pose
                
            } else {
                // Standing relieved on ledge
                pose.root = CGPoint(x: anchorMidX, y: -12.0)
                pose.chest = CGPoint(x: anchorMidX, y: -24.0)
                pose.head = CGPoint(x: anchorMidX, y: -32.0)
                
                pose.rightFoot = CGPoint(x: anchorMidX + 8.0, y: lipY)
                pose.leftFoot = CGPoint(x: anchorMidX - 8.0, y: lipY)
                pose.rightFootPlanted = true
                pose.leftFootPlanted = true
                
                pose.leftHand = CGPoint(x: anchorMidX - 10.0, y: -16.0)
                pose.rightHand = CGPoint(x: anchorMidX + 10.0, y: -16.0)
                pose.leftHandPlanted = false
                pose.rightHandPlanted = false
                
                pose.mouthShape = .smile
                pose.leftEyeOpen = 1.0
                pose.rightEyeOpen = 1.0
                
                solveArms(pose: &pose)
                solveLegs(pose: &pose)
                return pose
            }
            
        } else {
            // Dangling and swaying pendulum under gravity
            let gravity = 18.0
            let armLength: Double = 16.0
            let dampingFactor = 0.85
            
            let angularAccel = -(gravity / armLength) * sin(pendulumAngle) - (dampingFactor * pendulumVelocity)
            pendulumVelocity += angularAccel * dt
            pendulumAngle += pendulumVelocity * dt
            
            let swayX = CGFloat(armLength * sin(pendulumAngle))
            let swayY = CGFloat(armLength * cos(pendulumAngle))
            
            pose.root = CGPoint(x: anchorMidX + swayX, y: lipY + swayY)
            pose.chest = CGPoint(x: anchorMidX + swayX * 0.7, y: lipY + swayY - 10.0)
            pose.head = CGPoint(x: anchorMidX + swayX * 0.5, y: lipY + swayY - 18.0)
            pose.headAngle = pendulumAngle * 15.0
            
            // Kicking legs in anti-phase
            let kickPhase = behaviorTime * 8.0
            let kickL = CGFloat(sin(kickPhase)) * 8.0
            let kickR = CGFloat(-sin(kickPhase)) * 8.0
            
            pose.leftFoot = CGPoint(x: pose.root.x - 6.0 + kickL, y: pose.root.y + 16.0)
            pose.rightFoot = CGPoint(x: pose.root.x + 6.0 + kickR, y: pose.root.y + 16.0)
            
            // Wide terrified eyes
            pose.leftEyeOpen = 1.35
            pose.rightEyeOpen = 1.35
            pose.mouthShape = .gasp
            
            solveArms(pose: &pose)
            solveLegs(pose: &pose)
            return pose
        }
    }
    
    // MARK: - 3. WALKING Inverted Pendulum Gait (Zero Foot Slip Guarantee)
    private func evaluateWalking(dt: Double, notchWidth: CGFloat) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.facingRight = (walkDirection > 0)
        let lipY: CGFloat = 0.0
        
        let cornerMargin: CGFloat = notchWidth / 2.0 - 20.0
        
        // Check for boundary turn-around
        if (rootWorldX >= cornerMargin && walkDirection > 0) || (rootWorldX <= -cornerMargin && walkDirection < 0) {
            turnStage = .stopAtCorner
        }
        
        if turnStage != .notTurning {
            return evaluateTurnAtCorner(dt: dt)
        }
        
        // Stride Phase Progress
        walkStepPhase += dt / walkStepDuration
        
        if walkStepPhase >= 1.0 {
            // Step complete: plant the swing foot at its target!
            walkStepPhase = 0.0
            isLeftFootPlanted.toggle()
            
            if isLeftFootPlanted {
                // Left foot just planted, right foot becomes swing foot
                leftFootWorldX = rootWorldX + (walkStepLength / 2.0) * walkDirection
            } else {
                // Right foot just planted, left foot becomes swing foot
                rightFootWorldX = rootWorldX + (walkStepLength / 2.0) * walkDirection
            }
        }
        
        let u = CGFloat(walkStepPhase)
        
        // Biological Inverted Pendulum Rule:
        // The root X is calculated relative to the currently PLANTED foot.
        // At u = 0.0, root is behind planted foot: root = plant - (stepLength / 2)
        // At u = 0.5, root passes directly over planted foot: root = plant
        // At u = 1.0, root is ahead of planted foot: root = plant + (stepLength / 2)
        let plantedFootX = isLeftFootPlanted ? leftFootWorldX : rightFootWorldX
        rootWorldX = plantedFootX + (u - 0.5) * walkStepLength * walkDirection
        
        // Vertical Bob: vaults over the straight planted leg (inverted pendulum arc)
        let bob = -4.0 * CGFloat(cos(Double.pi * 2.0 * Double(u - 0.5)))
        let rootY = lipY - 14.0 + bob
        pose.root = CGPoint(x: rootWorldX, y: rootY)
        
        // Torso & Head
        pose.pelvisAngle = Double(sin(Double.pi * 2.0 * Double(u))) * 4.0 * Double(walkDirection)
        pose.chest = CGPoint(x: rootWorldX + CGFloat(walkDirection) * 1.5, y: rootY - 12.0)
        pose.head = CGPoint(x: rootWorldX + CGFloat(walkDirection) * 3.0, y: rootY - 20.0)
        pose.headAngle = Double(sin(Double.pi * 2.0 * Double(u))) * 3.0
        
        // Planted foot coordinates (STRICT ZERO SLIP INVARIANT: dx = 0)
        if isLeftFootPlanted {
            pose.leftFoot = CGPoint(x: leftFootWorldX, y: lipY)
            pose.leftFootPlanted = true
            
            // Right foot is swinging
            let swingStart = leftFootWorldX - walkStepLength * walkDirection
            let swingEnd = leftFootWorldX + walkStepLength * walkDirection
            let smoothU = u * u * (3.0 - 2.0 * u) // Smoothstep
            let swingX = swingStart + (swingEnd - swingStart) * smoothU
            let swingLift = -6.5 * 4.0 * u * (1.0 - u) // Parabolic lift
            pose.rightFoot = CGPoint(x: swingX, y: lipY + swingLift)
            pose.rightFootPlanted = false
            rightFootWorldX = swingX
            
        } else {
            pose.rightFoot = CGPoint(x: rightFootWorldX, y: lipY)
            pose.rightFootPlanted = true
            
            // Left foot is swinging
            let swingStart = rightFootWorldX - walkStepLength * walkDirection
            let swingEnd = rightFootWorldX + walkStepLength * walkDirection
            let smoothU = u * u * (3.0 - 2.0 * u)
            let swingX = swingStart + (swingEnd - swingStart) * smoothU
            let swingLift = -6.5 * 4.0 * u * (1.0 - u)
            pose.leftFoot = CGPoint(x: swingX, y: lipY + swingLift)
            pose.leftFootPlanted = false
            leftFootWorldX = swingX
        }
        
        // Arms Swing in Anti-Phase (180 deg opposite to legs)
        let armSwingAngle = sin(Double.pi * 2.0 * Double(u)) * 28.0 * Double(walkDirection)
        let swingFactor: CGFloat = isLeftFootPlanted ? 1.0 : -1.0
        
        pose.leftHand = CGPoint(
            x: pose.chest.x - CGFloat(sin(armSwingAngle * Double.pi / 180.0) * 10.0 * Double(swingFactor)),
            y: pose.chest.y + 11.0
        )
        pose.rightHand = CGPoint(
            x: pose.chest.x + CGFloat(sin(armSwingAngle * Double.pi / 180.0) * 10.0 * Double(swingFactor)),
            y: pose.chest.y + 11.0
        )
        
        // Face
        pose.leftEyeOpen = 1.0
        pose.rightEyeOpen = 1.0
        pose.pupilOffset = CGPoint(x: walkDirection * 0.4, y: 0.0)
        pose.mouthShape = .neutral
        
        solveArms(pose: &pose)
        solveLegs(pose: &pose)
        return pose
    }
    
    // MARK: - Turn-Around at Corner (Foot Pivot, No Sprite Flip!)
    private func evaluateTurnAtCorner(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        turnTimer += dt
        let lipY: CGFloat = 0.0
        
        pose.leftFoot = CGPoint(x: rootWorldX - 4.0, y: lipY)
        pose.rightFoot = CGPoint(x: rootWorldX + 4.0, y: lipY)
        pose.leftFootPlanted = true
        pose.rightFootPlanted = true
        
        if turnTimer < 0.6 {
            // Stop and peek over the edge
            pose.root = CGPoint(x: rootWorldX, y: lipY - 12.0)
            pose.chest = CGPoint(x: rootWorldX + (walkDirection * 3.0), y: lipY - 22.0)
            pose.head = CGPoint(x: rootWorldX + (walkDirection * 6.0), y: lipY - 28.0)
            pose.headAngle = 18.0 * Double(walkDirection)
            pose.pupilOffset = CGPoint(x: walkDirection * 0.7, y: 0.6)
            pose.facingRight = (walkDirection > 0)
            
        } else if turnTimer < 1.2 {
            // Lift front foot and pivot
            pose.root = CGPoint(x: rootWorldX, y: lipY - 14.0)
            pose.chest = CGPoint(x: rootWorldX, y: lipY - 24.0)
            pose.head = CGPoint(x: rootWorldX, y: lipY - 32.0)
            pose.facingRight = (walkDirection > 0)
            
        } else {
            // Turn complete: reverse direction and resume walking!
            walkDirection = -walkDirection
            turnStage = .notTurning
            turnTimer = 0.0
            pose.facingRight = (walkDirection > 0)
            isLeftFootPlanted = true
            leftFootWorldX = rootWorldX
            rightFootWorldX = rootWorldX - walkStepLength * walkDirection
        }
        
        pose.leftHand = CGPoint(x: pose.chest.x - 7.0, y: pose.chest.y + 10.0)
        pose.rightHand = CGPoint(x: pose.chest.x + 7.0, y: pose.chest.y + 10.0)
        
        solveArms(pose: &pose)
        solveLegs(pose: &pose)
        return pose
    }
    
    // MARK: - 4. CRAWLING (Quadruped Diagonal Gait)
    private func evaluateCrawling(dt: Double, notchWidth: CGFloat) -> SkeletonPose {
        var pose = SkeletonPose()
        pose.facingRight = (walkDirection > 0)
        let lipY: CGFloat = 0.0
        
        crawlStepPhase += dt / 0.42
        if crawlStepPhase >= 1.0 {
            crawlStepPhase = 0.0
            crawlDiagonalPair = (crawlDiagonalPair == 0) ? 1 : 0
        }
        
        let u = CGFloat(crawlStepPhase)
        let crawlStep: CGFloat = 8.0
        rootWorldX += (dt / 0.42) * crawlStep * walkDirection
        
        // Low to ground
        let rootY = lipY - 8.0
        pose.root = CGPoint(x: rootWorldX, y: rootY)
        pose.chest = CGPoint(x: rootWorldX + 12.0 * walkDirection, y: rootY - 3.0)
        pose.head = CGPoint(x: rootWorldX + 20.0 * walkDirection, y: rootY - 8.0)
        pose.headAngle = -8.0
        
        if crawlDiagonalPair == 0 {
            // Pair 0: Left Hand & Right Foot planted
            pose.leftHand = CGPoint(x: crawlHandLX, y: lipY)
            pose.leftHandPlanted = true
            pose.rightFoot = CGPoint(x: crawlFootRX, y: lipY)
            pose.rightFootPlanted = true
            
            // Right Hand & Left Foot swinging forward
            let swingHand = crawlHandLX + crawlStep * 2.0 * u
            pose.rightHand = CGPoint(x: swingHand, y: lipY - 4.0 * sin(u * .pi))
            pose.rightHandPlanted = false
            crawlHandRX = swingHand
            
            let swingFoot = crawlFootRX - 12.0 + crawlStep * 2.0 * u
            pose.leftFoot = CGPoint(x: swingFoot, y: lipY - 3.0 * sin(u * .pi))
            pose.leftFootPlanted = false
            crawlFootLX = swingFoot
            
        } else {
            // Pair 1: Right Hand & Left Foot planted
            pose.rightHand = CGPoint(x: crawlHandRX, y: lipY)
            pose.rightHandPlanted = true
            pose.leftFoot = CGPoint(x: crawlFootLX, y: lipY)
            pose.leftFootPlanted = true
            
            let swingHand = crawlHandRX + crawlStep * 2.0 * u
            pose.leftHand = CGPoint(x: swingHand, y: lipY - 4.0 * sin(u * .pi))
            pose.leftHandPlanted = false
            crawlHandLX = swingHand
            
            let swingFoot = crawlFootLX - 12.0 + crawlStep * 2.0 * u
            pose.rightFoot = CGPoint(x: swingFoot, y: lipY - 3.0 * sin(u * .pi))
            pose.rightFootPlanted = false
            crawlFootRX = swingFoot
        }
        
        pose.leftEyeOpen = 1.0
        pose.rightEyeOpen = 1.0
        pose.pupilOffset = CGPoint(x: 0.5, y: -0.2)
        
        solveArms(pose: &pose)
        solveLegs(pose: &pose)
        return pose
    }
    
    // MARK: - 5. THINKING & CURSOR TRACKING Engine
    private func evaluateThinking(dt: Double, cursorNotchPos: CGPoint) -> SkeletonPose {
        var pose = SkeletonPose()
        let lipY: CGFloat = 0.0
        
        // Hips resting on stance leg
        pose.root = CGPoint(x: rootWorldX, y: lipY - 14.0)
        pose.weightShift = -0.5
        pose.pelvisAngle = -6.0
        
        pose.chest = CGPoint(x: rootWorldX + 1.0, y: lipY - 24.0)
        pose.head = CGPoint(x: rootWorldX + 2.0, y: lipY - 32.0)
        
        // Both feet planted solidly
        pose.leftFoot = CGPoint(x: rootWorldX - 7.0, y: lipY)
        pose.rightFoot = CGPoint(x: rootWorldX + 6.0, y: lipY)
        pose.leftFootPlanted = true
        pose.rightFootPlanted = true
        
        // Cursor tracking spring math
        let targetAngle = atan2(cursorNotchPos.y - pose.head.y, cursorNotchPos.x - pose.head.x)
        let clampedTargetAngle = min(0.6, max(-0.6, Double(targetAngle) * 0.4))
        headAngleSpring.target = clampedTargetAngle
        headAngleSpring.update(dt: dt)
        pose.headAngle = headAngleSpring.position * 180.0 / .pi
        
        // Pupil spring tracking
        let targetPupilX = min(0.85, max(-0.85, (cursorNotchPos.x - pose.head.x) / 120.0))
        let targetPupilY = min(0.85, max(-0.85, (cursorNotchPos.y - pose.head.y) / 120.0))
        eyeTrackXSpring.target = Double(targetPupilX)
        eyeTrackXSpring.update(dt: dt)
        eyeTrackYSpring.target = Double(targetPupilY)
        eyeTrackYSpring.update(dt: dt)
        pose.pupilOffset = CGPoint(x: CGFloat(eyeTrackXSpring.position), y: CGFloat(eyeTrackYSpring.position))
        
        // Right hand to chin / mouth!
        pose.rightHand = CGPoint(x: pose.head.x + 3.0, y: pose.head.y + 6.0)
        pose.rightHandPlanted = false
        
        // Left arm tucked onto hip
        pose.leftHand = CGPoint(x: pose.root.x - 7.0, y: pose.root.y - 2.0)
        pose.leftHandPlanted = false
        
        pose.mouthShape = .neutral
        pose.leftEyeOpen = 1.0
        pose.rightEyeOpen = 1.0
        
        solveArms(pose: &pose)
        solveLegs(pose: &pose)
        return pose
    }
    
    // MARK: - 6. Auxiliary Skeleton-Driven Behaviors
    private func evaluateSleeping(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        let lipY: CGFloat = 0.0
        
        pose.root = CGPoint(x: 0, y: lipY - 6.0)
        pose.chest = CGPoint(x: 0, y: lipY - 10.0)
        pose.head = CGPoint(x: 0, y: lipY - 14.0)
        
        pose.leftFoot = CGPoint(x: -8, y: lipY - 2)
        pose.rightFoot = CGPoint(x: 8, y: lipY - 2)
        pose.leftHand = CGPoint(x: -5, y: lipY - 6)
        pose.rightHand = CGPoint(x: 5, y: lipY - 6)
        
        pose.leftEyeOpen = 0.0
        pose.rightEyeOpen = 0.0
        pose.mouthShape = .neutral
        
        solveArms(pose: &pose)
        solveLegs(pose: &pose)
        return pose
    }
    
    private func evaluateTyping(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        let lipY: CGFloat = 0.0
        
        pose.root = CGPoint(x: rootWorldX, y: lipY - 14.0)
        pose.chest = CGPoint(x: rootWorldX, y: lipY - 24.0)
        pose.head = CGPoint(x: rootWorldX, y: lipY - 32.0)
        
        pose.leftFoot = CGPoint(x: rootWorldX - 6.0, y: lipY)
        pose.rightFoot = CGPoint(x: rootWorldX + 6.0, y: lipY)
        pose.leftFootPlanted = true
        pose.rightFootPlanted = true
        
        // Alternating typing paws
        let pawAlt = sin(behaviorTime * 18.0) > 0
        pose.leftHand = CGPoint(x: rootWorldX - 4.0, y: lipY - 7.0 + (pawAlt ? -3.0 : 0.0))
        pose.rightHand = CGPoint(x: rootWorldX + 4.0, y: lipY - 7.0 + (pawAlt ? 0.0 : -3.0))
        
        pose.mouthShape = .openW
        pose.leftEyeOpen = 1.05
        pose.rightEyeOpen = 1.05
        
        solveArms(pose: &pose)
        solveLegs(pose: &pose)
        return pose
    }
    
    private func evaluateMusicGroove(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        let lipY: CGFloat = 0.0
        
        let beat = sin(behaviorTime * 9.0)
        let bobY = CGFloat(beat) * 2.5
        
        pose.root = CGPoint(x: rootWorldX, y: lipY - 14.0 + bobY)
        pose.chest = CGPoint(x: rootWorldX, y: lipY - 24.0 + bobY)
        pose.head = CGPoint(x: rootWorldX, y: lipY - 32.0 + bobY * 1.5)
        pose.headAngle = beat * 8.0
        
        pose.leftFoot = CGPoint(x: rootWorldX - 6.0, y: lipY)
        pose.rightFoot = CGPoint(x: rootWorldX + 6.0, y: lipY)
        pose.leftFootPlanted = true
        pose.rightFootPlanted = true
        
        // Hands holding headphone bands
        pose.leftHand = CGPoint(x: pose.head.x - 11.0, y: pose.head.y + 4.0)
        pose.rightHand = CGPoint(x: pose.head.x + 11.0, y: pose.head.y + 4.0)
        
        pose.mouthShape = .smile
        pose.leftEyeOpen = 1.0
        pose.rightEyeOpen = 1.0
        
        solveArms(pose: &pose)
        solveLegs(pose: &pose)
        return pose
    }
    
    private func evaluateCelebrating(dt: Double) -> SkeletonPose {
        var pose = SkeletonPose()
        let lipY: CGFloat = 0.0
        
        let jumpProgress = min(1.0, behaviorTime / 0.8)
        let jumpHeight = CGFloat(sin(jumpProgress * .pi)) * 18.0
        
        pose.root = CGPoint(x: rootWorldX, y: lipY - 14.0 - jumpHeight)
        pose.chest = CGPoint(x: rootWorldX, y: lipY - 24.0 - jumpHeight)
        pose.head = CGPoint(x: rootWorldX, y: lipY - 32.0 - jumpHeight)
        pose.headAngle = jumpProgress * 360.0
        
        // Tucked happy limbs in air
        pose.leftFoot = CGPoint(x: pose.root.x - 5.0, y: pose.root.y + 6.0)
        pose.rightFoot = CGPoint(x: pose.root.x + 5.0, y: pose.root.y + 6.0)
        pose.leftHand = CGPoint(x: pose.chest.x - 10.0, y: pose.chest.y - 4.0)
        pose.rightHand = CGPoint(x: pose.chest.x + 10.0, y: pose.chest.y - 4.0)
        
        pose.mouthShape = .smile
        pose.leftEyeOpen = 1.2
        pose.rightEyeOpen = 1.2
        
        solveArms(pose: &pose)
        solveLegs(pose: &pose)
        return pose
    }
    
    // MARK: - 2-Bone IK Solvers for Arms & Legs
    private func solveArms(pose: inout SkeletonPose) {
        pose.leftShoulder = CGPoint(x: pose.chest.x - 6.0, y: pose.chest.y + 2.0)
        pose.rightShoulder = CGPoint(x: pose.chest.x + 6.0, y: pose.chest.y + 2.0)
        
        let leftArmIK = TwoBoneIK.solve(
            root: pose.leftShoulder,
            target: pose.leftHand,
            length1: SkeletonPose.upperArmLength,
            length2: SkeletonPose.forearmLength,
            bendPositive: false
        )
        pose.leftElbow = leftArmIK.joint
        
        let rightArmIK = TwoBoneIK.solve(
            root: pose.rightShoulder,
            target: pose.rightHand,
            length1: SkeletonPose.upperArmLength,
            length2: SkeletonPose.forearmLength,
            bendPositive: true
        )
        pose.rightElbow = rightArmIK.joint
    }
    
    private func solveLegs(pose: inout SkeletonPose) {
        pose.leftHip = CGPoint(x: pose.root.x - 4.5, y: pose.root.y + 2.0)
        pose.rightHip = CGPoint(x: pose.root.x + 4.5, y: pose.root.y + 2.0)
        
        let leftLegIK = TwoBoneIK.solve(
            root: pose.leftHip,
            target: pose.leftFoot,
            length1: SkeletonPose.thighLength,
            length2: SkeletonPose.calfLength,
            bendPositive: false
        )
        pose.leftKnee = leftLegIK.joint
        
        let rightLegIK = TwoBoneIK.solve(
            root: pose.rightHip,
            target: pose.rightFoot,
            length1: SkeletonPose.thighLength,
            length2: SkeletonPose.calfLength,
            bendPositive: true
        )
        pose.rightKnee = rightLegIK.joint
    }
    
    private func solveLegsTucked(pose: inout SkeletonPose) {
        pose.leftHip = CGPoint(x: pose.root.x - 4.5, y: pose.root.y + 2.0)
        pose.rightHip = CGPoint(x: pose.root.x + 4.5, y: pose.root.y + 2.0)
        pose.leftFoot = CGPoint(x: pose.root.x - 4.0, y: pose.root.y + 10.0)
        pose.rightFoot = CGPoint(x: pose.root.x + 4.0, y: pose.root.y + 10.0)
        pose.leftKnee = CGPoint(x: pose.root.x - 8.0, y: pose.root.y + 6.0)
        pose.rightKnee = CGPoint(x: pose.root.x + 8.0, y: pose.root.y + 6.0)
    }
}
