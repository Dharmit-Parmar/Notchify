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
        return CGPoint(
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
        
        let maxReach = length1 + length2 - 0.001
        let minReach = max(0.001, abs(length1 - length2) + 0.001)
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

// MARK: - Complete Kinematic Skeleton Rig Pose
public struct SkeletonPose: Equatable {
    // Proportions
    public static let upperArmLength: CGFloat = 8.0
    public static let forearmLength: CGFloat = 8.0
    public static let thighLength: CGFloat = 8.5
    public static let calfLength: CGFloat = 8.5
    public static let torsoHeight: CGFloat = 16.0
    public static let headRadius: CGFloat = 10.0
    
    // Core Bones & Joint Transforms
    public var root: CGPoint = .zero            // Hips in notch coordinates
    public var pelvisAngle: Double = 0.0        // Pelvic tilt (degrees)
    public var chest: CGPoint = .zero           // Upper torso / shoulders
    public var chestAngle: Double = 0.0         // Torso curvature
    public var head: CGPoint = .zero            // Head center
    public var headAngle: Double = 0.0          // Head tilt
    
    // Left Arm (Back limb if facing right)
    public var leftShoulder: CGPoint = .zero
    public var leftElbow: CGPoint = .zero
    public var leftHand: CGPoint = .zero
    public var leftHandPlanted: Bool = false
    
    // Right Arm (Front limb if facing right)
    public var rightShoulder: CGPoint = .zero
    public var rightElbow: CGPoint = .zero
    public var rightHand: CGPoint = .zero
    public var rightHandPlanted: Bool = false
    
    // Left Leg (Back leg if facing right)
    public var leftHip: CGPoint = .zero
    public var leftKnee: CGPoint = .zero
    public var leftFoot: CGPoint = .zero
    public var leftFootPlanted: Bool = false
    
    // Right Leg (Front leg if facing right)
    public var rightHip: CGPoint = .zero
    public var rightKnee: CGPoint = .zero
    public var rightFoot: CGPoint = .zero
    public var rightFootPlanted: Bool = false
    
    // Tail (Physics chain of 4 segments)
    public var tailSegments: [CGPoint] = [
        CGPoint(x: -8, y: 0),
        CGPoint(x: -14, y: -2),
        CGPoint(x: -20, y: -5),
        CGPoint(x: -24, y: -9)
    ]
    
    // Facial Rig
    public var pupilOffset: CGPoint = .zero     // Normalized -1...1
    public var leftEyeOpen: CGFloat = 1.0       // 0 = closed, 1 = normal, 1.4 = wide
    public var rightEyeOpen: CGFloat = 1.0
    public var mouthOpen: CGFloat = 0.0
    public var mouthShape: MouthShape = .neutral
    
    // Secondary Motion Overlays
    public var facingRight: Bool = true
    public var breathScale: CGFloat = 1.0
    public var squashStretch: CGPoint = CGPoint(x: 1.0, y: 1.0)
    public var weightShift: Double = 0.0        // -1 (all weight on left) to +1 (on right)
    
    public init() {}
}
