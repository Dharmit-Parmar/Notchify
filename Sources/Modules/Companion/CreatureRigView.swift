import SwiftUI
import AppKit

// MARK: - Procedural Vector Kinematic Skeleton Renderer
public struct CreatureRigView: View {
    @ObservedObject var coordinator = CompanionCoordinator.shared
    @ObservedObject var store = SettingsStore.shared
    @ObservedObject var engine = KinematicEngine.shared
    
    public init() {}
    
    private var skin: CompanionSkin {
        store.companionSkin
    }
    
    public var body: some View {
        TimelineView(.animation(paused: coordinator.state == .inDen)) { timelineContext in
            Canvas { context, size in
                // Zero CPU / early exit if in den
                guard coordinator.state != .inDen else { return }
                
                renderSkeleton(
                    context: &context,
                    pose: engine.currentPose,
                    skin: skin,
                    debugSkeleton: store.companionDebugSkeleton || engine.currentPose.debugSkeleton
                )
            }
            .onChange(of: timelineContext.date) { _, _ in
                guard coordinator.state != .inDen else { return }
                
                let mouseScreen = NSEvent.mouseLocation
                let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]
                let cursorX = mouseScreen.x - screen.frame.origin.x
                let cursorY = screen.frame.maxY - mouseScreen.y
                let cursorScreenPos = CGPoint(x: cursorX, y: cursorY)
                
                engine.update(
                    deltaTime: 1.0 / 60.0,
                    cursorScreenPos: cursorScreenPos
                )
                
                CompanionPanel.shared?.clickPanel?.updatePosition(pose: engine.currentPose, screen: screen)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
    
    // MARK: - Core Single-Pass Vector Canvas Drawing Engine
    private func renderSkeleton(
        context: inout GraphicsContext,
        pose: SkeletonPose,
        skin: CompanionSkin,
        debugSkeleton: Bool
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
        
        // 1. Contact Shadow on Ledge Line (fades when dangling or jumping)
        if rootPt.y <= engine.ledgeY + 4.0 && rootPt.y >= 0 {
            let shadowDist = max(0, engine.ledgeY - rootPt.y)
            let shadowOpacity = max(0.0, min(0.35, 0.35 - Double(shadowDist) * 0.015))
            let shadowRect = CGRect(
                x: rootPt.x - 14,
                y: engine.ledgeY - 2,
                width: 28,
                height: 5
            )
            context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(shadowOpacity)))
        }
        
        // 2. Tail (Physics Curvature)
        drawTail(context: &context, root: rootPt, facingRight: pose.facingRight, skin: skin)
        
        // 3. Back Limbs (Right limbs if facing right, drawn in slightly shaded tone)
        let backTone = skin.primaryColor.opacity(0.82)
        drawLimb(context: &context, p1: rHipPt, p2: rKneePt, p3: rFootPt, thickness: 4.5, color: backTone)
        drawPaw(context: &context, center: rFootPt, size: 5.5, color: backTone)
        
        drawLimb(context: &context, p1: rShoulderPt, p2: rElbowPt, p3: rHandPt, thickness: 4.0, color: backTone)
        drawHand(context: &context, center: rHandPt, size: 5.0, color: backTone, isClinging: pose.rightArm.isPlantedOrGripping)
        
        // 4. Torso Hull (Bends along spine from hips to neck, anchored to shoulder/hip anchors)
        drawTorso(context: &context, torso: torso, skin: skin)
        
        // 5. Head Rig with Skin Accessories & Facial Features
        drawHead(context: &context, head: headPt, angle: pose.headAngle, pose: pose, skin: skin)
        
        // 6. Front Limbs (Foreground Left limbs, vibrant skin tone)
        let frontTone = skin.primaryColor
        drawLimb(context: &context, p1: lHipPt, p2: lKneePt, p3: lFootPt, thickness: 5.0, color: frontTone)
        drawPaw(context: &context, center: lFootPt, size: 6.0, color: frontTone)
        
        drawLimb(context: &context, p1: lShoulderPt, p2: lElbowPt, p3: lHandPt, thickness: 4.5, color: frontTone)
        drawHand(context: &context, center: lHandPt, size: 5.5, color: frontTone, isClinging: pose.leftArm.isPlantedOrGripping)
        
        // 7. Props (Mini Laptop or Headphones if active)
        if coordinator.state == .typingMimic {
            drawMiniLaptop(context: &context, position: CGPoint(x: rootPt.x, y: engine.ledgeY - 4))
        } else if coordinator.state == .musicGroove {
            drawMiniHeadphones(context: &context, head: headPt, skin: skin)
        }
        
        // 8. Visual Skeleton Rig Debug Overlay
        if debugSkeleton {
            drawDebugSkeletonOverlay(
                context: &context,
                pose: pose
            )
        }
    }
    
    // MARK: - Skeleton Debug Overlay
    private func drawDebugSkeletonOverlay(
        context: inout GraphicsContext,
        pose: SkeletonPose
    ) {
        let torso = pose.torso
        
        // Spine bone
        drawLine(context: &context, from: torso.root, to: torso.neck, color: .green, width: 2.0)
        // Shoulder clavicle
        drawLine(context: &context, from: torso.leftShoulderAnchor, to: torso.rightShoulderAnchor, color: .green, width: 1.5)
        // Pelvis bar
        drawLine(context: &context, from: torso.leftHipAnchor, to: torso.rightHipAnchor, color: .green, width: 1.5)
        // Neck to head
        drawLine(context: &context, from: torso.neck, to: pose.headCenter, color: .green, width: 2.0)
        
        // Left Arm bones (Cyan)
        drawLine(context: &context, from: pose.leftArm.anchor, to: pose.leftArm.joint, color: .cyan, width: 2.0)
        drawLine(context: &context, from: pose.leftArm.joint, to: pose.leftArm.end, color: .cyan, width: 2.0)
        
        // Right Arm bones (Cyan)
        drawLine(context: &context, from: pose.rightArm.anchor, to: pose.rightArm.joint, color: .cyan, width: 2.0)
        drawLine(context: &context, from: pose.rightArm.joint, to: pose.rightArm.end, color: .cyan, width: 2.0)
        
        // Left Leg bones (Yellow)
        drawLine(context: &context, from: pose.leftLeg.anchor, to: pose.leftLeg.joint, color: .yellow, width: 2.0)
        drawLine(context: &context, from: pose.leftLeg.joint, to: pose.leftLeg.end, color: .yellow, width: 2.0)
        
        // Right Leg bones (Yellow)
        drawLine(context: &context, from: pose.rightLeg.anchor, to: pose.rightLeg.joint, color: .yellow, width: 2.0)
        drawLine(context: &context, from: pose.rightLeg.joint, to: pose.rightLeg.end, color: .yellow, width: 2.0)
        
        // Joint Dots
        let jointList: [(CGPoint, Color, CGFloat)] = [
            (torso.root, .white, 3.0),
            (torso.neck, .green, 3.0),
            (pose.headCenter, .white, 3.5),
            (pose.leftArm.anchor, .cyan, 2.5),
            (pose.leftArm.joint, .cyan, 2.5),
            (pose.leftArm.end, .white, 3.0),
            (pose.rightArm.anchor, .cyan, 2.5),
            (pose.rightArm.joint, .cyan, 2.5),
            (pose.rightArm.end, .white, 3.0),
            (pose.leftLeg.anchor, .yellow, 2.5),
            (pose.leftLeg.joint, .yellow, 2.5),
            (pose.leftLeg.end, .white, 3.0),
            (pose.rightLeg.anchor, .yellow, 2.5),
            (pose.rightLeg.joint, .yellow, 2.5),
            (pose.rightLeg.end, .white, 3.0)
        ]
        
        for (pt, col, rad) in jointList {
            let rect = CGRect(x: pt.x - rad, y: pt.y - rad, width: rad * 2, height: rad * 2)
            context.fill(Path(ellipseIn: rect), with: .color(col))
            context.stroke(Path(ellipseIn: rect), with: .color(.black), lineWidth: 0.8)
        }
    }
    
    private func drawLine(context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color, width: CGFloat) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        context.stroke(p, with: .color(color), lineWidth: width)
    }
    
    // MARK: - Vector Drawing Components
    private func drawLimb(
        context: inout GraphicsContext,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint,
        thickness: CGFloat,
        color: Color
    ) {
        var path = Path()
        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func drawPaw(context: inout GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - size / 2.0, y: center.y - size / 2.5, width: size, height: size * 0.75)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }
    
    private func drawHand(
        context: inout GraphicsContext,
        center: CGPoint,
        size: CGFloat,
        color: Color,
        isClinging: Bool
    ) {
        if isClinging {
            // Curled gripping fingers over notch lip
            let rect = CGRect(x: center.x - size / 2.0, y: center.y - 1.5, width: size, height: size * 0.8)
            context.fill(Path(roundedRect: rect, cornerRadius: 2.0), with: .color(color))
        } else {
            let rect = CGRect(x: center.x - size / 2.0, y: center.y - size / 2.0, width: size, height: size)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
    
    private func drawTorso(
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
        
        let torsoWidth: CGFloat = skin == .pixel ? 18.0 : 20.0
        let torsoHeight: CGFloat = max(16.0, spineLength + 8.0)
        let cornerRadius: CGFloat = skin == .pixel ? 4.0 : 9.0
        
        let localRect = CGRect(x: -torsoWidth / 2.0, y: -torsoHeight, width: torsoWidth, height: torsoHeight)
        let path = Path(roundedRect: localRect, cornerRadius: cornerRadius)
        let transformedPath = path.applying(transform)
        
        context.fill(
            transformedPath,
            with: .linearGradient(
                Gradient(colors: [skin.primaryColor, skin.primaryColor.opacity(0.92)]),
                startPoint: CGPoint(x: neck.x, y: neck.y - 10),
                endPoint: CGPoint(x: root.x, y: root.y + 10)
            )
        )
        context.stroke(
            transformedPath,
            with: .color(Color.white.opacity(0.18)),
            lineWidth: 0.8
        )
    }
    
    private func drawHead(
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
        
        // 1. Head Accessories (Ears, Spines, Antenna)
        drawAccessories(context: &context, transform: t, skin: skin)
        
        // 2. Head Squircle Shape
        let headSize: CGFloat = skin == .pixel ? 20.0 : 22.0
        let headRect = CGRect(x: -headSize / 2.0, y: -headSize / 2.0, width: headSize, height: headSize * 0.95)
        let headPath = Path(roundedRect: headRect, cornerRadius: skin == .pixel ? 5.0 : 8.5).applying(t)
        
        context.fill(headPath, with: .color(skin.primaryColor))
        context.stroke(headPath, with: .color(Color.white.opacity(0.2)), lineWidth: 0.8)
        
        // 3. Face Layer (Eyes, Blush, Visor, Mouth)
        if skin == .cyber {
            // LED Visor
            let visorRect = CGRect(x: -8.0, y: -3.5, width: 16.0, height: 7.0)
            let visorPath = Path(roundedRect: visorRect, cornerRadius: 3.5).applying(t)
            context.fill(visorPath, with: .color(Color(red: 0.05, green: 0.08, blue: 0.12)))
            context.stroke(visorPath, with: .color(skin.accentColor.opacity(0.85)), lineWidth: 1.0)
            
            // LED Cyan Eyes
            if pose.leftEyeOpen > 0.2 {
                let eyeL = CGPoint(x: -4.0 + pose.pupilOffset.x * 2.0, y: 0.0 + pose.pupilOffset.y * 1.5)
                context.fill(Path(ellipseIn: CGRect(x: eyeL.x - 1.5, y: eyeL.y - 1.5, width: 3, height: 3)).applying(t), with: .color(skin.accentColor))
            }
            if pose.rightEyeOpen > 0.2 {
                let eyeR = CGPoint(x: 4.0 + pose.pupilOffset.x * 2.0, y: 0.0 + pose.pupilOffset.y * 1.5)
                context.fill(Path(ellipseIn: CGRect(x: eyeR.x - 1.5, y: eyeR.y - 1.5, width: 3, height: 3)).applying(t), with: .color(skin.accentColor))
            }
        } else {
            // Organic Eyes & Blush
            // Soft Pink Blush
            let blushL = CGRect(x: -8.5, y: 2.0, width: 3.5, height: 2.5)
            let blushR = CGRect(x: 5.0, y: 2.0, width: 3.5, height: 2.5)
            context.fill(Path(ellipseIn: blushL).applying(t), with: .color(skin.accentColor.opacity(0.45)))
            context.fill(Path(ellipseIn: blushR).applying(t), with: .color(skin.accentColor.opacity(0.45)))
            
            let eyeColor = skin == .kuro ? skin.accentColor : Color(red: 0.12, green: 0.12, blue: 0.15)
            
            // Left Eye
            if pose.leftEyeOpen <= 0.2 {
                // Blink line
                var p = Path()
                p.move(to: CGPoint(x: -7, y: 0))
                p.addLine(to: CGPoint(x: -3, y: 0))
                context.stroke(p.applying(t), with: .color(eyeColor), lineWidth: 1.2)
            } else {
                let h = 4.5 * pose.leftEyeOpen
                let eyeRect = CGRect(x: -7.0, y: -h / 2.0, width: 4.0, height: h)
                context.fill(Path(ellipseIn: eyeRect).applying(t), with: .color(eyeColor))
                // White specular pupil shine
                let pupil = CGPoint(x: -5.0 + pose.pupilOffset.x * 1.2, y: pose.pupilOffset.y * 1.2)
                context.fill(Path(ellipseIn: CGRect(x: pupil.x - 0.8, y: pupil.y - 0.8, width: 1.6, height: 1.6)).applying(t), with: .color(.white))
            }
            
            // Right Eye
            if pose.rightEyeOpen <= 0.2 {
                // Blink line
                var p = Path()
                p.move(to: CGPoint(x: 3, y: 0))
                p.addLine(to: CGPoint(x: 7, y: 0))
                context.stroke(p.applying(t), with: .color(eyeColor), lineWidth: 1.2)
            } else {
                let h = 4.5 * pose.rightEyeOpen
                let eyeRect = CGRect(x: 3.0, y: -h / 2.0, width: 4.0, height: h)
                context.fill(Path(ellipseIn: eyeRect).applying(t), with: .color(eyeColor))
                let pupil = CGPoint(x: 5.0 + pose.pupilOffset.x * 1.2, y: pose.pupilOffset.y * 1.2)
                context.fill(Path(ellipseIn: CGRect(x: pupil.x - 0.8, y: pupil.y - 0.8, width: 1.6, height: 1.6)).applying(t), with: .color(.white))
            }
            
            // Mouth
            drawMouth(context: &context, transform: t, shape: pose.mouthShape, color: eyeColor)
        }
    }
    
    private func drawMouth(
        context: inout GraphicsContext,
        transform: CGAffineTransform,
        shape: MouthShape,
        color: Color
    ) {
        switch shape {
        case .smile:
            var p = Path()
            p.move(to: CGPoint(x: -2.5, y: 4.0))
            p.addQuadCurve(to: CGPoint(x: 2.5, y: 4.0), control: CGPoint(x: 0, y: 6.5))
            context.stroke(p.applying(transform), with: .color(color), lineWidth: 1.2)
            
        case .gasp:
            let r = CGRect(x: -2.0, y: 3.5, width: 4.0, height: 4.5)
            context.stroke(Path(ellipseIn: r).applying(transform), with: .color(color), lineWidth: 1.2)
            
        case .sigh:
            var p = Path()
            p.move(to: CGPoint(x: -2.5, y: 5.5))
            p.addLine(to: CGPoint(x: 2.5, y: 5.5))
            context.stroke(p.applying(transform), with: .color(color), lineWidth: 1.0)
            
        case .openW, .neutral:
            var p = Path()
            p.move(to: CGPoint(x: -2.0, y: 4.5))
            p.addLine(to: CGPoint(x: 0.0, y: 5.2))
            p.addLine(to: CGPoint(x: 2.0, y: 4.5))
            context.stroke(p.applying(transform), with: .color(color), lineWidth: 1.0)
        }
    }
    
    private func drawAccessories(context: inout GraphicsContext, transform: CGAffineTransform, skin: CompanionSkin) {
        switch skin {
        case .kuro:
            var earL = Path()
            earL.move(to: CGPoint(x: -9, y: -8))
            earL.addLine(to: CGPoint(x: -5, y: -16))
            earL.addLine(to: CGPoint(x: -2, y: -9))
            earL.closeSubpath()
            context.fill(earL.applying(transform), with: .color(skin.primaryColor))
            
            var earR = Path()
            earR.move(to: CGPoint(x: 2, y: -9))
            earR.addLine(to: CGPoint(x: 5, y: -16))
            earR.addLine(to: CGPoint(x: 9, y: -8))
            earR.closeSubpath()
            context.fill(earR.applying(transform), with: .color(skin.primaryColor))
            
        case .boba:
            for xOffset in [-6.0, 0.0, 6.0] {
                var spine = Path()
                spine.move(to: CGPoint(x: xOffset - 2.5, y: -10))
                spine.addLine(to: CGPoint(x: xOffset, y: -15))
                spine.addLine(to: CGPoint(x: xOffset + 2.5, y: -10))
                spine.closeSubpath()
                context.fill(spine.applying(transform), with: .color(.orange))
            }
            
        case .pixel, .cyber:
            var ant = Path()
            ant.move(to: CGPoint(x: 0, y: -9))
            ant.addLine(to: CGPoint(x: 0, y: -16))
            context.stroke(ant.applying(transform), with: .color(Color(white: 0.4)), lineWidth: 2.0)
            context.fill(Path(ellipseIn: CGRect(x: -2.5, y: -19, width: 5, height: 5)).applying(transform), with: .color(skin.accentColor))
            
        case .mochi:
            break
        }
    }
    
    private func drawTail(
        context: inout GraphicsContext,
        root: CGPoint,
        facingRight: Bool,
        skin: CompanionSkin
    ) {
        guard skin == .kuro || skin == .boba else { return }
        let dir: CGFloat = facingRight ? -1.0 : 1.0
        
        var path = Path()
        path.move(to: CGPoint(x: root.x + dir * 4.0, y: root.y + 2.0))
        path.addCurve(
            to: CGPoint(x: root.x + dir * 16.0, y: root.y - 8.0),
            control1: CGPoint(x: root.x + dir * 8.0, y: root.y + 6.0),
            control2: CGPoint(x: root.x + dir * 14.0, y: root.y)
        )
        context.stroke(
            path,
            with: .color(skin == .boba ? Color.green.opacity(0.8) : skin.primaryColor),
            style: StrokeStyle(lineWidth: skin == .boba ? 4.5 : 2.8, lineCap: .round)
        )
    }
    
    private func drawMiniLaptop(context: inout GraphicsContext, position: CGPoint) {
        let base = CGRect(x: position.x - 8, y: position.y - 1.5, width: 16, height: 3)
        context.fill(Path(roundedRect: base, cornerRadius: 1), with: .color(Color(white: 0.3)))
        
        let screen = CGRect(x: position.x - 7, y: position.y - 10, width: 14, height: 9)
        context.fill(Path(roundedRect: screen, cornerRadius: 1.5), with: .color(Color.cyan.opacity(0.85)))
    }
    
    private func drawMiniHeadphones(context: inout GraphicsContext, head: CGPoint, skin: CompanionSkin) {
        var arc = Path()
        arc.addArc(center: head, radius: 12.0, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        context.stroke(arc, with: .color(Color(white: 0.35)), lineWidth: 2.0)
        
        let padL = CGRect(x: head.x - 13.5, y: head.y - 4, width: 3.5, height: 8)
        let padR = CGRect(x: head.x + 10.0, y: head.y - 4, width: 3.5, height: 8)
        context.fill(Path(roundedRect: padL, cornerRadius: 1.5), with: .color(skin.accentColor))
        context.fill(Path(roundedRect: padR, cornerRadius: 1.5), with: .color(skin.accentColor))
    }
}
