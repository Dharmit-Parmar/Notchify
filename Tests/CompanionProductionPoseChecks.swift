import AppKit
import SwiftUI

@main
struct CompanionProductionPoseChecks {
    @MainActor
    static func main() {
        let engine = KinematicEngine.shared
        let dt = 1.0 / 60.0
        let sampledBehaviors: [CompanionBehaviorState] = [
            .peekingLeft, .peekingRight, .walking, .dangling, .slipping,
            .pullingUp, .thinking, .curious, .sleeping, .typingMimic,
            .musicGroove, .celebrating, .crawling
        ]
        var maxBoneError: CGFloat = 0
        var maxAnchorError: CGFloat = 0
        let uprightTorso = TorsoBones()
        assert(uprightTorso.leftShoulderAnchor.x < uprightTorso.rightShoulderAnchor.x)
        assert(uprightTorso.leftHipAnchor.x < uprightTorso.rightHipAnchor.x)
        for behavior in sampledBehaviors {
            engine.setBehavior(behavior)
            for _ in 0..<120 {
                engine.update(deltaTime: dt, cursorScreenPos: .zero)
                let pose = engine.currentPose
                if pose.drawsArms || pose.drawsLegs {
                    let spineError = abs(pose.torso.root.distance(to: pose.torso.neck) - pose.torso.spineLength)
                    maxBoneError = max(maxBoneError, spineError)
                    if pose.drawsArms {
                        maxBoneError = max(maxBoneError, max(Self.boneError(pose.leftArm), Self.boneError(pose.rightArm)))
                        maxAnchorError = max(maxAnchorError, max(pose.leftArm.anchor.distance(to: pose.torso.leftShoulderAnchor), pose.rightArm.anchor.distance(to: pose.torso.rightShoulderAnchor)))
                    }
                    if pose.drawsLegs {
                        maxBoneError = max(maxBoneError, max(Self.boneError(pose.leftLeg), Self.boneError(pose.rightLeg)))
                        maxAnchorError = max(maxAnchorError, max(pose.leftLeg.anchor.distance(to: pose.torso.leftHipAnchor), pose.rightLeg.anchor.distance(to: pose.torso.rightHipAnchor)))
                    }
                }
                let bodyOverlapsNotch = pose.root.x + 12 > engine.notchLeft && pose.root.x - 12 < engine.notchRight
                let bodyTopY = abs(pose.torso.spineAngle) < 0.2 ? (pose.root.y - 11.0) : (pose.root.y - 24.0)
                if pose.drawsTorso && bodyOverlapsNotch { assert(bodyTopY >= engine.ledgeY, "Body overlaps the notch in \(behavior)") }
                let headOverlapsNotch = pose.headCenter.x + 16 > engine.notchLeft && pose.headCenter.x - 16 < engine.notchRight
                if pose.drawsHead && headOverlapsNotch && behavior != .pullingUp { assert(pose.headCenter.y - 11 >= engine.ledgeY, "Face overlaps the notch in \(behavior)") }
            }
        }
        assert(maxBoneError < 0.5, "Production bone-length error: \(maxBoneError) pt")
        assert(maxAnchorError < 0.5, "Production anchor error: \(maxAnchorError) pt")

        engine.setBehavior(.walking)
        engine.update(deltaTime: dt, cursorScreenPos: .zero)
        assert(engine.currentPose.headCenter.y - engine.currentPose.headRadius >= 0)
        assert(engine.currentPose.root.y > engine.ledgeY)

        engine.setBehavior(.peekingLeft)
        for _ in 0..<54 { engine.update(deltaTime: dt, cursorScreenPos: .zero) }
        let hands = engine.currentPose
        assert(hands.drawsArms && !hands.drawsHead && !hands.drawsTorso && !hands.drawsLegs)
        assert(hands.leftHand.y >= engine.ledgeY - 1 && hands.rightHand.y >= engine.ledgeY - 1)

        var oneEyeFrame: Int?
        var fullFaceFrame: Int?
        var oneEyeHasConnectedTorso = false
        for frame in 0..<300 {
            engine.update(deltaTime: dt, cursorScreenPos: .zero)
            let pose = engine.currentPose
            if pose.drawsHead && !pose.drawsLegs && (pose.leftEyeOpen > 0) != (pose.rightEyeOpen > 0) && oneEyeFrame == nil {
                oneEyeFrame = frame
                oneEyeHasConnectedTorso = pose.drawsTorso && abs(pose.headCenter.y - pose.torso.neck.y) < 12
            }
            if engine.behaviorTime >= 4.2 && pose.drawsHead && pose.leftEyeOpen > 0 && pose.rightEyeOpen > 0 && fullFaceFrame == nil {
                fullFaceFrame = frame
            }
        }
        assert(oneEyeFrame != nil && fullFaceFrame != nil && oneEyeFrame! < fullFaceFrame!, "Peek sequence order failed: one-eye frame \(String(describing: oneEyeFrame)), full-face frame \(String(describing: fullFaceFrame))")
        assert(oneEyeHasConnectedTorso, "The single-eye peek is detached from the torso")
        assert(engine.currentPose.drawsTorso, "The full-face peek should show a connected upper body")

        engine.setBehavior(.dangling)
        var maxLeftGripError: CGFloat = 0
        var maxRightGripError: CGFloat = 0
        var maxKickStep: CGFloat = 0
        var previousFoot: CGPoint?
        var maxHangSway: CGFloat = 0
        var initialHangRoot: CGPoint?
        for _ in 0..<240 {
            engine.update(deltaTime: dt, cursorScreenPos: .zero)
            let pose = engine.currentPose
            if initialHangRoot == nil { initialHangRoot = pose.root }
            if let initialHangRoot { maxHangSway = max(maxHangSway, pose.root.distance(to: initialHangRoot)) }
            if let previousFoot { maxKickStep = max(maxKickStep, pose.leftFoot.distance(to: previousFoot)) }
            previousFoot = pose.leftFoot
            maxLeftGripError = max(maxLeftGripError, pose.leftHand.distance(to: CGPoint(x: engine.handLWorldX, y: engine.ledgeY + 3)))
            maxRightGripError = max(maxRightGripError, pose.rightHand.distance(to: CGPoint(x: engine.handRWorldX, y: engine.ledgeY + 3)))
            assert(pose.root.y - 24 >= engine.ledgeY)
            assert(pose.headCenter.y - pose.headRadius >= engine.ledgeY)
            assert(pose.root.y - pose.leftHand.y > 45, "Body is too close to the gripping hands")
            assert(pose.headCenter.y + 11 <= pose.root.y - 22, "Head and torso are compressed together")
        }
        assert(maxLeftGripError < 0.5 && maxRightGripError < 0.5, "Direct hang grip error: \(maxLeftGripError), \(maxRightGripError)")
        assert(maxKickStep > 0.5, "Hanging legs do not visibly kick")
        assert(maxHangSway > 1.0, "Hanging body does not visibly swing")

        let hangStartY = engine.currentPose.root.y
        engine.setBehavior(.pullingUp)
        var pullUpGripError: CGFloat = 0
        var pullUpLowestY = hangStartY
        for _ in 0..<150 {
            engine.update(deltaTime: dt, cursorScreenPos: .zero)
            let pose = engine.currentPose
            pullUpLowestY = min(pullUpLowestY, pose.root.y)
            pullUpGripError = max(pullUpGripError, pose.leftHand.distance(to: CGPoint(x: engine.handLWorldX, y: engine.ledgeY + 3)))
            pullUpGripError = max(pullUpGripError, pose.rightHand.distance(to: CGPoint(x: engine.handRWorldX, y: engine.ledgeY + 3)))
            let headOverlapsNotch = pose.headCenter.x + 16 > engine.notchLeft && pose.headCenter.x - 16 < engine.notchRight
            if headOverlapsNotch { assert(pose.headCenter.y + 11 >= engine.ledgeY - 12) }
            for hand in [pose.leftHand, pose.rightHand] where hand.x + 3 > engine.notchLeft && hand.x - 3 < engine.notchRight {
                assert(hand.y - 3 >= engine.ledgeY, "A paw is clipped by the notch lip")
            }
        }
        assert(hangStartY - pullUpLowestY > 30, "Pull-up did not raise the body")
        assert(pullUpGripError < 0.5, "Pull-up grip error: \(pullUpGripError)")
        assert(engine.currentPose.root.y <= engine.ledgeY + 32.5, "Pull-up did not raise the body to a visible, connected pose")
        assert(engine.currentPose.headCenter.y < engine.currentPose.torso.neck.y, "Pull-up head dropped below the neck")

        engine.setBehavior(.walking, startingFromRight: true)
        engine.update(deltaTime: dt, cursorScreenPos: .zero)
        let rightStartPose = engine.currentPose
        assert(rightStartPose.root.x > engine.screenWidth / 2, "Right-start route spawned on the left")
        assert(rightStartPose.headCenter.x + 16 <= engine.screenWidth && rightStartPose.headCenter.x - 16 >= 0, "Right-start face is clipped by the screen edge")
        let rightRouteCount = engine.completedRouteCount
        var rightRouteStayedClear = true
        var rightRouteMaxBoneError: CGFloat = 0
        for _ in 0..<12000 {
            engine.update(deltaTime: dt, cursorScreenPos: .zero)
            let pose = engine.currentPose
            if pose.drawsArms { rightRouteMaxBoneError = max(rightRouteMaxBoneError, max(Self.boneError(pose.leftArm), Self.boneError(pose.rightArm))) }
            if pose.drawsLegs { rightRouteMaxBoneError = max(rightRouteMaxBoneError, max(Self.boneError(pose.leftLeg), Self.boneError(pose.rightLeg))) }
            if pose.drawsArms {
                assert(pose.leftArm.anchor.distance(to: pose.torso.leftShoulderAnchor) < 0.5)
                assert(pose.rightArm.anchor.distance(to: pose.torso.rightShoulderAnchor) < 0.5)
            }
            let bodyOverlapsNotch = pose.root.x + 12 > engine.notchLeft && pose.root.x - 12 < engine.notchRight
            let faceOverlapsNotch = pose.headCenter.x + 16 > engine.notchLeft && pose.headCenter.x - 16 < engine.notchRight
            if (bodyOverlapsNotch && pose.root.y - 24 < engine.ledgeY) || (faceOverlapsNotch && engine.routeStage != .monkeyBarTraversal && pose.headCenter.y - 11 < engine.ledgeY) {
                rightRouteStayedClear = false
            }
        }
        assert(engine.completedRouteCount > rightRouteCount && rightRouteStayedClear && rightRouteMaxBoneError < 0.5, "Right-start route failed to complete safely or preserve its mirrored rig")

        engine.setBehavior(.walking)
        for _ in 0..<5000 {
            engine.update(deltaTime: dt, cursorScreenPos: .zero)
            if engine.rootWorldX > engine.notchLeft - 42 && engine.rootWorldX < engine.notchLeft { break }
        }
        assert(engine.rootWorldX > engine.notchLeft - 42 && engine.rootWorldX < engine.notchLeft, "Could not place the crawl start beside the notch")
        engine.setBehavior(.crawling)
        let nearNotchCrawlStartX = engine.currentPose.root.x
        for _ in 0..<30 { engine.update(deltaTime: dt, cursorScreenPos: .zero) }
        assert(abs(engine.currentPose.root.x - nearNotchCrawlStartX) > 5, "Crawl stride collapsed to zero at the notch boundary: \(nearNotchCrawlStartX) -> \(engine.currentPose.root.x)")

        engine.setBehavior(.crawling)
        var maxCrawlContactSlip: CGFloat = 0
        var previousCrawlPose: SkeletonPose?
        let crawlStartX = engine.currentPose.root.x
        var maxCrawlRootTravel: CGFloat = 0
        for _ in 0..<600 {
            engine.update(deltaTime: dt, cursorScreenPos: .zero)
            let pose = engine.currentPose
            maxCrawlRootTravel = max(maxCrawlRootTravel, abs(pose.root.x - crawlStartX))
            if let previousCrawlPose {
                if previousCrawlPose.leftArm.isPlantedOrGripping && pose.leftArm.isPlantedOrGripping {
                    maxCrawlContactSlip = max(maxCrawlContactSlip, previousCrawlPose.leftHand.distance(to: pose.leftHand))
                }
                if previousCrawlPose.rightArm.isPlantedOrGripping && pose.rightArm.isPlantedOrGripping {
                    maxCrawlContactSlip = max(maxCrawlContactSlip, previousCrawlPose.rightHand.distance(to: pose.rightHand))
                }
                if previousCrawlPose.leftLeg.isPlantedOrGripping && pose.leftLeg.isPlantedOrGripping {
                    maxCrawlContactSlip = max(maxCrawlContactSlip, previousCrawlPose.leftFoot.distance(to: pose.leftFoot))
                }
                if previousCrawlPose.rightLeg.isPlantedOrGripping && pose.rightLeg.isPlantedOrGripping {
                    maxCrawlContactSlip = max(maxCrawlContactSlip, previousCrawlPose.rightFoot.distance(to: pose.rightFoot))
                }
            }
            assert(pose.leftArm.isPlantedOrGripping != pose.rightArm.isPlantedOrGripping)
            assert(pose.leftLeg.isPlantedOrGripping != pose.rightLeg.isPlantedOrGripping)
            let crawlHeadOverlapsNotch = pose.headCenter.x + 16 > engine.notchLeft && pose.headCenter.x - 16 < engine.notchRight
            if crawlHeadOverlapsNotch { assert(pose.headCenter.y - 11 >= engine.ledgeY) }
            previousCrawlPose = pose
        }
        assert(maxCrawlContactSlip < 0.5, "Crawl contact slip: \(maxCrawlContactSlip) pt")
        assert(maxCrawlRootTravel > 100, "Crawling failed to travel along the screen")

        let completedRoutesAtStart = engine.completedRouteCount
        engine.setBehavior(.walking)
        var visitedStages = Set<ScreenRouteStage>()
        var maxRouteGripError: CGFloat = 0
        var maxRouteGripStage = ScreenRouteStage.leftWalk
        var maxPlantedFootSlip: CGFloat = 0
        var previousLeftFoot: CGPoint?
        var previousRightFoot: CGPoint?
        var previousLeftPlanted = false
        var previousRightPlanted = false
        var previousWalkStage: ScreenRouteStage?
        var maxRootStep: CGFloat = 0
        var previousRoot: CGPoint?
        var pivotFirstRightFoot: CGPoint?
        var pivotLastRightFoot: CGPoint?
        var pivotLeftFoot: CGPoint?
        for _ in 0..<12000 {
            engine.update(deltaTime: dt, cursorScreenPos: .zero)
            visitedStages.insert(engine.routeStage)
            let pose = engine.currentPose
            if engine.routeStage == .farCornerPeek && pose.timestamp >= 0.85 {
                if pivotFirstRightFoot == nil { pivotFirstRightFoot = pose.rightFoot; pivotLeftFoot = pose.leftFoot }
                pivotLastRightFoot = pose.rightFoot
                assert(pivotLeftFoot!.distance(to: pose.leftFoot) < 0.5, "Pivot stance foot moved")
            }
            if engine.routeStage == .leftWalk {
                if previousWalkStage == engine.routeStage {
                    if previousLeftPlanted && pose.leftLeg.isPlantedOrGripping, let previousLeftFoot {
                        maxPlantedFootSlip = max(maxPlantedFootSlip, pose.leftFoot.distance(to: previousLeftFoot))
                    }
                    if previousRightPlanted && pose.rightLeg.isPlantedOrGripping, let previousRightFoot {
                        maxPlantedFootSlip = max(maxPlantedFootSlip, pose.rightFoot.distance(to: previousRightFoot))
                    }
                }
                previousLeftFoot = pose.leftFoot
                previousRightFoot = pose.rightFoot
                previousLeftPlanted = pose.leftLeg.isPlantedOrGripping
                previousRightPlanted = pose.rightLeg.isPlantedOrGripping
                previousWalkStage = engine.routeStage
            } else {
                previousWalkStage = nil
            }
            if let previousRoot {
                maxRootStep = max(maxRootStep, pose.root.distance(to: previousRoot))
            }
            previousRoot = pose.root
            if pose.leftArm.isPlantedOrGripping {
                let error = pose.leftHand.distance(to: CGPoint(x: engine.handLWorldX, y: engine.ledgeY + 3))
                if error > maxRouteGripError { maxRouteGripError = error; maxRouteGripStage = engine.routeStage }
            }
            if pose.rightArm.isPlantedOrGripping {
                let error = pose.rightHand.distance(to: CGPoint(x: engine.handRWorldX, y: engine.ledgeY + 3))
                if error > maxRouteGripError { maxRouteGripError = error; maxRouteGripStage = engine.routeStage }
            }
            let torsoOverlapsNotch = pose.root.x + 12 > engine.notchLeft && pose.root.x - 12 < engine.notchRight
            if torsoOverlapsNotch { assert(pose.root.y - 24 >= engine.ledgeY) }
            let headOverlapsNotch = pose.headCenter.x + 16 > engine.notchLeft && pose.headCenter.x - 16 < engine.notchRight
            if headOverlapsNotch && engine.routeStage != .monkeyBarTraversal { assert(pose.headCenter.y - 11 >= engine.ledgeY) }
        }
        assert(maxRouteGripError < 0.5, "Grip error \(maxRouteGripError) pt in \(maxRouteGripStage)")
        assert(maxRootStep < 2.0)
        assert(maxPlantedFootSlip < 0.5, "Production planted foot slip: \(maxPlantedFootSlip) pt")
        assert(engine.completedRouteCount > completedRoutesAtStart, "The full-screen route did not complete before the action ended")
        assert(pivotFirstRightFoot != nil && pivotLastRightFoot!.distance(to: pivotFirstRightFoot!) > 5, "Far-corner pivot did not swing the free foot")
        assert([.leftWalk, .farCornerPeek].allSatisfy(visitedStages.contains), "Continuous route did not visit walk and far corner turn stages")

        // Dangling and Slip Grip Pinning Verification
        engine.setBehavior(.dangling)
        for _ in 0..<60 {
            engine.update(deltaTime: dt, cursorScreenPos: .zero)
            let hangPose = engine.currentPose
            assert(hangPose.leftHand.distance(to: CGPoint(x: engine.handLWorldX, y: engine.ledgeY + 3)) < 0.5, "Dangling left hand not pinned to lip")
            assert(hangPose.rightHand.distance(to: CGPoint(x: engine.handRWorldX, y: engine.ledgeY + 3)) < 0.5, "Dangling right hand not pinned to lip")
        }
        let beforeSlipRoot = engine.currentPose.root
        let beforeSlipLeftGrip = engine.handLWorldX
        let beforeSlipRightGrip = engine.handRWorldX
        engine.setBehavior(.slipping)
        assert(engine.handLWorldX == beforeSlipLeftGrip && engine.handRWorldX == beforeSlipRightGrip)
        engine.update(deltaTime: dt, cursorScreenPos: .zero)
        let slipPose = engine.currentPose
        assert(slipPose.root.distance(to: beforeSlipRoot) < 16.0, "Slip recovery teleported the body away from its grips")
        assert(slipPose.leftHand.distance(to: CGPoint(x: beforeSlipLeftGrip, y: engine.ledgeY + 3)) < 0.5)
        assert(slipPose.rightHand.distance(to: CGPoint(x: beforeSlipRightGrip, y: engine.ledgeY + 3)) < 0.5)

        let rightRouteStartCount = engine.completedRouteCount
        engine.setBehavior(.walking, startingFromRight: true)
        engine.update(deltaTime: dt, cursorScreenPos: .zero)
        assert(engine.currentPose.root.x > engine.screenWidth / 2, "Right route did not begin on the right side")
        var rightRouteMinX = engine.currentPose.root.x
        var rightRouteMaxX = engine.currentPose.root.x
        var rightRouteMaxStep: CGFloat = 0
        var rightRoutePreviousRoot = engine.currentPose.root
        var rightRouteMaxGripSlip: CGFloat = 0
        var previousGripStage: ScreenRouteStage?
        var previousLeftGrip: CGPoint?
        var previousRightGrip: CGPoint?
        var previousLeftGripPlanted = false
        var previousRightGripPlanted = false
        for _ in 0..<12000 where engine.completedRouteCount == rightRouteStartCount {
            engine.update(deltaTime: dt, cursorScreenPos: .zero)
            let pose = engine.currentPose
            rightRouteMinX = min(rightRouteMinX, pose.root.x)
            rightRouteMaxX = max(rightRouteMaxX, pose.root.x)
            rightRouteMaxStep = max(rightRouteMaxStep, pose.root.distance(to: rightRoutePreviousRoot))
            rightRoutePreviousRoot = pose.root

            if previousGripStage == engine.routeStage {
                if previousLeftGripPlanted && pose.leftArm.isPlantedOrGripping, let previousLeftGrip {
                    rightRouteMaxGripSlip = max(rightRouteMaxGripSlip, pose.leftHand.distance(to: previousLeftGrip))
                }
                if previousRightGripPlanted && pose.rightArm.isPlantedOrGripping, let previousRightGrip {
                    rightRouteMaxGripSlip = max(rightRouteMaxGripSlip, pose.rightHand.distance(to: previousRightGrip))
                }
            }
            previousGripStage = engine.routeStage
            previousLeftGrip = pose.leftHand
            previousRightGrip = pose.rightHand
            previousLeftGripPlanted = pose.leftArm.isPlantedOrGripping
            previousRightGripPlanted = pose.rightArm.isPlantedOrGripping

            if pose.drawsHead {
                assert(pose.headCenter.x >= 16 && pose.headCenter.x <= engine.screenWidth - 16, "Right route clipped the face horizontally")
                assert(pose.headCenter.y >= 17 && pose.headCenter.y + 11 <= 160, "Right route clipped the face vertically")
            }

            let torsoOverlapsNotch = pose.root.x + 12 > engine.notchLeft && pose.root.x - 12 < engine.notchRight
            if torsoOverlapsNotch { assert(pose.root.y - 24 >= engine.ledgeY, "Right route hid the torso behind the notch") }
            let headOverlapsNotch = pose.headCenter.x + 16 > engine.notchLeft && pose.headCenter.x - 16 < engine.notchRight
            if headOverlapsNotch && engine.routeStage != .monkeyBarTraversal { assert(pose.headCenter.y - 11 >= engine.ledgeY, "Right route hid the face behind the notch") }
        }
        assert(engine.completedRouteCount > rightRouteStartCount, "Right route did not complete")
        assert(rightRouteMaxX > engine.screenWidth - 50 && rightRouteMinX < engine.notchLeft, "Right route did not traverse the full screen")
        assert(rightRouteMaxStep < 2.0, "Right route has a sliding or teleporting step: \(rightRouteMaxStep) pt")
        assert(rightRouteMaxGripSlip < 0.5, "Right route grip slipped: \(rightRouteMaxGripSlip) pt")
        print("Production pose checks passed; bone error:", maxBoneError, "pt; anchor error:", maxAnchorError, "pt; walk foot slip:", maxPlantedFootSlip, "pt; crawl contact slip:", maxCrawlContactSlip, "pt; grip slip:", max(maxLeftGripError, max(maxRightGripError, maxRouteGripError, rightRouteMaxGripSlip)), "pt; route root steps:", maxRootStep, rightRouteMaxStep, "pt")
    }

    private static func boneError(_ limb: LimbBones) -> CGFloat {
        max(abs(limb.anchor.distance(to: limb.joint) - limb.length1), abs(limb.joint.distance(to: limb.end) - limb.length2))
    }
}
