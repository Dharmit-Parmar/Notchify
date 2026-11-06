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
    
    private func volumetricGradient(for skin: CompanionSkin) -> Gradient {
        switch skin {
        case .bubu, .mochi:
            return Gradient(stops: [
                .init(color: .white, location: 0.0),
                .init(color: skin.primaryColor, location: 0.35),
                .init(color: skin.primaryColor, location: 0.65),
                .init(color: Color(red: 0.88, green: 0.89, blue: 0.94), location: 0.90),
                .init(color: Color(red: 0.82, green: 0.83, blue: 0.89), location: 1.0)
            ])
        case .kuro:
            return Gradient(stops: [
                .init(color: Color(white: 0.28), location: 0.0),
                .init(color: skin.primaryColor, location: 0.40),
                .init(color: Color(red: 0.05, green: 0.05, blue: 0.07), location: 1.0)
            ])
        case .boba:
            return Gradient(stops: [
                .init(color: Color(red: 0.65, green: 0.95, blue: 0.72), location: 0.0),
                .init(color: skin.primaryColor, location: 0.45),
                .init(color: Color(red: 0.28, green: 0.55, blue: 0.35), location: 1.0)
            ])
        case .pixel:
            return Gradient(stops: [
                .init(color: Color(red: 1.0, green: 0.88, blue: 0.50), location: 0.0),
                .init(color: skin.primaryColor, location: 0.45),
                .init(color: Color(red: 0.75, green: 0.55, blue: 0.15), location: 1.0)
            ])
        case .cyber:
            return Gradient(stops: [
                .init(color: Color(red: 0.35, green: 0.42, blue: 0.52), location: 0.0),
                .init(color: skin.primaryColor, location: 0.45),
                .init(color: Color(red: 0.10, green: 0.13, blue: 0.18), location: 1.0)
            ])
        }
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
                    debugSkeleton: store.companionDebugSkeleton
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
        
        // 1. Specialized State Renderers
        if state == .sleeping {
            // Tummy Rest Pose matching Reference Image 1
            renderTummyRestPose(context: &context, pose: pose, skin: skin)
        } else if state == .peekingLeft || state == .peekingRight {
            // Lip Peek with chubby white paws gripping notch edge
            let side: CGFloat = (state == .peekingLeft) ? -1.0 : 1.0
            renderLipPeek(context: &context, pose: pose, skin: skin, side: side)
        } else if state == .dangling || state == .slipping || state == .pullingUp ||
                  (state == .walking && (engine.routeStage == .lowerToHang || engine.routeStage == .monkeyBarTraversal || engine.routeStage == .climbOntoRightLedge)) {
            // Notch Hang & Pull-Up with chubby limbs and dangling marshmallow body
            renderNotchHangAndPullUp(context: &context, pose: pose, skin: skin)
        } else if state == .walking {
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
        context.fill(bodyPath, with: .radialGradient(volumetricGradient(for: skin), center: CGPoint(x: cx, y: groundY - 10), startRadius: 1, endRadius: 24))
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
        drawHeadEars(context: &context, transform: headTransform, headWidth: headW, headHeight: headH, skin: skin)
        
        // Dumpling head shape
        let headShape = dumplingHeadPath(width: headW, height: headH).applying(headTransform)
        let lightCenter = CGPoint(x: headCenter.x - 3.0 * dir, y: headCenter.y - 4.0)
        context.fill(headShape, with: .radialGradient(volumetricGradient(for: skin), center: lightCenter, startRadius: 1, endRadius: headW * 0.65))
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
        let dir: CGFloat = pose.facingRight ? 1.0 : -1.0
        
        let bodyColor = skin.primaryColor
        let outlineColor = skin.outlineColor
        let soleColor = skin.darkAccentColor
        
        // Butt and Body Sway (Signature Bubu Waddle!)
        let isLeftPlanted = KinematicEngine.shared.isLeftFootPlanted
        let stepSide: CGFloat = isLeftPlanted ? 1.0 : -1.0
        let sway = sin(u * .pi) * 3.5 * stepSide
        let tilt = sin(u * .pi) * 4.0 * (.pi / 180.0) * stepSide * dir
        let bounce = -1.2 * (1.0 - cos(2.0 * .pi * u))
        
        let cx = pose.torso.root.x
        let cy = pose.torso.root.y + bounce
        
        // 1. Soft contact shadow on ground
        let shadowRect = CGRect(x: cx - 18, y: walkY - 1.5, width: 36, height: 4.5)
        context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(0.18)))
        
        var bodyTransform = CGAffineTransform.identity
        bodyTransform = bodyTransform.translatedBy(x: cx + sway, y: cy)
        bodyTransform = bodyTransform.rotated(by: tilt)
        
        // 2. Stubby Feet with Alternating Dark Soles (NO long legs, strictly matching Reference!)
        let footW: CGFloat = 8.5
        let footH: CGFloat = 5.5
        let swingLift = -2.5 * sin(u * .pi)
        
        // Left Foot
        let leftFootX: CGFloat = -7.5
        let leftFootY: CGFloat = 8.0 + (isLeftPlanted ? 0.0 : swingLift)
        let leftFootRect = CGRect(x: leftFootX - footW / 2.0, y: leftFootY, width: footW, height: footH)
        let leftFootPath = Path(ellipseIn: leftFootRect)
        context.fill(leftFootPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(leftFootPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        let leftSoleRect = CGRect(x: leftFootX - footW * 0.35, y: leftFootY + footH * 0.35, width: footW * 0.7, height: footH * 0.55)
        context.fill(Path(ellipseIn: leftSoleRect).applying(bodyTransform), with: .color(soleColor))
        
        // Right Foot
        let rightFootX: CGFloat = 7.5
        let rightFootY: CGFloat = 8.0 + (!isLeftPlanted ? 0.0 : swingLift)
        let rightFootRect = CGRect(x: rightFootX - footW / 2.0, y: rightFootY, width: footW, height: footH)
        let rightFootPath = Path(ellipseIn: rightFootRect)
        context.fill(rightFootPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(rightFootPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        let rightSoleRect = CGRect(x: rightFootX - footW * 0.35, y: rightFootY + footH * 0.35, width: footW * 0.7, height: footH * 0.55)
        context.fill(Path(ellipseIn: rightSoleRect).applying(bodyTransform), with: .color(soleColor))
        
        // 3. Stubby Arms dangling and swinging at sides
        let armSwing = sin(u * 2.0 * .pi) * 3.0
        let armLRect = CGRect(x: -16.5, y: -7.0 + armSwing, width: 6.5, height: 11.0)
        let armLPath = Path(roundedRect: armLRect, cornerRadius: 3.2)
        context.fill(armLPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(armLPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        let armRRect = CGRect(x: 10.0, y: -7.0 - armSwing, width: 6.5, height: 11.0)
        let armRPath = Path(roundedRect: armRRect, cornerRadius: 3.2)
        context.fill(armRPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(armRPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 4. Chubby Marshmallow Torso (Pear shape with 3D radial depth gradient)
        var torsoPath = Path()
        let tw: CGFloat = 28.0
        let th: CGFloat = 24.0
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
        
        context.fill(torsoPath.applying(bodyTransform), with: .radialGradient(volumetricGradient(for: skin), center: CGPoint(x: cx + sway, y: cy - 2), startRadius: 1, endRadius: 18))
        context.stroke(torsoPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 5. Tail: White circular puff tail on lower back/side
        let tailX = -tw * 0.45 * dir
        let tailRect = CGRect(x: tailX - 4.5, y: th * 0.12 - 4.5, width: 9.0, height: 9.0)
        context.fill(Path(ellipseIn: tailRect).applying(bodyTransform), with: .color(bodyColor))
        context.stroke(Path(ellipseIn: tailRect).applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 6. Head & EXPRESSIVE FACE (Always visible, smiling in walk direction!)
        let headCenter = CGPoint(x: cx + sway * 0.5 + 2.0 * dir, y: cy - 20)
        var headTransform = CGAffineTransform.identity
        headTransform = headTransform.translatedBy(x: headCenter.x, y: headCenter.y)
        let isFarCorner = (engine.routeStage == .farCornerPeek)
        let headRot = isFarCorner ? (pose.headAngle * .pi / 180.0) : (tilt * 0.5)
        headTransform = headTransform.rotated(by: headRot)
        if dir < 0 {
            headTransform = headTransform.scaledBy(x: -1.0, y: 1.0)
        }
        
        let headW: CGFloat = 36.0
        let headH: CGFloat = 30.0
        
        // Ears on top of head (tailored to collectible skins)
        drawHeadEars(context: &context, transform: headTransform, headWidth: headW, headHeight: headH, skin: skin)
        
        // Dumpling head shape with 3D radial depth gradient
        let headShape = dumplingHeadPath(width: headW, height: headH).applying(headTransform)
        context.fill(headShape, with: .radialGradient(volumetricGradient(for: skin), center: CGPoint(x: headCenter.x - 3.0 * dir, y: headCenter.y - 4.0), startRadius: 1, endRadius: headW * 0.65))
        context.stroke(headShape, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Bubu's face: wide-set dark eyes with shine, curved eyebrows, giant pink blush, smiling cat w mouth!
        var walkFacePose = pose
        walkFacePose.mouthShape = .smile
        walkFacePose.leftEyeOpen = 1.0
        walkFacePose.rightEyeOpen = 1.0
        if !isFarCorner {
            walkFacePose.pupilOffset = CGPoint(x: 0.35, y: 0.0)
        }
        drawBubuFace(
            context: &context,
            transform: headTransform,
            pose: walkFacePose,
            skin: skin,
            headWidth: headW,
            headHeight: headH
        )
    }
    
    // MARK: - 3. Lip Peek (Left & Right Notch Curves)
    private func renderLipPeek(
        context: inout GraphicsContext,
        pose: SkeletonPose,
        skin: CompanionSkin,
        side: CGFloat
    ) {
        guard pose.drawsHead || pose.drawsArms || pose.drawsTorso else { return }
        
        let gripY = engine.ledgeY + 3.0
        let bodyColor = skin.primaryColor
        let outlineColor = skin.outlineColor
        let headCenter = pose.headCenter
        let headW: CGFloat = 36.0
        let headH: CGFloat = 30.0
        let tw: CGFloat = 26.0
        let th: CGFloat = 22.0
        
        // 1. Soft Contact Shadow on Menu Bar Ledge
        let shadowRect = CGRect(x: headCenter.x - 16.0, y: gripY - 1.5, width: 32.0, height: 4.0)
        context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(0.20)))
        
        // 2. Connected Upper Torso (Seamless body below head, drawn behind head)
        if pose.drawsTorso {
            var torsoPath = Path()
            let torsoRect = CGRect(x: headCenter.x - tw / 2.0, y: headCenter.y + 8.0, width: tw, height: th)
            torsoPath.addRoundedRect(in: torsoRect, cornerSize: CGSize(width: 8.0, height: 8.0))
            context.fill(torsoPath, with: .radialGradient(volumetricGradient(for: skin), center: CGPoint(x: headCenter.x, y: headCenter.y + 14.0), startRadius: 1, endRadius: 18))
            
            // Stroke sides only, seamlessly connecting into cheeks without cutting across neck
            var torsoSides = Path()
            torsoSides.move(to: CGPoint(x: headCenter.x - tw * 0.44, y: headCenter.y + 12.0))
            torsoSides.addLine(to: CGPoint(x: headCenter.x - tw * 0.50, y: headCenter.y + 8.0 + th))
            torsoSides.move(to: CGPoint(x: headCenter.x + tw * 0.44, y: headCenter.y + 12.0))
            torsoSides.addLine(to: CGPoint(x: headCenter.x + tw * 0.50, y: headCenter.y + 8.0 + th))
            context.stroke(torsoSides, with: .color(outlineColor), style: cartoonStrokeStyle)
        }
        
        // 3. Forearms connecting shoulders to paws (Drawn behind head so no limbs cross face)
        if pose.drawsArms {
            let armLAnchor = pose.leftArm.anchor
            let armLJoint = pose.leftArm.joint
            let armLEnd = pose.leftArm.end
            let armRAnchor = pose.rightArm.anchor
            let armRJoint = pose.rightArm.joint
            let armREnd = pose.rightArm.end
            
            drawChubbyLimb(context: &context, p1: armLAnchor, p2: armLJoint, p3: armLEnd, thickness: 5.5, color: bodyColor, outlineColor: outlineColor)
            drawChubbyLimb(context: &context, p1: armRAnchor, p2: armRJoint, p3: armREnd, thickness: 5.5, color: bodyColor, outlineColor: outlineColor)
        }
        
        // 4. Dumpling Head with 3D Depth & Face (In front of limbs so face is 100% visible)
        if pose.drawsHead {
            var headTransform = CGAffineTransform.identity
            headTransform = headTransform.translatedBy(x: headCenter.x, y: headCenter.y)
            headTransform = headTransform.rotated(by: pose.headAngle * .pi / 180.0)
            if side > 0 {
                headTransform = headTransform.scaledBy(x: -1.0, y: 1.0)
            }
            
            // Ears on top of head
            drawHeadEars(context: &context, transform: headTransform, headWidth: headW, headHeight: headH, skin: skin)
            
            // Dumpling head fill and stroke
            let headShape = dumplingHeadPath(width: headW, height: headH).applying(headTransform)
            let lightCenter = CGPoint(x: headCenter.x - headW * 0.20 * (side < 0 ? 1.0 : -1.0), y: headCenter.y - headH * 0.22)
            context.fill(headShape, with: .radialGradient(volumetricGradient(for: skin), center: lightCenter, startRadius: 1, endRadius: headW * 0.65))
            context.stroke(headShape, with: .color(outlineColor), style: cartoonStrokeStyle)
            
            // Face features from pose
            drawBubuFace(
                context: &context,
                transform: headTransform,
                pose: pose,
                skin: skin,
                headWidth: headW,
                headHeight: headH
            )
        }
        
        // 5. Chubby White Paws resting on the notch ledge lip
        if pose.drawsArms {
            let armLEnd = pose.leftArm.end
            let armREnd = pose.rightArm.end
            drawChubbyPaw(context: &context, center: armLEnd, size: 7.5, color: bodyColor, outlineColor: outlineColor, isGripping: pose.leftArm.isPlantedOrGripping)
            drawChubbyPaw(context: &context, center: armREnd, size: 7.5, color: bodyColor, outlineColor: outlineColor, isGripping: pose.rightArm.isPlantedOrGripping)
        }
    }
    
    // MARK: - 4. Notch Hang & Pull-Up (Under Notch)
    private func renderNotchHangAndPullUp(
        context: inout GraphicsContext,
        pose: SkeletonPose,
        skin: CompanionSkin
    ) {
        let bodyColor = skin.primaryColor
        let outlineColor = skin.outlineColor
        let soleColor = skin.darkAccentColor
        
        let isClimbingUp = (engine.routeStage == .climbOntoRightLedge && pose.torso.root.y < engine.ledgeY + 50.0)
        let handY = isClimbingUp ? min(engine.ledgeY + 3.0, pose.torso.root.y + 4.0) : (engine.ledgeY + 3.0)
        let handL = CGPoint(x: engine.handLWorldX, y: handY)
        let handR = CGPoint(x: engine.handRWorldX, y: handY)
        let angle = engine.pendulumAngle
        let root = pose.torso.root
        let isPullingUp = (coordinator.state == .pullingUp || engine.isPullingUpWorkout)
        
        var bodyTransform = CGAffineTransform.identity
        bodyTransform = bodyTransform.translatedBy(x: root.x, y: root.y)
        bodyTransform = bodyTransform.rotated(by: angle * 0.4)
        
        // 1. Stubby Feet Kicking Playfully (NO long legs, strictly matching Reference!)
        let footW: CGFloat = 8.5
        let footH: CGFloat = 5.5
        let kickTime = engine.behaviorTime
        let kickL = sin(kickTime * 7.5) * 5.5
        let kickR = sin(kickTime * 7.5 + 1.4) * 5.0
        
        // Left Foot Pad
        let footLY = 9.0 + kickL * 0.3
        let footLRect = CGRect(x: -7.0 - footW / 2.0 + kickL, y: footLY, width: footW, height: footH)
        let footLPath = Path(ellipseIn: footLRect)
        context.fill(footLPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(footLPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        let soleL = CGRect(x: -7.0 - footW * 0.35 + kickL, y: footLY + footH * 0.35, width: footW * 0.7, height: footH * 0.55)
        context.fill(Path(ellipseIn: soleL).applying(bodyTransform), with: .color(soleColor))
        
        // Right Foot Pad
        let footRY = 9.0 + kickR * 0.3
        let footRRect = CGRect(x: 7.0 - footW / 2.0 + kickR, y: footRY, width: footW, height: footH)
        let footRPath = Path(ellipseIn: footRRect)
        context.fill(footRPath.applying(bodyTransform), with: .color(bodyColor))
        context.stroke(footRPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        let soleR = CGRect(x: 7.0 - footW * 0.35 + kickR, y: footRY + footH * 0.35, width: footW * 0.7, height: footH * 0.55)
        context.fill(Path(ellipseIn: soleR).applying(bodyTransform), with: .color(soleColor))
        
        // 2. Chubby Marshmallow Torso (with 3D radial depth gradient)
        var torsoPath = Path()
        let tw: CGFloat = 26.0
        let th: CGFloat = 22.0
        let torsoRect = CGRect(x: -tw / 2.0, y: -th * 0.5, width: tw, height: th)
        torsoPath.addRoundedRect(in: torsoRect, cornerSize: CGSize(width: 8.0, height: 8.0))
        context.fill(torsoPath.applying(bodyTransform), with: .radialGradient(volumetricGradient(for: skin), center: CGPoint(x: root.x, y: root.y - 2), startRadius: 1, endRadius: 18))
        context.stroke(torsoPath.applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Tail
        let tailRect = CGRect(x: -tw / 2.0 - 2.5, y: -2.0, width: 7.0, height: 7.0)
        context.fill(Path(ellipseIn: tailRect).applying(bodyTransform), with: .color(bodyColor))
        context.stroke(Path(ellipseIn: tailRect).applying(bodyTransform), with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // 3. Head with 3D Depth Shading (Drawn BEFORE arms so arms stay 100% visible!)
        let headCenter = isPullingUp ? pose.headCenter : CGPoint(x: root.x + CGFloat(angle) * 2.0, y: root.y - 17.0)
        var headTransform = CGAffineTransform.identity
        headTransform = headTransform.translatedBy(x: headCenter.x, y: headCenter.y)
        headTransform = headTransform.rotated(by: angle * 0.25)
        
        let headW: CGFloat = 34.0
        let headH: CGFloat = 28.0
        
        // Ears
        drawHeadEars(context: &context, transform: headTransform, headWidth: headW, headHeight: headH, skin: skin)
        
        // Dumpling head shape with 3D radial depth gradient
        let headShape = dumplingHeadPath(width: headW, height: headH).applying(headTransform)
        let lightCenter = CGPoint(x: headCenter.x - 2.0, y: headCenter.y - 3.0)
        context.fill(headShape, with: .radialGradient(volumetricGradient(for: skin), center: lightCenter, startRadius: 1, endRadius: headW * 0.65))
        context.stroke(headShape, with: .color(outlineColor), style: cartoonStrokeStyle)
        
        // Face: beaming smile during pull-up!
        var hangPose = pose
        if coordinator.state == .slipping {
            hangPose.mouthShape = .gasp
            hangPose.leftEyeOpen = 1.2
            hangPose.rightEyeOpen = 1.2
        } else if isPullingUp {
            hangPose.mouthShape = .smile
            hangPose.leftEyeOpen = 0.0 // Joyful happy crescent eyes (^ ‿ ^)
            hangPose.rightEyeOpen = 0.0
        } else {
            hangPose.mouthShape = .smile
            hangPose.leftEyeOpen = 1.0
            hangPose.rightEyeOpen = 1.0
        }
        drawBubuFace(
            context: &context,
            transform: headTransform,
            pose: hangPose,
            skin: skin,
            headWidth: headW,
            headHeight: headH
        )
        
        // 4. Thick Chubby Arms connecting Torso to Hand Grips (Drawn in front of head with visible outward flare!)
        let shoulderL = CGPoint(x: root.x - 10.0 * cos(angle * 0.4), y: root.y - 7.0)
        let shoulderR = CGPoint(x: root.x + 10.0 * cos(angle * 0.4), y: root.y - 7.0)
        
        // Outward elbow flexion during pull-ups: flaring outward past the cheeks!
        let elbowFlare: CGFloat = isPullingUp ? 14.0 : 6.0
        var armL = Path()
        armL.move(to: shoulderL)
        armL.addQuadCurve(to: handL, control: CGPoint(x: (shoulderL.x + handL.x) / 2.0 - elbowFlare, y: (shoulderL.y + handL.y) / 2.0 + (isPullingUp ? 3.5 : 1.0)))
        context.stroke(armL, with: .color(outlineColor), style: StrokeStyle(lineWidth: 7.0, lineCap: .round, lineJoin: .round))
        context.stroke(armL, with: .color(bodyColor), style: StrokeStyle(lineWidth: 4.0, lineCap: .round, lineJoin: .round))
        
        var armR = Path()
        armR.move(to: shoulderR)
        armR.addQuadCurve(to: handR, control: CGPoint(x: (shoulderR.x + handR.x) / 2.0 + elbowFlare, y: (shoulderR.y + handR.y) / 2.0 + (isPullingUp ? 3.5 : 1.0)))
        context.stroke(armR, with: .color(outlineColor), style: StrokeStyle(lineWidth: 7.0, lineCap: .round, lineJoin: .round))
        context.stroke(armR, with: .color(bodyColor), style: StrokeStyle(lineWidth: 4.0, lineCap: .round, lineJoin: .round))
        
        // 5. Chubby Paws Gripping Notch Lip (Curled over lip, or resting flat when climbing)
        drawChubbyPaw(context: &context, center: handL, size: 8.5, color: bodyColor, outlineColor: outlineColor, isGripping: !isClimbingUp)
        drawChubbyPaw(context: &context, center: handR, size: 8.5, color: bodyColor, outlineColor: outlineColor, isGripping: !isClimbingUp)
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
        
        let lFootPt = pose.leftLeg.end
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
        
        // 3. Back Limbs
        let backTone = bodyColor.opacity(0.88)
        let limbThickness: CGFloat = 5.5
        
        if pose.drawsLegs {
            let rHipPt = torso.rightHipAnchor
            let rKneePt = pose.rightLeg.joint
            drawChubbyLimb(context: &context, p1: rHipPt, p2: rKneePt, p3: rFootPt, thickness: limbThickness, color: backTone, outlineColor: outlineColor)
            let footPos = CGPoint(x: rFootPt.x, y: min(rFootPt.y, rootPt.y + 10.0))
            drawChubbyFoot(context: &context, center: footPos, angle: 0, size: 8.0, color: backTone, soleColor: soleColor, outlineColor: outlineColor)
        }
        
        if pose.drawsArms {
            drawChubbyLimb(context: &context, p1: rShoulderPt, p2: rElbowPt, p3: rHandPt, thickness: limbThickness, color: backTone, outlineColor: outlineColor)
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
            let lHipPt = torso.leftHipAnchor
            let lKneePt = pose.leftLeg.joint
            drawChubbyLimb(context: &context, p1: lHipPt, p2: lKneePt, p3: lFootPt, thickness: limbThickness, color: bodyColor, outlineColor: outlineColor)
            let footPos = CGPoint(x: lFootPt.x, y: min(lFootPt.y, rootPt.y + 10.0))
            drawChubbyFoot(context: &context, center: footPos, angle: 0, size: 8.0, color: bodyColor, soleColor: soleColor, outlineColor: outlineColor)
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
        
        let lightCenter = CGPoint(x: root.x - torsoWidth * 0.20, y: root.y - torsoHeight * 0.6)
        context.fill(path, with: .radialGradient(volumetricGradient(for: skin), center: lightCenter, startRadius: 1, endRadius: torsoHeight * 0.8))
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
        let lightCenter = CGPoint(x: head.x - headW * 0.20, y: head.y - headH * 0.25)
        context.fill(shape, with: .radialGradient(volumetricGradient(for: skin), center: lightCenter, startRadius: 1, endRadius: headW * 0.65))
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
    
    // MARK: - Extra Props (Typing Mimic & Music Groove)
    private func drawMiniLaptop(
        context: inout GraphicsContext,
        position: CGPoint
    ) {
        let laptopW: CGFloat = 22.0
        let baseH: CGFloat = 3.5
        let screenH: CGFloat = 14.0
        
        // Base plate on ledge
        let baseRect = CGRect(x: position.x - laptopW / 2.0, y: position.y - baseH, width: laptopW, height: baseH)
        let basePath = Path(roundedRect: baseRect, cornerRadius: 1.5)
        context.fill(basePath, with: .color(Color(red: 0.75, green: 0.77, blue: 0.82)))
        context.stroke(basePath, with: .color(Color(red: 0.25, green: 0.27, blue: 0.32)), lineWidth: 1.2)
        
        // Keyboard surface lines
        let kbRect = CGRect(x: position.x - laptopW * 0.4, y: position.y - baseH + 0.8, width: laptopW * 0.8, height: 1.6)
        context.fill(Path(roundedRect: kbRect, cornerRadius: 0.6), with: .color(Color(red: 0.35, green: 0.37, blue: 0.42)))
        
        // Screen (tilted up and slightly back)
        var screenPath = Path()
        screenPath.move(to: CGPoint(x: position.x - laptopW / 2.0 + 1.5, y: position.y - baseH))
        screenPath.addLine(to: CGPoint(x: position.x - laptopW / 2.0 + 3.0, y: position.y - baseH - screenH))
        screenPath.addLine(to: CGPoint(x: position.x + laptopW / 2.0 - 3.0, y: position.y - baseH - screenH))
        screenPath.addLine(to: CGPoint(x: position.x + laptopW / 2.0 - 1.5, y: position.y - baseH))
        screenPath.closeSubpath()
        
        context.fill(screenPath, with: .color(Color(red: 0.15, green: 0.18, blue: 0.24)))
        context.stroke(screenPath, with: .color(Color(red: 0.25, green: 0.27, blue: 0.32)), lineWidth: 1.2)
        
        // Screen glow display
        let glowRect = CGRect(x: position.x - laptopW * 0.32, y: position.y - baseH - screenH + 2.0, width: laptopW * 0.64, height: screenH - 3.5)
        context.fill(Path(roundedRect: glowRect, cornerRadius: 1.0), with: .color(Color(red: 0.40, green: 0.75, blue: 0.95).opacity(0.85)))
        
        // Code lines on screen
        for i in 0..<3 {
            let lineY = position.y - baseH - screenH + 4.5 + CGFloat(i) * 3.0
            var codeLine = Path()
            codeLine.move(to: CGPoint(x: position.x - laptopW * 0.25, y: lineY))
            codeLine.addLine(to: CGPoint(x: position.x + laptopW * 0.20 - CGFloat(i) * 2.0, y: lineY))
            context.stroke(codeLine, with: .color(Color.white.opacity(0.9)), lineWidth: 1.0)
        }
    }
    
    private func drawMiniHeadphones(
        context: inout GraphicsContext,
        head: CGPoint,
        skin: CompanionSkin
    ) {
        let headW: CGFloat = 36.0
        let headH: CGFloat = 30.0
        let bandColor = Color(red: 0.20, green: 0.22, blue: 0.26)
        let cupColor = skin == .cyber ? Color(red: 0.15, green: 0.35, blue: 0.55) : Color(red: 0.25, green: 0.22, blue: 0.28)
        let ringColor = skin.accentColor
        
        // Headband arching over top of head
        var bandPath = Path()
        bandPath.move(to: CGPoint(x: head.x - headW * 0.45, y: head.y - headH * 0.05))
        bandPath.addQuadCurve(
            to: CGPoint(x: head.x + headW * 0.45, y: head.y - headH * 0.05),
            control: CGPoint(x: head.x, y: head.y - headH * 0.65)
        )
        context.stroke(bandPath, with: .color(bandColor), style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
        
        // Left ear cup
        let cupW: CGFloat = 6.0
        let cupH: CGFloat = 11.0
        let cupLRect = CGRect(x: head.x - headW * 0.48 - cupW / 2.0, y: head.y - headH * 0.05 - cupH / 2.0, width: cupW, height: cupH)
        let cupLPath = Path(roundedRect: cupLRect, cornerRadius: 3.0)
        context.fill(cupLPath, with: .color(cupColor))
        context.stroke(cupLPath, with: .color(skin.outlineColor), lineWidth: 1.2)
        context.stroke(Path(ellipseIn: cupLRect.insetBy(dx: 1.2, dy: 2.0)), with: .color(ringColor), lineWidth: 1.0)
        
        // Right ear cup
        let cupRRect = CGRect(x: head.x + headW * 0.48 - cupW / 2.0, y: head.y - headH * 0.05 - cupH / 2.0, width: cupW, height: cupH)
        let cupRPath = Path(roundedRect: cupRRect, cornerRadius: 3.0)
        context.fill(cupRPath, with: .color(cupColor))
        context.stroke(cupRPath, with: .color(skin.outlineColor), lineWidth: 1.2)
        context.stroke(Path(ellipseIn: cupRRect.insetBy(dx: 1.2, dy: 2.0)), with: .color(ringColor), lineWidth: 1.0)
        
        // Floating musical notes ♪ ♫
        let time = KinematicEngine.shared.behaviorTime
        let noteSymbols = ["♪", "♫", "♩"]
        for i in 0..<3 {
            let phase = (time * 1.5 + Double(i) * 1.1).truncatingRemainder(dividingBy: 3.0)
            let progress = CGFloat(phase / 3.0)
            let xSide: CGFloat = (i % 2 == 0) ? 1.0 : -1.0
            let xOffset = xSide * (headW * 0.55 + progress * 14.0) + sin(progress * .pi * 2.0) * 3.0
            let yOffset = -headH * 0.2 - progress * 22.0
            let opacity = Double(sin(progress * .pi))
            let noteText = Text(noteSymbols[i])
                .font(.system(size: 11.0 + CGFloat(i) * 2.0, weight: .bold, design: .rounded))
                .foregroundColor(skin.accentColor.opacity(opacity))
            context.draw(noteText, at: CGPoint(x: head.x + xOffset, y: head.y + yOffset))
        }
    }
}
