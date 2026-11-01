import SwiftUI
import AppKit

// MARK: - Procedural Vector Creature Sprite & Rig
public struct CreatureRigView: View {
    @ObservedObject var coordinator = CompanionCoordinator.shared
    @ObservedObject var store = SettingsStore.shared
    
    public init() {}
    
    private var skin: CompanionSkin {
        store.companionSkin
    }
    
    public var body: some View {
        ZStack {
            // Background Aura / Soft Ambient Shadow
            Ellipse()
                .fill(Color.black.opacity(coordinator.shadowOpacity))
                .frame(width: 38, height: 8)
                .offset(y: coordinator.shadowOffsetY)
                .blur(radius: 2)
            
            // Main Body Rig
            VStack(spacing: 0) {
                ZStack {
                    // Skin-Specific Head Accessories (Ears / Antennas / Spines)
                    accessoryLayer
                    
                    // Main Squishy Body
                    bodyShape
                    
                    // Face: Eyes, Blush & Visor
                    faceLayer
                    
                    // Hands / Paws
                    pawsLayer
                    
                    // Prop Layer (Headphones, Laptop, Coffee)
                    propsLayer
                }
                .frame(width: 44, height: 42)
                
                // Feet / Little Legs
                feetLayer
            }
            .scaleEffect(x: coordinator.bodySquashX, y: coordinator.bodyStretchY, anchor: .bottom)
            .rotationEffect(.degrees(coordinator.bodyTiltAngle + coordinator.backflipAngle))
            .offset(x: coordinator.creaturePosition.x, y: coordinator.creaturePosition.y)
            .contentShape(Rectangle())
            .onHover { hovering in
                coordinator.onCursorHover(hovering)
            }
            .onTapGesture {
                coordinator.performTapCelebration()
            }
            
            // Floating Particle Overlays
            particleOverlay
        }
        .frame(width: 140, height: 90)
    }
    
    // MARK: - Body Shape
    private var bodyShape: some View {
        RoundedRectangle(cornerRadius: skin == .pixel ? 6 : 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        skin.primaryColor,
                        skin.primaryColor.opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: skin == .pixel ? 6 : 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: skin.accentColor.opacity(skin == .cyber ? 0.35 : 0.12), radius: skin == .cyber ? 6 : 2)
    }
    
    // MARK: - Accessories (Cat Ears, Dino Spines, Antenna, Visor)
    @ViewBuilder
    private var accessoryLayer: some View {
        switch skin {
        case .kuro:
            // Pointed Cat Ears
            HStack(spacing: 18) {
                CatEarShape()
                    .fill(skin.primaryColor)
                    .frame(width: 11, height: 12)
                    .overlay(
                        CatEarShape()
                            .fill(skin.accentColor.opacity(0.4))
                            .frame(width: 6, height: 7)
                            .offset(y: 2)
                    )
                CatEarShape()
                    .fill(skin.primaryColor)
                    .frame(width: 11, height: 12)
                    .overlay(
                        CatEarShape()
                            .fill(skin.accentColor.opacity(0.4))
                            .frame(width: 6, height: 7)
                            .offset(y: 2)
                    )
            }
            .offset(y: -23)
            
        case .boba:
            // Dino Back Spines
            HStack(spacing: 7) {
                TriangleShape().fill(Color.orange).frame(width: 8, height: 7)
                TriangleShape().fill(Color.orange).frame(width: 9, height: 8)
                TriangleShape().fill(Color.orange).frame(width: 8, height: 7)
            }
            .offset(y: -22)
            
        case .pixel:
            // Retro 8-Bit Antenna
            VStack(spacing: 0) {
                Rectangle().fill(skin.accentColor).frame(width: 4, height: 4)
                Rectangle().fill(Color.gray).frame(width: 2, height: 6)
            }
            .offset(y: -24)
            
        case .cyber:
            // Robot Antenna with Pulsing Beacon
            ZStack {
                Capsule().fill(Color(white: 0.3)).frame(width: 3, height: 9)
                Circle().fill(skin.accentColor).frame(width: 5, height: 5).offset(y: -6)
            }
            .offset(y: -24)
            
        case .mochi:
            // Soft Fluffy Cheeks
            EmptyView()
        }
    }
    
    // MARK: - Face Layer
    @ViewBuilder
    private var faceLayer: some View {
        if skin == .cyber {
            // LED Visor Display
            ZStack {
                Capsule()
                    .fill(Color(red: 0.05, green: 0.08, blue: 0.12))
                    .frame(width: 32, height: 13)
                    .overlay(Capsule().strokeBorder(skin.accentColor.opacity(0.8), lineWidth: 1))
                
                if coordinator.state == .sleeping {
                    Text("- -")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(skin.accentColor)
                } else {
                    HStack(spacing: 8) {
                        Circle().fill(skin.accentColor).frame(width: 4, height: 4)
                        Circle().fill(skin.accentColor).frame(width: 4, height: 4)
                    }
                }
            }
            .offset(y: -2)
        } else {
            // Organic Cartoon Face
            VStack(spacing: 3) {
                // Eyes & Blush Row
                ZStack {
                    // Soft Pink Blush
                    HStack(spacing: 22) {
                        Circle().fill(skin.accentColor.opacity(0.45)).frame(width: 6, height: 4)
                        Circle().fill(skin.accentColor.opacity(0.45)).frame(width: 6, height: 4)
                    }
                    .offset(y: 2)
                    
                    // Eyes
                    if coordinator.state == .sleeping {
                        // Sleeping Curved Eyelids (^_^)
                        HStack(spacing: 12) {
                            Text("~").font(.system(size: 11, weight: .bold)).foregroundColor(eyeColor)
                            Text("~").font(.system(size: 11, weight: .bold)).foregroundColor(eyeColor)
                        }
                    } else if coordinator.blinkPhase {
                        // Blinking Horizontal Slits
                        HStack(spacing: 14) {
                            Capsule().fill(eyeColor).frame(width: 6, height: 1.5)
                            Capsule().fill(eyeColor).frame(width: 6, height: 1.5)
                        }
                    } else if coordinator.state == .dangling || coordinator.state == .slipping {
                        // Wide Panicked / Surprised Eyes (O_O)
                        HStack(spacing: 12) {
                            Circle().fill(eyeColor).frame(width: 7, height: 7)
                                .overlay(Circle().fill(Color.white).frame(width: 2.5, height: 2.5).offset(x: 1, y: -1))
                            Circle().fill(eyeColor).frame(width: 7, height: 7)
                                .overlay(Circle().fill(Color.white).frame(width: 2.5, height: 2.5).offset(x: 1, y: -1))
                        }
                    } else {
                        // Default Curious Expressive Eyes
                        HStack(spacing: 13) {
                            Circle().fill(eyeColor).frame(width: 5, height: 5.5)
                                .overlay(Circle().fill(Color.white).frame(width: 1.8, height: 1.8).offset(x: 1, y: -1))
                            Circle().fill(eyeColor).frame(width: 5, height: 5.5)
                                .overlay(Circle().fill(Color.white).frame(width: 1.8, height: 1.8).offset(x: 1, y: -1))
                        }
                    }
                }
                
                // Cute Tiny Mouth
                if coordinator.state == .celebrating {
                    Circle().strokeBorder(eyeColor, lineWidth: 1.2).frame(width: 4, height: 4)
                } else if coordinator.state == .slipping || coordinator.state == .dangling {
                    Capsule().fill(eyeColor).frame(width: 5, height: 4)
                } else {
                    Text("w")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundColor(eyeColor.opacity(0.8))
                        .offset(y: -1)
                }
            }
            .offset(y: -1)
        }
    }
    
    private var eyeColor: Color {
        skin == .kuro ? skin.accentColor : Color(red: 0.12, green: 0.12, blue: 0.15)
    }
    
    // MARK: - Paws Layer
    @ViewBuilder
    private var pawsLayer: some View {
        if coordinator.state == .dangling {
            // Paws gripping tight to notch top edge
            HStack(spacing: 24) {
                Capsule().fill(skin.primaryColor).frame(width: 8, height: 12).offset(y: -18)
                Capsule().fill(skin.primaryColor).frame(width: 8, height: 12).offset(y: -18)
            }
        } else if coordinator.state == .typingMimic {
            // Typing paws alternating frantically
            HStack(spacing: 10) {
                Capsule()
                    .fill(skin.primaryColor)
                    .frame(width: 7, height: 8)
                    .offset(y: coordinator.typingPawAlternate ? 10 : 7)
                Capsule()
                    .fill(skin.primaryColor)
                    .frame(width: 7, height: 8)
                    .offset(y: coordinator.typingPawAlternate ? 7 : 10)
            }
        } else if coordinator.state == .peekingLeft || coordinator.state == .peekingRight {
            // Peek paws resting over notch curve
            HStack(spacing: 18) {
                Circle().fill(skin.primaryColor).frame(width: 7, height: 7).offset(y: 8)
                Circle().fill(skin.primaryColor).frame(width: 7, height: 7).offset(y: 8)
            }
        } else {
            // Natural resting side paws
            HStack(spacing: 34) {
                Circle().fill(skin.primaryColor).frame(width: 6, height: 6).offset(y: 6)
                Circle().fill(skin.primaryColor).frame(width: 6, height: 6).offset(y: 6)
            }
        }
    }
    
    // MARK: - Feet Layer
    @ViewBuilder
    private var feetLayer: some View {
        if coordinator.state == .dangling {
            // Flailing little kicking legs while dangling
            HStack(spacing: 14) {
                Capsule()
                    .fill(skin.primaryColor.opacity(0.95))
                    .frame(width: 6, height: 10)
                    .rotationEffect(.degrees(sin(coordinator.flailPhase) * 25))
                Capsule()
                    .fill(skin.primaryColor.opacity(0.95))
                    .frame(width: 6, height: 10)
                    .rotationEffect(.degrees(-sin(coordinator.flailPhase) * 25))
            }
            .offset(y: -2)
        } else if coordinator.state == .walking {
            // Stepping feet while walking
            HStack(spacing: 16) {
                Capsule()
                    .fill(skin.primaryColor.opacity(0.95))
                    .frame(width: 7, height: 6)
                    .offset(y: sin(coordinator.walkPhase) > 0 ? -2 : 0)
                Capsule()
                    .fill(skin.primaryColor.opacity(0.95))
                    .frame(width: 7, height: 6)
                    .offset(y: sin(coordinator.walkPhase) <= 0 ? -2 : 0)
            }
            .offset(y: -2)
        } else if coordinator.state != .peekingLeft && coordinator.state != .peekingRight && coordinator.state != .inDen {
            // Small standing paws
            HStack(spacing: 16) {
                Capsule().fill(skin.primaryColor.opacity(0.95)).frame(width: 7, height: 5)
                Capsule().fill(skin.primaryColor.opacity(0.95)).frame(width: 7, height: 5)
            }
            .offset(y: -2)
        }
    }
    
    // MARK: - Props Layer
    @ViewBuilder
    private var propsLayer: some View {
        if coordinator.state == .typingMimic {
            // Miniature glowing typewriter / laptop
            MiniLaptopProp()
                .offset(y: 12)
        } else if coordinator.state == .musicGroove {
            // Miniature DJ Headphones
            MiniHeadphonesProp(color: skin.accentColor)
                .offset(y: -2)
        }
    }
    
    // MARK: - Floating Particles Overlay
    private var particleOverlay: some View {
        ZStack {
            // Music Notes
            ForEach(coordinator.musicalNotes) { note in
                Text(note.symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(skin.accentColor)
                    .offset(x: note.x, y: note.y)
                    .opacity(note.opacity)
            }
            
            // Sleep Zzz
            ForEach(coordinator.sleepZzzs) { z in
                Text("Z")
                    .font(.system(size: z.size, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(z.opacity))
                    .offset(x: z.x, y: z.y)
            }
            
            // Celebration Stars
            ForEach(coordinator.celebrationStars) { star in
                Image(systemName: "sparkle")
                    .font(.system(size: star.size))
                    .foregroundColor(Color.yellow)
                    .offset(x: star.x, y: star.y)
                    .opacity(star.opacity)
            }
        }
    }
}

// MARK: - Cat Ear Shape
struct CatEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Triangle Shape
struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Mini Laptop Prop
struct MiniLaptopProp: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(white: 0.25))
                .frame(width: 18, height: 2)
            
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 15, height: 10)
                .offset(y: -6)
                .rotation3DEffect(.degrees(15), axis: (x: 1, y: 0, z: 0))
        }
    }
}

// MARK: - Mini Headphones Prop
struct MiniHeadphonesProp: View {
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color(white: 0.3), lineWidth: 2)
                .frame(width: 38, height: 38)
                .clipShape(Rectangle().offset(y: -10))
            
            HStack(spacing: 34) {
                Capsule().fill(color).frame(width: 5, height: 11)
                Capsule().fill(color).frame(width: 5, height: 11)
            }
            .offset(y: 4)
        }
    }
}
