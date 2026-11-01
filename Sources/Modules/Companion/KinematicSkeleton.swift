import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Mathematical Vector Helpers
public extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = other.x - self.x
        let dy = other.y - self.y
        return sqrt(dx * dx + dy * dy)
    }
    
    func lerp(to target: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: self.x + (target.x - self.x) * t,
            y: self.y + (target.y - self.y) * t
        )
    }
}

// MARK: - Mouth Shapes
public enum MouthShape: String, Equatable {
    case neutral
    case smile
    case gasp
    case sigh
    case openW
}

// MARK: - Two-Bone Analytical Inverse Kinematics Solver
public struct TwoBoneIK {
    public struct Result {
        public let root: CGPoint
        public let joint: CGPoint
        public let end: CGPoint
        public let isReachable: Bool
    }
    
    /// Solves the joint position for a two-bone system with lengths L1 and L2.
    /// bendDirection: +1 or -1 determines the side the joint (elbow/knee) flexes toward.
    public static func solve(
        root: CGPoint,
        target: CGPoint,
        length1: CGFloat,
        length2: CGFloat,
        bendPositive: Bool
    ) -> Result {
        let dx = target.x - root.x
        let dy = target.y - root.y
        let dist = sqrt(dx * dx + dy * dy)
        
        let maxReach = length1 + length2 - 0.0001
        let minReach = max(0.0001, abs(length1 - length2) + 0.0001)
        let reachable = dist <= maxReach && dist >= minReach
        let d = min(maxReach, max(minReach, dist))
        
        // Base direction from root to target
        let alpha = atan2(dy, dx)
        
        // Law of Cosines for angle at root (beta)
        let cosBeta = (length1 * length1 + d * d - length2 * length2) / (2.0 * length1 * d)
        let clampedCosBeta = min(1.0, max(-1.0, cosBeta))
        let beta = acos(clampedCosBeta)
        
        // Compute joint angle
        let sign: Double = bendPositive ? 1.0 : -1.0
        let jointAngle = alpha + sign * beta
        
        let jointX = root.x + length1 * CGFloat(cos(jointAngle))
        let jointY = root.y + length1 * CGFloat(sin(jointAngle))
        let joint = CGPoint(x: jointX, y: jointY)
        
        // End effector: if unreachable, clamp to maximum reach along target vector
        let endPoint: CGPoint
        if dist > maxReach {
            endPoint = CGPoint(
                x: root.x + CGFloat(cos(alpha)) * maxReach,
                y: root.y + CGFloat(sin(alpha)) * maxReach
            )
        } else {
            endPoint = target
        }
        
        return Result(
            root: root,
            joint: joint,
            end: endPoint,
            isReachable: reachable
        )
    }
}

// MARK: - Spring Damper Secondary Physics
public struct SpringDamper {
    public var position: Double = 0.0
    public var velocity: Double = 0.0
    public var target: Double = 0.0
    
    public var stiffness: Double = 220.0
    public var damping: Double = 18.0
    
    public init(position: Double = 0.0, stiffness: Double = 220.0, damping: Double = 18.0) {
        self.position = position
        self.target = position
        self.stiffness = stiffness
        self.damping = damping
    }
    
    public mutating func update(dt: Double) {
        let clampedDt = min(0.05, max(0.001, dt))
        let force = -stiffness * (position - target) - damping * velocity
        velocity += force * clampedDt
        position += velocity * clampedDt
    }
}

// MARK: - Torso Anchors & Geometry
public struct TorsoBones: Equatable {
    public var root: CGPoint = .zero            // Hips center
    public var spineAngle: Double = -.pi / 2.0  // Points upward by default
    public var spineLength: CGFloat = 16.0
    public var shoulderWidth: CGFloat = 14.0
    public var hipWidth: CGFloat = 12.0
    
    // Computed Anchors on Torso Hull
    public var neck: CGPoint {
        CGPoint(
            x: root.x + cos(spineAngle) * spineLength,
            y: root.y + sin(spineAngle) * spineLength
        )
    }
    
    // Normal vector perpendicular to spine
    private var normalVector: CGPoint {
        CGPoint(x: sin(spineAngle), y: -cos(spineAngle))
    }
    
    public var leftShoulderAnchor: CGPoint {
        let n = normalVector
        return CGPoint(
            x: neck.x + n.x * (shoulderWidth / 2.0),
            y: neck.y + n.y * (shoulderWidth / 2.0)
        )
    }
    
    public var rightShoulderAnchor: CGPoint {
        let n = normalVector
        return CGPoint(
            x: neck.x - n.x * (shoulderWidth / 2.0),
            y: neck.y - n.y * (shoulderWidth / 2.0)
        )
    }
    
    public var leftHipAnchor: CGPoint {
        let n = normalVector
        return CGPoint(
            x: root.x + n.x * (hipWidth / 2.0),
            y: root.y + n.y * (hipWidth / 2.0)
        )
    }
    
    public var rightHipAnchor: CGPoint {
        let n = normalVector
        return CGPoint(
            x: root.x - n.x * (hipWidth / 2.0),
            y: root.y - n.y * (hipWidth / 2.0)
        )
    }
}

// MARK: - Limb Bone Systems
public struct LimbBones: Equatable {
    public var anchor: CGPoint = .zero  // Strictly attached to torso anchor
    public var joint: CGPoint = .zero   // Elbow or knee
    public var end: CGPoint = .zero     // Hand or foot
    public var length1: CGFloat = 8.0
    public var length2: CGFloat = 8.0
    public var isPlantedOrGripping: Bool = false
    
    public init(length1: CGFloat = 8.0, length2: CGFloat = 8.0) {
        self.length1 = length1
        self.length2 = length2
    }
    
    public mutating func solveIK(from anchor: CGPoint, toward target: CGPoint, bendPositive: Bool) {
        self.anchor = anchor
        let result = TwoBoneIK.solve(
            root: anchor,
            target: target,
            length1: length1,
            length2: length2,
            bendPositive: bendPositive
        )
        self.joint = result.joint
        self.end = result.end
    }
}

// MARK: - Unified Single-Clock Kinematic Skeleton Pose
public struct SkeletonPose: Equatable {
    // Single shared frame timestamp
    public var timestamp: Double = 0.0
    
    // Core Rig
    public var torso: TorsoBones = TorsoBones()
    public var headCenter: CGPoint = .zero
    public var headAngle: Double = 0.0
    public var headRadius: CGFloat = 10.0
    
    // Four Limbs attached strictly to Torso Anchors
    public var leftArm: LimbBones = LimbBones(length1: 8.0, length2: 8.0)
    public var rightArm: LimbBones = LimbBones(length1: 8.0, length2: 8.0)
    public var leftLeg: LimbBones = LimbBones(length1: 8.5, length2: 8.5)
    public var rightLeg: LimbBones = LimbBones(length1: 8.5, length2: 8.5)
    
    // Tail (Physics Chain)
    public var tailSegments: [CGPoint] = [
        CGPoint(x: -8, y: 0),
        CGPoint(x: -14, y: -2),
        CGPoint(x: -20, y: -5),
        CGPoint(x: -24, y: -9)
    ]
    
    // Facial Features
    public var pupilOffset: CGPoint = .zero
    public var leftEyeOpen: CGFloat = 1.0
    public var rightEyeOpen: CGFloat = 1.0
    public var mouthShape: MouthShape = .neutral
    public var facingRight: Bool = true
    
    // Debug Skeleton Overlay Toggle
    public var debugSkeleton: Bool = false
    public var drawsTorso: Bool = true
    public var drawsHead: Bool = true
    public var drawsArms: Bool = true
    public var drawsLegs: Bool = true
    
    // Convenience accessors for backwards compatibility & tests
    public var root: CGPoint {
        get { torso.root }
        set { torso.root = newValue }
    }
    public var chest: CGPoint {
        torso.neck
    }
    public var head: CGPoint {
        get { headCenter }
        set { headCenter = newValue }
    }
    public var leftShoulder: CGPoint { leftArm.anchor }
    public var leftElbow: CGPoint { leftArm.joint }
    public var leftHand: CGPoint { leftArm.end }
    public var leftHandPlanted: Bool { leftArm.isPlantedOrGripping }
    
    public var rightShoulder: CGPoint { rightArm.anchor }
    public var rightElbow: CGPoint { rightArm.joint }
    public var rightHand: CGPoint { rightArm.end }
    public var rightHandPlanted: Bool { rightArm.isPlantedOrGripping }
    
    public var leftHip: CGPoint { leftLeg.anchor }
    public var leftKnee: CGPoint { leftLeg.joint }
    public var leftFoot: CGPoint { leftLeg.end }
    public var leftFootPlanted: Bool { leftLeg.isPlantedOrGripping }
    
    public var rightHip: CGPoint { rightLeg.anchor }
    public var rightKnee: CGPoint { rightLeg.joint }
    public var rightFoot: CGPoint { rightLeg.end }
    public var rightFootPlanted: Bool { rightLeg.isPlantedOrGripping }
    
    public init() {}
}
