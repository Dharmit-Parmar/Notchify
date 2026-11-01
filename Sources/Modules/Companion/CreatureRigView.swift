import SwiftUI
import AppKit

// MARK: - Adorable 2D Vector Cartoon Companion Renderer (Bubu & Friends)
public struct CreatureRigView: View {
    @ObservedObject var coordinator = CompanionCoordinator.shared
    @ObservedObject var store = SettingsStore.shared
    private var engine: KinematicEngine { KinematicEngine.shared }
    
    public init() {}
    
    private var skin: CompanionSkin {
        store.companionSkin
    }
    
    private var cartoonStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
    }
    
    public var body: some View {
        TimelineView(.animation(paused: coordinator.state == .inDen)) { timelineContext in
            Canvas { context, _ in
                // Zero CPU / early exit if in den
                guard coordinator.state != .inDen else { return }
                
                renderCompanion(
                    context: &context,
                    pose: engine.currentPose,
                    skin: skin,
                    debugSkeleton: store.companionDebugSkeleton || engine.currentPose.debugSkeleton
                )
            }
            .onChange(of: timelineContext.date) { previousDate, date in
                guard coordinator.state != .inDen else { return }
                let deltaTime = date.timeIntervalSince(previousDate)
                
                let screen = CompanionPanel.shared?.screen ?? NSScreen.main ?? NSScreen.screens[0]
                let cursorScreenPos: CGPoint
                if coordinator.state == .thinking || coordinator.state == .curious {
                    let mouseScreen = NSEvent.mouseLocation
                    cursorScreenPos = CGPoint(x: mouseScreen.x - screen.frame.origin.x, y: screen.frame.maxY - mouseScreen.y)
                } else {
                    cursorScreenPos = .zero
                }
                
                engine.update(
                    deltaTime: deltaTime,
                    cursorScreenPos: cursorScreenPos
                )
                coordinator.companionRouteDidAdvance()
                
                CompanionPanel.shared?.clickPanel?.updatePosition(pose: engine.currentPose, screen: screen)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
    
    // MARK: - Master Mascot Dispatcher
    private func renderCompanion(
        context: inout GraphicsContext,
        pose: SkeletonPose,
        skin: CompanionSkin,
        debugSkeleton: Bool
    ) {
        let state = coordinator.state
        let routeStage = engine.routeStage
        
        // 1. Specialized State Renderers
        if state == .sleeping {
            // Tummy Rest Pose matching Reference Image 1
            renderTummyRestPose(context: &context, pose: pose, skin: skin)
        } else if state == .peekingLeft || state == .peekingRight {
            // Lip Peek with chubby white paws gripping notch edge
            let side: CGFloat = (state == .peekingLeft) ? -1.0 : 1.0
            renderLipPeek(context: &context, pose: pose, skin: skin, side: side)
        } else if state == .dangling || state == .slipping || state == .pullingUp ||
                  ([.lowerToHang, .monkeyBarTraversal, .climbOntoRightLedge].contains(routeStage) && state == .walking) {
            // Notch Hang & Pull-Up with chubby limbs and dangling marshmallow body
            renderNotchHangAndPullUp(context: &context, pose: pose, skin: skin)
        } else if state == .walking && ([.leftWalk, .rightWalk].contains(routeStage)) {
            // Chubby Waddle Walk matching Reference Image 2
            renderChubbyWaddleWalk(context: &context, pose: pose, skin: skin)
        } else {
            // Front-facing chubby mascot (thinking, curious, typing, music groove, crawling, etc.)
            renderChubbyMascot(context: &context, pose: pose, skin: skin)
        }
        
        // 2. Extra Props
        if state == .typingMimic {
            drawMiniLaptop(context: &context, position: CGPoint(x: pose.torso.root.x, y: engine.ledgeY + 23))
        } else if state == .musicGroove {
            drawMiniHeadphones(context: &context, head: pose.headCenter, skin: skin)
        }
        
        // 3. Skeleton Rig Debug Overlay (if developer toggle is active)
        if debugSkeleton {
            drawDebugSkeletonOverlay(context: &context, pose: pose)
        }
    }
    
    // MARK: - 1. Tummy Resting Pose (Reference Image 1)
    private func renderTummyRestPose(
        context: inout GraphicsContext,
        pose: SkeletonPose,
        skin: CompanionSkin
    ) {
        let groundY = pose.torso.root.y
        let cx = pose.torso.root.x
        let dir: CGFloat = pose.facingRight ? 1.0 : -1.0
        let breath = sin(pose.timestamp * 2.8) * 0.8
        
        let bodyColor = skin.primaryColor
        let outlineColor = skin.outlineColor
        let earColor = skin.darkAccentColor
        let soleColor = skin.darkAccentColor
        let blushColor = skin.accentColor
        
        // 1. Soft ground contact shadow
        let shadowRect = CGRect(x: cx - 38, y: groundY - 1, width: 76, height: 5.5)
        context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(0.18)))
        
        // 2. Rear Leg stretched back along the ground with dark foot sole (Reference 1)
        var legPath = Path()
        legPath.move(to: CGPoint(x: cx - 18 * dir, y: groundY - 5))
        legPath.addQuadCurve(to: CGPoint(x: cx - 30 * dir, y: groundY - 3), control: CGPoint(x: cx - 24 * dir, y: groundY - 8))
        legPath.addLine(to: CGPoint(x: cx - 30 * dir, y: groundY))
        legPath.addLine(to: CGPoint(x: cx - 18 * dir, y: groundY))
        legPath.closeSubpath()
        context.fill(legPath, with: .color(bodyColor))
        context.stroke(legPath, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Dark sole pad on back foot
        let rearSoleRect = CGRect(x: (dir > 0 ? cx - 34 : cx + 27), y: groundY - 6.5, width: 7.5, height: 6.5)
        context.fill(Path(ellipseIn: rearSoleRect), with: .color(soleColor))
        context.stroke(Path(ellipseIn: rearSoleRect), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 3. Tail: Cute circular white puff tail on the rump (Reference 1)
        let tailCenter = CGPoint(x: cx - 22 * dir, y: groundY - 18 - breath)
        let tailRect = CGRect(x: tailCenter.x - 4.5, y: tailCenter.y - 4.5, width: 9.0, height: 9.0)
        context.fill(Path(ellipseIn: tailRect), with: .color(bodyColor))
        context.stroke(Path(ellipseIn: tailRect), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 4. Chubby Body (Marshmallow stretching from rear to head)
        var bodyPath = Path()
        bodyPath.move(to: CGPoint(x: cx - 26 * dir, y: groundY))
        bodyPath.addCurve(
            to: CGPoint(x: cx + 2 * dir, y: groundY - 12 - breath),
            control1: CGPoint(x: cx - 24 * dir, y: groundY - 20 - breath),
            control2: CGPoint(x: cx - 8 * dir, y: groundY - 21 - breath)
        )
        bodyPath.addLine(to: CGPoint(x: cx + 8 * dir, y: groundY))
        bodyPath.addLine(to: CGPoint(x: cx - 26 * dir, y: groundY))
        bodyPath.closeSubpath()
        context.fill(bodyPath, with: .color(bodyColor))
        context.stroke(bodyPath, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 5. Front Paws (Reference 1)
        // Front paw 1: Resting under chin
        let frontPaw1Rect = CGRect(x: (dir > 0 ? cx + 2 : cx - 16), y: groundY - 7, width: 14, height: 7)
        let paw1Path = Path(roundedRect: frontPaw1Rect, cornerRadius: 3.5)
        context.fill(paw1Path, with: .color(bodyColor))
        context.stroke(paw1Path, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Front paw 2: Peeking out on right under right cheek
        let frontPaw2Rect = CGRect(x: (dir > 0 ? cx + 33 : cx - 40), y: groundY - 5, width: 7.5, height: 5.5)
        let paw2Path = Path(roundedRect: frontPaw2Rect, cornerRadius: 2.7)
        context.fill(paw2Path, with: .color(bodyColor))
        context.stroke(paw2Path, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 6. Giant Squishy Dumpling Head (Resting flat on ground, Reference 1)
        let headCenter = CGPoint(x: cx + 18 * dir, y: groundY - 12 - breath * 0.3)
        let headW: CGFloat = 38.0
        let headH: CGFloat = 26.0
        
        var headTransform = CGAffineTransform.identity
        headTransform = headTransform.translatedBy(x: headCenter.x, y: headCenter.y)
        if dir < 0 { headTransform = headTransform.scaledBy(x: -1.0, y: 1.0) }
        
        // Ears on top of head
        let earRadius: CGFloat = 5.2
        let earLRect = CGRect(x: -headW * 0.28 - earRadius, y: -headH * 0.5 - earRadius + 2.0, width: earRadius * 2, height: earRadius * 2)
        let earRRect = CGRect(x: headW * 0.30 - earRadius, y: -headH * 0.46 - earRadius + 2.0, width: earRadius * 2, height: earRadius * 2)
        context.fill(Path(ellipseIn: earLRect).applying(headTransform), with: .color(earColor))
        context.stroke(Path(ellipseIn: earLRect).applying(headTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        context.fill(Path(ellipseIn: earRRect).applying(headTransform), with: .color(earColor))
        context.stroke(Path(ellipseIn: earRRect).applying(headTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Dumpling head shape
        let headShape = dumplingHeadPath(width: headW, height: headH).applying(headTransform)
        context.fill(headShape, with: .color(bodyColor))
        context.stroke(headShape, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Giant circular rosy blush cheeks
        let blushRadius: CGFloat = 5.8
        let blushL = CGRect(x: -headW * 0.30 - blushRadius, y: headH * 0.12 - blushRadius, width: blushRadius * 2, height: blushRadius * 2)
        let blushR = CGRect(x: headW * 0.36 - blushRadius, y: headH * 0.12 - blushRadius, width: blushRadius * 2, height: blushRadius * 2)
        context.fill(Path(ellipseIn: blushL).applying(headTransform), with: .color(blushColor.opacity(0.85)))
        context.fill(Path(ellipseIn: blushR).applying(headTransform), with: .color(blushColor.opacity(0.85)))
        
        // Eyes: cute gentle sleep curves or solid dots
        let eyeY = headH * -0.04
        let eyeSpread = headW * 0.21
        let eyeColor = skin.eyeColor
        
        var eyePathL = Path()
        eyePathL.move(to: CGPoint(x: -eyeSpread - 3.0, y: eyeY + 1.0))
        eyePathL.addQuadCurve(to: CGPoint(x: -eyeSpread + 3.0, y: eyeY + 1.0), control: CGPoint(x: -eyeSpread, y: eyeY - 2.2))
        context.stroke(eyePathL.applying(headTransform), with: .color(eyeColor), lineWidth: 1.8)
        
        var eyePathR = Path()
        eyePathR.move(to: CGPoint(x: eyeSpread - 3.0, y: eyeY + 1.0))
        eyePathR.addQuadCurve(to: CGPoint(x: eyeSpread + 3.0, y: eyeY + 1.0), control: CGPoint(x: eyeSpread, y: eyeY - 2.2))
        context.stroke(eyePathR.applying(headTransform), with: .color(eyeColor), lineWidth: 1.8)
        
        // Eyebrows
        let browY = eyeY - 6.0
        var browL = Path()
        browL.move(to: CGPoint(x: -eyeSpread - 3.0, y: browY + 0.5))
        browL.addQuadCurve(to: CGPoint(x: -eyeSpread + 2.5, y: browY + 0.5), control: CGPoint(x: -eyeSpread - 0.2, y: browY - 1.8))
        context.stroke(browL.applying(headTransform), with: .color(eyeColor), lineWidth: 1.3)
        
        var browR = Path()
        browR.move(to: CGPoint(x: eyeSpread - 2.5, y: browY + 0.5))
        browR.addQuadCurve(to: CGPoint(x: eyeSpread + 3.0, y: browY + 0.5), control: CGPoint(x: eyeSpread + 0.2, y: browY - 1.8))
        context.stroke(browR.applying(headTransform), with: .color(eyeColor), lineWidth: 1.3)
        
        // Cute 'w' mouth
        let mouthY = eyeY + 5.0
        var mouth = Path()
        mouth.move(to: CGPoint(x: -2.8, y: mouthY))
        mouth.addQuadCurve(to: CGPoint(x: 0.0, y: mouthY + 1.2), control: CGPoint(x: -1.4, y: mouthY + 2.0))
        mouth.addQuadCurve(to: CGPoint(x: 2.8, y: mouthY), control: CGPoint(x: 1.4, y: mouthY + 2.0))
        context.stroke(mouth.applying(headTransform), with: .color(eyeColor), lineWidth: 1.4)
        
        // 7. Floating 'Zzz' Animation
        drawFloatingZzz(context: &context, origin: CGPoint(x: headCenter.x + 8 * dir, y: headCenter.y - 12), time: pose.timestamp)
    }
    
    // MARK: - 2. Chubby Waddle Walk (Reference Image 2)
    private func renderChubbyWaddleWalk(
        context: inout GraphicsContext,
        pose: SkeletonPose,
        skin: CompanionSkin
    ) {
        let u = KinematicEngine.shared.walkStepPhase
        let walkY = pose.torso.root.y + 11.0
        
        let bodyColor = skin.primaryColor
        let outlineColor = skin.outlineColor
        let earColor = skin.darkAccentColor
        let soleColor = skin.darkAccentColor
        let backBandColor = Color(red: 0.17, green: 0.12, blue: 0.13)
        let blushColor = skin.accentColor
        
        // Butt and Body Sway (Signature Bubu Waddle!)
        let sway = sin(u * 2.0 * .pi) * 3.6
        let tilt = sin(u * 2.0 * .pi) * 5.0 * (.pi / 180.0)
        let bounce = -abs(sin(u * 2.0 * .pi)) * 2.4
        
        let cx = pose.torso.root.x
        let cy = pose.torso.root.y + bounce
        
        // 1. Soft contact shadow on ground
        let shadowRect = CGRect(x: cx - 18, y: walkY - 2, width: 36, height: 5)
        context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(0.20)))
        
        var bodyTransform = CGAffineTransform.identity
        bodyTransform = bodyTransform.translatedBy(x: cx + sway, y: cy)
        bodyTransform = bodyTransform.rotated(by: tilt)
        
        // 2. Stubby Legs with Alternating Dark Soles (Reference Image 2)
        let isLeftPlanted = KinematicEngine.shared.isLeftFootPlanted
        let legW: CGFloat = 9.0
        let legH: CGFloat = 12.0
        
        // Left Leg
        let leftLegX: CGFloat = -8.0
        var leftLegPath = Path()
        if isLeftPlanted {
            let r = CGRect(x: leftLegX - legW / 2.0, y: 5.0, width: legW, height: legH)
            leftLegPath.addRoundedRect(in: r, cornerSize: CGSize(width: 4.5, height: 4.5))
            context.fill(leftLegPath.applying(bodyTransform), with: .color(bodyColor))
            context.stroke(leftLegPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
            let sole = CGRect(x: leftLegX - legW / 2.0, y: 5.0 + legH - 3.5, width: legW, height: 3.5)
            context.fill(Path(ellipseIn: sole).applying(bodyTransform), with: .color(soleColor))
        } else {
            let swingLift = -4.0 * sin(u * .pi)
            let r = CGRect(x: leftLegX - legW / 2.0, y: 1.0 + swingLift, width: legW, height: legH * 0.95)
            leftLegPath.addRoundedRect(in: r, cornerSize: CGSize(width: 4.5, height: 4.5))
            context.fill(leftLegPath.applying(bodyTransform), with: .color(bodyColor))
            context.stroke(leftLegPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
            let sole = CGRect(x: leftLegX - 4.5, y: 1.0 + swingLift + legH * 0.45, width: 9.0, height: 6.0)
            context.fill(Path(ellipseIn: sole).applying(bodyTransform), with: .color(soleColor))
            context.stroke(Path(ellipseIn: sole).applying(bodyTransform), with: .color(outlineColor), lineWidth: 1.2)
        }
        
        // Right Leg
        let rightLegX: CGFloat = 8.0
        var rightLegPath = Path()
        if !isLeftPlanted {
            let r = CGRect(x: rightLegX - legW / 2.0, y: 5.0, width: legW, height: legH)
            rightLegPath.addRoundedRect(in: r, cornerSize: CGSize(width: 4.5, height: 4.5))
            context.fill(rightLegPath.applying(bodyTransform), with: .color(bodyColor))
            context.stroke(rightLegPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
            let sole = CGRect(x: rightLegX - legW / 2.0, y: 5.0 + legH - 3.5, width: legW, height: 3.5)
            context.fill(Path(ellipseIn: sole).applying(bodyTransform), with: .color(soleColor))
        } else {
            let swingLift = -4.0 * sin(u * .pi)
            let r = CGRect(x: rightLegX - legW / 2.0, y: 1.0 + swingLift, width: legW, height: legH * 0.95)
            rightLegPath.addRoundedRect(in: r, cornerSize: CGSize(width: 4.5, height: 4.5))
            context.fill(rightLegPath.applying(bodyTransform), with: .color(bodyColor))
            context.stroke(rightLegPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
            let sole = CGRect(x: rightLegX - 4.5, y: 1.0 + swingLift + legH * 0.45, width: 9.0, height: 6.0)
            context.fill(Path(ellipseIn: sole).applying(bodyTransform), with: .color(soleColor))
            context.stroke(Path(ellipseIn: sole).applying(bodyTransform), with: .color(outlineColor), lineWidth: 1.2)
        }
        
        // 3. Stubby Arms dangling at sides
        let armSwing = sin(u * 2.0 * .pi) * 4.0
        let armLRect = CGRect(x: -18.5, y: -9.0 + armSwing, width: 7.5, height: 15.0)
        let armLPath = Path(roundedRect: armLRect, cornerRadius: 3.75)
        context.fill(armLPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(armLPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        let armRRect = CGRect(x: 11.0, y: -9.0 - armSwing, width: 7.5, height: 15.0)
        let armRPath = Path(roundedRect: armRRect, cornerRadius: 3.75)
        context.fill(armRPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(armRPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 4. Chubby Marshmallow Torso (Pear shape)
        var torsoPath = Path()
        let tw: CGFloat = 28.0
        let th: CGFloat = 25.0
        torsoPath.move(to: CGPoint(x: -tw * 0.38, y: -th * 0.5))
        torsoPath.addLine(to: CGPoint(x: tw * 0.38, y: -th * 0.5))
        torsoPath.addCurve(
            to: CGPoint(x: tw * 0.5, y: th * 0.45),
            control1: CGPoint(x: tw * 0.45, y: -th * 0.1),
            control2: CGPoint(x: tw * 0.54, y: th * 0.2)
        )
        torsoPath.addQuadCurve(
            to: CGPoint(x: -tw * 0.5, y: th * 0.45),
            control: CGPoint(x: 0, y: th * 0.52)
        )
        torsoPath.addCurve(
            to: CGPoint(x: -tw * 0.38, y: -th * 0.5),
            control1: CGPoint(x: -tw * 0.54, y: th * 0.2),
            control2: CGPoint(x: -tw * 0.45, y: -th * 0.1)
        )
        torsoPath.closeSubpath()
        context.fill(torsoPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(torsoPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 5. Tail: White circular puff tail on lower back/bum (Reference 2)
        let tailCenter = CGPoint(x: 0.0, y: th * 0.18)
        let tailRect = CGRect(x: tailCenter.x - 5.0, y: tailCenter.y - 5.0, width: 10.0, height: 10.0)
        context.fill(Path(ellipseIn: tailRect).applying(bodyTransform), with: .color(bodyColor))
        context.stroke(Path(ellipseIn: tailRect).applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 6. Black Collar Band (Key requirement from Reference Image 2!)
        var bandPath = Path()
        bandPath.move(to: CGPoint(x: -tw * 0.44, y: -th * 0.48))
        bandPath.addQuadCurve(to: CGPoint(x: tw * 0.44, y: -th * 0.48), control: CGPoint(x: 0, y: -th * 0.48 + 4.2))
        bandPath.addLine(to: CGPoint(x: tw * 0.42, y: -th * 0.48 + 4.2))
        bandPath.addQuadCurve(to: CGPoint(x: -tw * 0.42, y: -th * 0.48 + 4.2), control: CGPoint(x: 0, y: -th * 0.48 + 8.4))
        bandPath.closeSubpath()
        context.fill(bandPath.applying(bodyTransform), with: .color(backBandColor))
        context.stroke(bandPath.applying(bodyTransform), with: .color(outlineColor), lineWidth: 1.0)
        
        // 7. Head (Viewed from Behind)
        let headCenter = CGPoint(x: cx + sway * 0.6, y: cy - 22)
        var headTransform = CGAffineTransform.identity
        headTransform = headTransform.translatedBy(x: headCenter.x, y: headCenter.y)
        headTransform = headTransform.rotated(by: tilt * 0.6)
        
        let headW: CGFloat = 38.0
        let headH: CGFloat = 33.0
        
        // Ears on top of head
        let earRadius: CGFloat = 5.5
        let earLRect = CGRect(x: -headW * 0.32 - earRadius, y: -headH * 0.44 - earRadius, width: earRadius * 2, height: earRadius * 2)
        let earRRect = CGRect(x: headW * 0.32 - earRadius, y: -headH * 0.44 - earRadius, width: earRadius * 2, height: earRadius * 2)
        context.fill(Path(ellipseIn: earLRect).applying(headTransform), with: .color(earColor))
        context.stroke(Path(ellipseIn: earLRect).applying(headTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        context.fill(Path(ellipseIn: earRRect).applying(headTransform), with: .color(earColor))
        context.stroke(Path(ellipseIn: earRRect).applying(headTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Dumpling head shape
        let headShape = dumplingHeadPath(width: headW, height: headH).applying(headTransform)
        context.fill(headShape, with: .color(bodyColor))
        context.stroke(headShape, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Cheek blush peeking on left profile (Reference Image 2!)
        let cheekBlushRect = CGRect(x: -headW * 0.5 - 2.5, y: headH * 0.05, width: 6.0, height: 8.0)
        context.fill(Path(ellipseIn: cheekBlushRect).applying(headTransform), with: .color(blushColor.opacity(0.85)))
    }
    
    // MARK: - 3. Lip Peek (Left & Right Notch Curves)
    private func renderLipPeek(
        context: inout GraphicsContext,
        pose: SkeletonPose,
        skin: CompanionSkin,
        side: CGFloat
    ) {
        let cornerX = (side < 0) ? (engine.notchLeft - 14.0) : (engine.notchRight + 14.0)
        let gripY = engine.ledgeY
        let bodyColor = skin.primaryColor
        let outlineColor = skin.outlineColor
        let earColor = skin.darkAccentColor
        
        let p = min(1.0, max(0.0, CGFloat(engine.behaviorTime / 1.5)))
        let rise = p * p * (3.0 - 2.0 * p)
        let headY = gripY + 20.0 - (34.0 * rise)
        
        let headCenter = CGPoint(x: cornerX, y: headY)
        let headW: CGFloat = 36.0
        let headH: CGFloat = 30.0
        
        var headTransform = CGAffineTransform.identity
        headTransform = headTransform.translatedBy(x: headCenter.x, y: headCenter.y)
        
        // 1. Ears
        let earRadius: CGFloat = 5.2
        let earLRect = CGRect(x: -headW * 0.32 - earRadius, y: -headH * 0.44 - earRadius, width: earRadius * 2, height: earRadius * 2)
        let earRRect = CGRect(x: headW * 0.32 - earRadius, y: -headH * 0.44 - earRadius, width: earRadius * 2, height: earRadius * 2)
        context.fill(Path(ellipseIn: earLRect).applying(headTransform), with: .color(earColor))
        context.stroke(Path(ellipseIn: earLRect).applying(headTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        context.fill(Path(ellipseIn: earRRect).applying(headTransform), with: .color(earColor))
        context.stroke(Path(ellipseIn: earRRect).applying(headTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 2. Dumpling head shape
        let headShape = dumplingHeadPath(width: headW, height: headH).applying(headTransform)
        context.fill(headShape, with: .color(bodyColor))
        context.stroke(headShape, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 3. Face features (Wide eyes, blush, cute eyebrows)
        drawBubuFace(
            context: &context,
            transform: headTransform,
            pose: pose,
            skin: skin,
            headWidth: headW,
            headHeight: headH
        )
        
        // 4. Two Chubby White Paws Gripping Over Notch Lip (Spaced on either side of chin)
        let pawW: CGFloat = 9.0
        let pawH: CGFloat = 7.0
        let pawL = CGRect(x: cornerX - 14.0 - pawW / 2.0, y: gripY - 2.0, width: pawW, height: pawH)
        let pawR = CGRect(x: cornerX + 14.0 - pawW / 2.0, y: gripY - 2.0, width: pawW, height: pawH)
        
        let pawPathL = Path(roundedRect: pawL, cornerRadius: 3.0)
        let pawPathR = Path(roundedRect: pawR, cornerRadius: 3.0)
        
        context.fill(pawPathL, with: .color(bodyColor))
        context.stroke(pawPathL, with: .color(outlineColor), style: cartoonStrokeStyle)
        context.fill(pawPathR, with: .color(bodyColor))
        context.stroke(pawPathR, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Subtle knuckle indent lines
        var kLines = Path()
        kLines.move(to: CGPoint(x: cornerX - 14.0, y: gripY - 1.0))
        kLines.addLine(to: CGPoint(x: cornerX - 14.0, y: gripY + 2.5))
        kLines.move(to: CGPoint(x: cornerX + 14.0, y: gripY - 1.0))
        kLines.addLine(to: CGPoint(x: cornerX + 14.0, y: gripY + 2.5))
        context.stroke(kLines, with: .color(outlineColor), lineWidth: 1.0)
    }
    
    // MARK: - 4. Notch Hang & Pull-Up (Under Notch)
    private func renderNotchHangAndPullUp(
        context: inout GraphicsContext,
        pose: SkeletonPose,
        skin: CompanionSkin
    ) {
        let bodyColor = skin.primaryColor
        let outlineColor = skin.outlineColor
        let earColor = skin.darkAccentColor
        let soleColor = skin.darkAccentColor
        
        let handL = CGPoint(x: engine.handLWorldX, y: engine.ledgeY + 2.0)
        let handR = CGPoint(x: engine.handRWorldX, y: engine.ledgeY + 2.0)
        let angle = engine.pendulumAngle
        let root = pose.torso.root
        
        var bodyTransform = CGAffineTransform.identity
        bodyTransform = bodyTransform.translatedBy(x: root.x, y: root.y)
        bodyTransform = bodyTransform.rotated(by: angle * 0.5)
        
        // 1. Chubby Legs Kicking Playfully (NO thin stick bones!)
        let legW: CGFloat = 8.5
        let legH: CGFloat = 11.0
        let kickTime = engine.behaviorTime
        let kickL = sin(kickTime * 9.0) * 4.0
        let kickR = sin(kickTime * 7.5 + 1.2) * 4.0
        
        // Left Leg
        var legLPath = Path()
        let rL = CGRect(x: -7.0 - legW / 2.0 + kickL, y: 8.0, width: legW, height: legH)
        legLPath.addRoundedRect(in: rL, cornerSize: CGSize(width: 4.0, height: 4.0))
        context.fill(legLPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(legLPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        // Dark sole
        let soleL = CGRect(x: -7.0 - legW / 2.0 + kickL, y: 8.0 + legH - 3.5, width: legW, height: 3.5)
        context.fill(Path(ellipseIn: soleL).applying(bodyTransform), with: .color(soleColor))
        
        // Right Leg
        var legRPath = Path()
        let rR = CGRect(x: 7.0 - legW / 2.0 + kickR, y: 8.0, width: legW, height: legH)
        legRPath.addRoundedRect(in: rR, cornerSize: CGSize(width: 4.0, height: 4.0))
        context.fill(legRPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(legRPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        // Dark sole
        let soleR = CGRect(x: 7.0 - legW / 2.0 + kickR, y: 8.0 + legH - 3.5, width: legW, height: 3.5)
        context.fill(Path(ellipseIn: soleR).applying(bodyTransform), with: .color(soleColor))
        
        // 2. Chubby Marshmallow Torso
        var torsoPath = Path()
        let tw: CGFloat = 26.0
        let th: CGFloat = 24.0
        let torsoRect = CGRect(x: -tw / 2.0, y: -th * 0.5, width: tw, height: th)
        torsoPath.addRoundedRect(in: torsoRect, cornerSize: CGSize(width: 8.0, height: 8.0))
        context.fill(torsoPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(torsoPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Tail
        let tailRect = CGRect(x: -tw / 2.0 - 3.0, y: 0.0, width: 7.0, height: 7.0)
        context.fill(Path(ellipseIn: tailRect).applying(bodyTransform), with: .color(bodyColor))
        context.stroke(Path(ellipseIn: tailRect).applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 3. Thick Chubby Arms connecting Torso to Hand Grips (NO stick lines!)
        let shoulderL = CGPoint(x: root.x - 9.0 * cos(angle * 0.5), y: root.y - 8.0)
        let shoulderR = CGPoint(x: root.x + 9.0 * cos(angle * 0.5), y: root.y - 8.0)
        
        // Left Arm
        var armL = Path()
        armL.move(to: shoulderL)
        armL.addQuadCurve(to: handL, control: CGPoint(x: (shoulderL.x + handL.x) / 2.0 - 5.0, y: (shoulderL.y + handL.y) / 2.0))
        context.stroke(armL, with: .color(outlineColor), style: StrokeStyle(lineWidth: 8.5, lineCap: .round, lineJoin: .round))
        context.stroke(armL, with: .color(bodyColor), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
        
        // Right Arm
        var armR = Path()
        armR.move(to: shoulderR)
        armR.addQuadCurve(to: handR, control: CGPoint(x: (shoulderR.x + handR.x) / 2.0 + 5.0, y: (shoulderR.y + handR.y) / 2.0))
        context.stroke(armR, with: .color(outlineColor), style: StrokeStyle(lineWidth: 8.5, lineCap: .round, lineJoin: .round))
        context.stroke(armR, with: .color(bodyColor), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
        
        // 4. Head
        let headCenter = CGPoint(x: root.x + CGFloat(angle) * 3.0, y: root.y - 18.0)
        var headTransform = CGAffineTransform.identity
        headTransform = headTransform.translatedBy(x: headCenter.x, y: headCenter.y)
        headTransform = headTransform.rotated(by: angle * 0.3)
        
        let headW: CGFloat = 34.0
        let headH: CGFloat = 28.0
        
        // Ears
        let earRadius: CGFloat = 5.0
        let earLRect = CGRect(x: -headW * 0.32 - earRadius, y: -headH * 0.44 - earRadius, width: earRadius * 2, height: earRadius * 2)
        let earRRect = CGRect(x: headW * 0.32 - earRadius, y: -headH * 0.44 - earRadius, width: earRadius * 2, height: earRadius * 2)
        context.fill(Path(ellipseIn: earLRect).applying(headTransform), with: .color(earColor))
        context.stroke(Path(ellipseIn: earLRect).applying(headTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        context.fill(Path(ellipseIn: earRRect).applying(headTransform), with: .color(earColor))
        context.stroke(Path(ellipseIn: earRRect).applying(headTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Dumpling head shape
        let headShape = dumplingHeadPath(width: headW, height: headH).applying(headTransform)
        context.fill(headShape, with: .color(bodyColor))
        context.stroke(headShape, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Face
        var hangPose = pose
        if coordinator.state == .slipping {
            hangPose.mouthShape = .gasp
        } else if coordinator.state == .pullingUp {
            hangPose.mouthShape = .sigh
        } else {
            hangPose.mouthShape = .smile
        }
        drawBubuFace(
            context: &context,
            transform: headTransform,
            pose: hangPose,
            skin: skin,
            headWidth: headW,
            headHeight: headH
        )
        
        // 5. Chubby Paws Gripping Notch Lip
        for hp in [handL, handR] {
            let pawRect = CGRect(x: hp.x - 4.5, y: hp.y - 3.0, width: 9.0, height: 6.5)
            let pawPath = Path(roundedRect: pawRect, cornerRadius: 2.5)
            context.fill(pawPath, with: .color(bodyColor))
            context.stroke(pawPath, with: .color(outlineColor), style: cartoonStrokeStyle)
        }
    }
    
    // MARK: - 5. Front-Facing Chubby Mascot (Thinking, Curious, Typing, Crawling, Groove)
    private func renderChubbyMascot(
        context: inout GraphicsContext,
        pose: SkeletonPose,
        skin: CompanionSkin
    ) {
        let torso = pose.torso
        let rootPt = torso.root
        let headPt = pose.headCenter
        
        let lShoulderPt = pose.leftArm.anchor
        let lElbowPt = pose.leftArm.joint
        let lHandPt = pose.leftArm.end
        
        let rShoulderPt = pose.rightArm.anchor
        let rElbowPt = pose.rightArm.joint
        let rHandPt = pose.rightArm.end
        
        let lHipPt = pose.leftLeg.anchor
        let lKneePt = pose.leftLeg.joint
        let lFootPt = pose.leftLeg.end
        
        let rHipPt = pose.rightLeg.anchor
        let rKneePt = pose.rightLeg.joint
        let rFootPt = pose.rightLeg.end
        
        let bodyColor = skin.primaryColor
        let outlineColor = skin.outlineColor
        let soleColor = skin.darkAccentColor
        
        // 1. Contact Shadow on Ledge Line
        if rootPt.y <= engine.ledgeY + 28.0 && rootPt.y >= 0 {
            let shadowDist = max(0, engine.ledgeY + 24.0 - rootPt.y)
            let shadowOpacity = max(0.0, min(0.25, 0.25 - Double(shadowDist) * 0.015))
            let shadowRect = CGRect(x: rootPt.x - 16, y: rootPt.y + 10, width: 32, height: 5)
            context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(shadowOpacity)))
        }
        
        // 2. Tail
        if pose.drawsTorso {
            drawTail(context: &context, root: rootPt, facingRight: pose.facingRight, skin: skin)
        }
        
        // 3. Back Limbs (Right limbs, drawn with full cartoon thickness)
        let backTone = bodyColor.opacity(0.88)
        let limbThickness: CGFloat = 8.5
        
        if pose.drawsLegs {
            drawChubbyLimb(context: &context, p1: rHipPt, p2: rKneePt, p3: rFootPt, thickness: limbThickness, color: backTone, outlineColor: outlineColor)
            drawChubbyFoot(context: &context, center: rFootPt, angle: 0, size: 7.5, color: backTone, soleColor: soleColor, outlineColor: outlineColor)
        }
        
        if pose.drawsArms {
            drawChubbyLimb(context: &context, p1: rShoulderPt, p2: rElbowPt, p3: rHandPt, thickness: limbThickness - 0.5, color: backTone, outlineColor: outlineColor)
            drawChubbyPaw(context: &context, center: rHandPt, size: 7.0, color: backTone, outlineColor: outlineColor, isGripping: pose.rightArm.isPlantedOrGripping)
        }
        
        // 4. Torso Hull (Marshmallow shape)
        if pose.drawsTorso {
            drawChubbyTorso(context: &context, torso: torso, skin: skin)
        }
        
        // 5. Head Rig (Squishy Dumpling with Bubu face)
        if pose.drawsHead {
            drawChubbyHead(context: &context, head: headPt, angle: pose.headAngle, pose: pose, skin: skin)
        }
        
        // 6. Front Limbs (Foreground Left limbs, vibrant skin tone)
        if pose.drawsLegs {
            drawChubbyLimb(context: &context, p1: lHipPt, p2: lKneePt, p3: lFootPt, thickness: limbThickness, color: bodyColor, outlineColor: outlineColor)
            drawChubbyFoot(context: &context, center: lFootPt, angle: 0, size: 7.5, color: bodyColor, soleColor: soleColor, outlineColor: outlineColor)
        }
        
        if pose.drawsArms {
            drawChubbyLimb(context: &context, p1: lShoulderPt, p2: lElbowPt, p3: lHandPt, thickness: limbThickness - 0.5, color: bodyColor, outlineColor: outlineColor)
            drawChubbyPaw(context: &context, center: lHandPt, size: 7.0, color: bodyColor, outlineColor: outlineColor, isGripping: pose.leftArm.isPlantedOrGripping)
        }
    }
    
    // MARK: - Core Vector Drawing Components
    
    /// Generates the iconic dumpling head shape: squishy plump cheeks, gently flattened chin, rounded top
    private func dumplingHeadPath(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let w = width
        let h = height
        path.move(to: CGPoint(x: 0, y: -h * 0.5))
        path.addCurve(
            to: CGPoint(x: w * 0.44, y: -h * 0.28),
            control1: CGPoint(x: w * 0.26, y: -h * 0.5),
            control2: CGPoint(x: w * 0.42, y: -h * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.48, y: h * 0.22),
            control1: CGPoint(x: w * 0.52, y: -h * 0.08),
            control2: CGPoint(x: w * 0.54, y: h * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.22, y: h * 0.48),
            control1: CGPoint(x: w * 0.42, y: h * 0.38),
            control2: CGPoint(x: w * 0.34, y: h * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: -w * 0.22, y: h * 0.48),
            control1: CGPoint(x: w * 0.08, y: h * 0.5),
            control2: CGPoint(x: -w * 0.08, y: h * 0.5)
        )
        path.addCurve(
            to: CGPoint(x: -w * 0.48, y: h * 0.22),
            control1: CGPoint(x: -w * 0.34, y: h * 0.48),
            control2: CGPoint(x: -w * 0.42, y: h * 0.38)
        )
        path.addCurve(
            to: CGPoint(x: -w * 0.44, y: -h * 0.28),
            control1: CGPoint(x: -w * 0.54, y: h * 0.08),
            control2: CGPoint(x: -w * 0.52, y: -h * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: -h * 0.5),
            control1: CGPoint(x: -w * 0.42, y: -h * 0.42),
            control2: CGPoint(x: -w * 0.26, y: -h * 0.5)
        )
        path.closeSubpath()
        return path
    }
    
    /// Head ears tailored to each skin (Solid chocolate circles for Bubu!)
    private func drawHeadEars(
        context: inout GraphicsContext,
        transform: CGAffineTransform,
        headWidth: CGFloat,
        headHeight: CGFloat,
        skin: CompanionSkin
    ) {
        let earRadius: CGFloat = headWidth * 0.15
        let earY = -headHeight * 0.42
        let earSpread = headWidth * 0.34
        
        switch skin {
        case .kuro:
            var earL = Path()
            earL.move(to: CGPoint(x: -earSpread - earRadius * 0.6, y: earY + 4))
            earL.addLine(to: CGPoint(x: -earSpread - 2, y: earY - 10))
            earL.addLine(to: CGPoint(x: -earSpread + earRadius * 0.8, y: earY + 2))
            earL.closeSubpath()
            context.fill(earL.applying(transform), with: .color(skin.primaryColor))
            context.stroke(earL.applying(transform), with: .color(skin.outlineColor), style: cartoonStrokeStyle)
            
            var earR = Path()
            earR.move(to: CGPoint(x: earSpread - earRadius * 0.8, y: earY + 2))
            earR.addLine(to: CGPoint(x: earSpread + 2, y: earY - 10))
            earR.addLine(to: CGPoint(x: earSpread + earRadius * 0.6, y: earY + 4))
            earR.closeSubpath()
            context.fill(earR.applying(transform), with: .color(skin.primaryColor))
            context.stroke(earR.applying(transform), with: .color(skin.outlineColor), style: cartoonStrokeStyle)
            
        case .boba:
            for offset in [-earSpread, 0, earSpread] {
                var spine = Path()
                spine.move(to: CGPoint(x: offset - 3.5, y: -headHeight * 0.46))
                spine.addQuadCurve(to: CGPoint(x: offset + 3.5, y: -headHeight * 0.46), control: CGPoint(x: offset, y: -headHeight * 0.46 - 8))
                spine.closeSubpath()
                context.fill(spine.applying(transform), with: .color(Color(red: 0.98, green: 0.55, blue: 0.50)))
                context.stroke(spine.applying(transform), with: .color(skin.outlineColor), style: cartoonStrokeStyle)
            }
            
        case .cyber, .pixel:
            var ant = Path()
            ant.move(to: CGPoint(x: 0, y: -headHeight * 0.48))
            ant.addLine(to: CGPoint(x: 0, y: -headHeight * 0.48 - 9))
            context.stroke(ant.applying(transform), with: .color(skin.outlineColor), style: cartoonStrokeStyle)
            let orb = CGRect(x: -3, y: -headHeight * 0.48 - 14, width: 6, height: 6)
            context.fill(Path(ellipseIn: orb).applying(transform), with: .color(skin.accentColor))
            context.stroke(Path(ellipseIn: orb).applying(transform), with: .color(skin.outlineColor), style: cartoonStrokeStyle)
            
        case .bubu, .mochi:
            let leftEarRect = CGRect(x: -earSpread - earRadius, y: earY - earRadius, width: earRadius * 2, height: earRadius * 2)
            let rightEarRect = CGRect(x: earSpread - earRadius, y: earY - earRadius, width: earRadius * 2, height: earRadius * 2)
            let earColor = skin.darkAccentColor
            context.fill(Path(ellipseIn: leftEarRect).applying(transform), with: .color(earColor))
            context.stroke(Path(ellipseIn: leftEarRect).applying(transform), with: .color(skin.outlineColor), style: cartoonStrokeStyle)
            context.fill(Path(ellipseIn: rightEarRect).applying(transform), with: .color(earColor))
            context.stroke(Path(ellipseIn: rightEarRect).applying(transform), with: .color(skin.outlineColor), style: cartoonStrokeStyle)
        }
    }
    
    /// Adorable cartoon face: wide-set dot eyes, curved eyebrows, cat 'w' mouth, and giant rosy blush!
    private func drawBubuFace(
        context: inout GraphicsContext,
        transform: CGAffineTransform,
        pose: SkeletonPose,
        skin: CompanionSkin,
        headWidth: CGFloat,
        headHeight: CGFloat,
        forceSleepEyes: Bool = false
    ) {
        if skin == .cyber {
            let visorRect = CGRect(x: -headWidth * 0.32, y: -headHeight * 0.12, width: headWidth * 0.64, height: headHeight * 0.32)
            let visorPath = Path(roundedRect: visorRect, cornerRadius: 4.0).applying(transform)
            context.fill(visorPath, with: .color(Color(red: 0.06, green: 0.08, blue: 0.12)))
            context.stroke(visorPath, with: .color(skin.accentColor), lineWidth: 1.5)
            
            let eyeL = CGPoint(x: -headWidth * 0.16 + pose.pupilOffset.x * 2.0, y: 0.0 + pose.pupilOffset.y * 1.5)
            let eyeR = CGPoint(x: headWidth * 0.16 + pose.pupilOffset.x * 2.0, y: 0.0 + pose.pupilOffset.y * 1.5)
            context.fill(Path(ellipseIn: CGRect(x: eyeL.x - 2, y: eyeL.y - 2, width: 4, height: 4)).applying(transform), with: .color(skin.accentColor))
            context.fill(Path(ellipseIn: CGRect(x: eyeR.x - 2, y: eyeR.y - 2, width: 4, height: 4)).applying(transform), with: .color(skin.accentColor))
            return
        }
        
        // 1. Giant Circular Rosy Blush (Iconic Bubu cheeks!)
        let blushRadius: CGFloat = 5.6
        let blushY: CGFloat = headHeight * 0.14
        let blushSpread: CGFloat = headWidth * 0.32
        let blushL = CGRect(x: -blushSpread - blushRadius, y: blushY - blushRadius, width: blushRadius * 2, height: blushRadius * 2)
        let blushR = CGRect(x: blushSpread - blushRadius, y: blushY - blushRadius, width: blushRadius * 2, height: blushRadius * 2)
        
        let blushColor = skin.accentColor.opacity(0.85)
        context.fill(Path(ellipseIn: blushL).applying(transform), with: .color(blushColor))
        context.fill(Path(ellipseIn: blushR).applying(transform), with: .color(blushColor))
        
        let eyeColor = skin.eyeColor
        let eyeSpread = headWidth * 0.22
        let eyeY = headHeight * 0.02
        
        // 2. Eyes (Solid cute dark dots - NO creepy white sclera!)
        let leftClosed = forceSleepEyes || pose.leftEyeOpen <= 0.2
        let rightClosed = forceSleepEyes || pose.rightEyeOpen <= 0.2
        
        // Left Eye
        if leftClosed {
            var p = Path()
            p.move(to: CGPoint(x: -eyeSpread - 3.2, y: eyeY + 1.0))
            p.addQuadCurve(to: CGPoint(x: -eyeSpread + 3.2, y: eyeY + 1.0), control: CGPoint(x: -eyeSpread, y: eyeY - 2.0))
            context.stroke(p.applying(transform), with: .color(eyeColor), lineWidth: 1.8)
        } else {
            let eyeDot = CGPoint(x: -eyeSpread + pose.pupilOffset.x * 1.6, y: eyeY + pose.pupilOffset.y * 1.2)
            let eyeRect = CGRect(x: eyeDot.x - 2.0, y: eyeDot.y - 2.0, width: 4.0, height: 4.0)
            context.fill(Path(ellipseIn: eyeRect).applying(transform), with: .color(eyeColor))
            let glint = CGRect(x: eyeDot.x + 0.4, y: eyeDot.y - 1.4, width: 1.3, height: 1.3)
            context.fill(Path(ellipseIn: glint).applying(transform), with: .color(.white))
        }
        
        // Right Eye
        if rightClosed {
            var p = Path()
            p.move(to: CGPoint(x: eyeSpread - 3.2, y: eyeY + 1.0))
            p.addQuadCurve(to: CGPoint(x: eyeSpread + 3.2, y: eyeY + 1.0), control: CGPoint(x: eyeSpread, y: eyeY - 2.0))
            context.stroke(p.applying(transform), with: .color(eyeColor), lineWidth: 1.8)
        } else {
            let eyeDot = CGPoint(x: eyeSpread + pose.pupilOffset.x * 1.6, y: eyeY + pose.pupilOffset.y * 1.2)
            let eyeRect = CGRect(x: eyeDot.x - 2.0, y: eyeDot.y - 2.0, width: 4.0, height: 4.0)
            context.fill(Path(ellipseIn: eyeRect).applying(transform), with: .color(eyeColor))
            let glint = CGRect(x: eyeDot.x + 0.4, y: eyeDot.y - 1.4, width: 1.3, height: 1.3)
            context.fill(Path(ellipseIn: glint).applying(transform), with: .color(.white))
        }
        
        // 3. Eyebrows (Two tiny curved arcs `⌒   ⌒` above eyes)
        let browY = eyeY - 6.0
        var browL = Path()
        browL.move(to: CGPoint(x: -eyeSpread - 3.2, y: browY + 0.5))
        browL.addQuadCurve(to: CGPoint(x: -eyeSpread + 2.8, y: browY + 0.5), control: CGPoint(x: -eyeSpread - 0.2, y: browY - 1.8))
        context.stroke(browL.applying(transform), with: .color(eyeColor), lineWidth: 1.3)
        
        var browR = Path()
        browR.move(to: CGPoint(x: eyeSpread - 2.8, y: browY + 0.5))
        browR.addQuadCurve(to: CGPoint(x: eyeSpread + 3.2, y: browY + 0.5), control: CGPoint(x: eyeSpread + 0.2, y: browY - 1.8))
        context.stroke(browR.applying(transform), with: .color(eyeColor), lineWidth: 1.3)
        
        // 4. Mouth (Cute cat `w` mouth!)
        let mouthY = eyeY + 4.6
        switch pose.mouthShape {
        case .gasp:
            let r = CGRect(x: -2.2, y: mouthY - 1.5, width: 4.4, height: 5.2)
            context.fill(Path(ellipseIn: r).applying(transform), with: .color(eyeColor))
            context.stroke(Path(ellipseIn: r).applying(transform), with: .color(skin.outlineColor), lineWidth: 1.2)
        case .smile:
            var p = Path()
            p.move(to: CGPoint(x: -3.4, y: mouthY - 0.5))
            p.addQuadCurve(to: CGPoint(x: 3.4, y: mouthY - 0.5), control: CGPoint(x: 0, y: mouthY + 3.6))
            p.closeSubpath()
            context.fill(p.applying(transform), with: .color(Color(red: 0.35, green: 0.15, blue: 0.18)))
            context.stroke(p.applying(transform), with: .color(eyeColor), lineWidth: 1.4)
            let tongue = CGRect(x: -1.6, y: mouthY + 0.8, width: 3.2, height: 2.2)
            context.fill(Path(ellipseIn: tongue).applying(transform), with: .color(skin.accentColor))
        case .sigh:
            var p = Path()
            p.move(to: CGPoint(x: -2.8, y: mouthY + 1.0))
            p.addLine(to: CGPoint(x: 2.8, y: mouthY + 1.0))
            context.stroke(p.applying(transform), with: .color(eyeColor), lineWidth: 1.3)
        case .openW, .neutral:
            var p = Path()
            p.move(to: CGPoint(x: -3.2, y: mouthY - 0.2))
            p.addQuadCurve(to: CGPoint(x: 0.0, y: mouthY + 1.0), control: CGPoint(x: -1.6, y: mouthY + 2.0))
            p.addQuadCurve(to: CGPoint(x: 3.2, y: mouthY - 0.2), control: CGPoint(x: 1.6, y: mouthY + 2.0))
            context.stroke(p.applying(transform), with: .color(eyeColor), lineWidth: 1.4)
        }
    }
    
    /// Thick chubby cartoon limb with dark charcoal border (NO thin stick lines!)
    private func drawChubbyLimb(
        context: inout GraphicsContext,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint,
        thickness: CGFloat,
        color: Color,
        outlineColor: Color
    ) {
        var path = Path()
        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        
        context.stroke(
            path,
            with: .color(outlineColor),
            style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: max(1.0, thickness - 4.4), lineCap: .round, lineJoin: .round)
        )
    }
    
    /// Stubby rounded foot with dark chocolate sole pad
    private func drawChubbyFoot(
        context: inout GraphicsContext,
        center: CGPoint,
        angle: Double,
        size: CGFloat,
        color: Color,
        soleColor: Color,
        outlineColor: Color
    ) {
        let rect = CGRect(x: center.x - size / 2.0, y: center.y - size * 0.35, width: size, height: size * 0.75)
        let path = Path(ellipseIn: rect)
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Dark foot sole/pad
        let soleRect = CGRect(x: center.x - size * 0.3, y: center.y - size * 0.1, width: size * 0.6, height: size * 0.4)
        context.fill(Path(ellipseIn: soleRect), with: .color(soleColor))
    }
    
    /// Stubby rounded paw
    private func drawChubbyPaw(
        context: inout GraphicsContext,
        center: CGPoint,
        size: CGFloat,
        color: Color,
        outlineColor: Color,
        isGripping: Bool
    ) {
        if isGripping {
            let rect = CGRect(x: center.x - size / 2.0, y: center.y - 1.5, width: size, height: size * 0.75)
            let path = Path(roundedRect: rect, cornerRadius: 2.5)
            context.fill(path, with: .color(color))
            context.stroke(path, with: .color(outlineColor), style: cartoonStrokeStyle)
            var line = Path()
            line.move(to: CGPoint(x: center.x, y: center.y - 1.0))
            line.addLine(to: CGPoint(x: center.x, y: center.y + 2.5))
            context.stroke(line, with: .color(outlineColor), lineWidth: 1.0)
        } else {
            let rect = CGRect(x: center.x - size / 2.0, y: center.y - size / 2.0, width: size, height: size)
            let path = Path(ellipseIn: rect)
            context.fill(path, with: .color(color))
            context.stroke(path, with: .color(outlineColor), style: cartoonStrokeStyle)
        }
    }
    
    /// Chubby marshmallow torso
    private func drawChubbyTorso(
        context: inout GraphicsContext,
        torso: TorsoBones,
        skin: CompanionSkin
    ) {
        let root = torso.root
        let neck = torso.neck
        let dx = neck.x - root.x
        let dy = neck.y - root.y
        let spineLength = sqrt(dx * dx + dy * dy)
        let spineAngle = atan2(dy, dx)
        
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: root.x, y: root.y)
        transform = transform.rotated(by: spineAngle + .pi / 2.0)
        
        let torsoWidth: CGFloat = 24.0
        let torsoHeight: CGFloat = max(18.0, spineLength + 8.0)
        let localRect = CGRect(x: -torsoWidth / 2.0, y: -torsoHeight, width: torsoWidth, height: torsoHeight)
        let path = Path(roundedRect: localRect, cornerRadius: 9.0).applying(transform)
        
        context.fill(path, with: .color(skin.primaryColor))
        context.stroke(path, with: .color(skin.outlineColor), style: cartoonStrokeStyle)
        
        if skin == .boba {
            let belly = CGRect(x: -6.0, y: -torsoHeight * 0.65, width: 12.0, height: 14.0)
            context.fill(Path(ellipseIn: belly).applying(transform), with: .color(Color(red: 0.98, green: 0.55, blue: 0.50).opacity(0.35)))
        }
    }
    
    /// Squishy dumpling head with face features
    private func drawChubbyHead(
        context: inout GraphicsContext,
        head: CGPoint,
        angle: Double,
        pose: SkeletonPose,
        skin: CompanionSkin
    ) {
        let rad = angle * .pi / 180.0
        var t = CGAffineTransform.identity
        t = t.translatedBy(x: head.x, y: head.y)
        t = t.rotated(by: rad)
        if !pose.facingRight {
            t = t.scaledBy(x: -1.0, y: 1.0)
        }
        
        let headW: CGFloat = 34.0
        let headH: CGFloat = 28.0
        
        // 1. Ears
        drawHeadEars(context: &context, transform: t, headWidth: headW, headHeight: headH, skin: skin)
        
        // 2. Dumpling head shape
        let shape = dumplingHeadPath(width: headW, height: headH).applying(t)
        context.fill(shape, with: .color(skin.primaryColor))
        context.stroke(shape, with: .color(skin.outlineColor), style: cartoonStrokeStyle)
        
        // 3. Subtle highlight
        let hl = CGRect(x: -5.0, y: -headH * 0.38, width: 10.0, height: 4.5)
        context.fill(Path(ellipseIn: hl).applying(t), with: .color(.white.opacity(0.40)))
        
        // 4. Face Features
        drawBubuFace(
            context: &context,
            transform: t,
            pose: pose,
            skin: skin,
            headWidth: headW,
            headHeight: headH
        )
    }
    
    /// White circular puff tail with dark outline
    private func drawTail(
        context: inout GraphicsContext,
        root: CGPoint,
        facingRight: Bool,
        skin: CompanionSkin
    ) {
        let dir: CGFloat = facingRight ? -1.0 : 1.0
        switch skin {
        case .bubu, .mochi:
            let tailRect = CGRect(x: root.x + dir * 13.0 - 4.5, y: root.y - 6.0, width: 9.0, height: 9.0)
            context.fill(Path(ellipseIn: tailRect), with: .color(skin.primaryColor))
            context.stroke(Path(ellipseIn: tailRect), with: .color(skin.outlineColor), style: cartoonStrokeStyle)
        case .kuro, .boba:
            var path = Path()
            path.move(to: CGPoint(x: root.x + dir * 6.0, y: root.y - 2.0))
            path.addCurve(
                to: CGPoint(x: root.x + dir * 18.0, y: root.y - 12.0),
                control1: CGPoint(x: root.x + dir * 10.0, y: root.y + 4.0),
                control2: CGPoint(x: root.x + dir * 16.0, y: root.y - 2.0)
            )
            context.stroke(path, with: .color(skin.outlineColor), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            context.stroke(path, with: .color(skin.primaryColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        default:
            break
        }
    }
    
    /// Gently floating sleeping 'Zzz' animation
    private func drawFloatingZzz(
        context: inout GraphicsContext,
        origin: CGPoint,
        time: Double
    ) {
        let zColors = [
            Color(red: 0.60, green: 0.70, blue: 0.95),
            Color(red: 0.70, green: 0.60, blue: 0.95),
            Color(red: 0.85, green: 0.65, blue: 0.90)
        ]
        let cycle = (time * 1.2).truncatingRemainder(dividingBy: 3.0)
        
        for i in 0..<3 {
            let phase = (cycle + Double(i) * 1.0).truncatingRemainder(dividingBy: 3.0)
            let progress = CGFloat(phase / 3.0)
            let yOffset = -progress * 26.0
            let xOffset = sin(progress * .pi * 2.5) * 4.5 + CGFloat(i * 3)
            let opacity = Double(sin(progress * .pi))
            let fontSize: CGFloat = 8.0 + CGFloat(i) * 2.5
            
            let zPos = CGPoint(x: origin.x + xOffset, y: origin.y + yOffset)
            let zText = Text("z")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(zColors[i].opacity(opacity))
            
            context.draw(zText, at: zPos)
        }
    }
    
    private func drawMiniLaptop(context: inout GraphicsContext, position: CGPoint) {
        let base = CGRect(x: position.x - 8, y: position.y - 1.5, width: 16, height: 3)
        context.fill(Path(roundedRect: base, cornerRadius: 1), with: .color(Color(white: 0.3)))
        
        let screen = CGRect(x: position.x - 7, y: position.y - 10, width: 14, height: 9)
        context.fill(Path(roundedRect: screen, cornerRadius: 1.5), with: .color(Color.cyan.opacity(0.85)))
    }
    
    private func drawMiniHeadphones(context: inout GraphicsContext, head: CGPoint, skin: CompanionSkin) {
        var arc = Path()
        arc.addArc(center: head, radius: 14.0, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        context.stroke(arc, with: .color(skin.outlineColor), lineWidth: 2.2)
        
        let padL = CGRect(x: head.x - 15.5, y: head.y - 5, width: 4.0, height: 9)
        let padR = CGRect(x: head.x + 11.5, y: head.y - 5, width: 4.0, height: 9)
        context.fill(Path(roundedRect: padL, cornerRadius: 2.0), with: .color(skin.accentColor))
        context.stroke(Path(roundedRect: padL, cornerRadius: 2.0), with: .color(skin.outlineColor), lineWidth: 1.2)
        context.fill(Path(roundedRect: padR, cornerRadius: 2.0), with: .color(skin.accentColor))
        context.stroke(Path(roundedRect: padR, cornerRadius: 2.0), with: .color(skin.outlineColor), lineWidth: 1.2)
    }
    
    // MARK: - Optional Visual Skeleton Rig Debug Overlay (For developers only)
    private func drawDebugSkeletonOverlay(
        context: inout GraphicsContext,
        pose: SkeletonPose
    ) {
        let torso = pose.torso
        
        drawLine(context: &context, from: torso.root, to: torso.neck, color: .green, width: 1.5)
        drawLine(context: &context, from: torso.leftShoulderAnchor, to: torso.rightShoulderAnchor, color: .green, width: 1.2)
        drawLine(context: &context, from: torso.leftHipAnchor, to: torso.rightHipAnchor, color: .green, width: 1.2)
        drawLine(context: &context, from: torso.neck, to: pose.headCenter, color: .green, width: 1.5)
        
        drawLine(context: &context, from: pose.leftArm.anchor, to: pose.leftArm.joint, color: .cyan, width: 1.5)
        drawLine(context: &context, from: pose.leftArm.joint, to: pose.leftArm.end, color: .cyan, width: 1.5)
        drawLine(context: &context, from: pose.rightArm.anchor, to: pose.rightArm.joint, color: .cyan, width: 1.5)
        drawLine(context: &context, from: pose.rightArm.joint, to: pose.rightArm.end, color: .cyan, width: 1.5)
        
        drawLine(context: &context, from: pose.leftLeg.anchor, to: pose.leftLeg.joint, color: .yellow, width: 1.5)
        drawLine(context: &context, from: pose.leftLeg.joint, to: pose.leftLeg.end, color: .yellow, width: 1.5)
        drawLine(context: &context, from: pose.rightLeg.anchor, to: pose.rightLeg.joint, color: .yellow, width: 1.5)
        drawLine(context: &context, from: pose.rightLeg.joint, to: pose.rightLeg.end, color: .yellow, width: 1.5)
    }
    
    private func drawLine(context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color, width: CGFloat) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        context.stroke(p, with: .color(color), lineWidth: width)
    }
}
