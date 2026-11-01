import SwiftUI

// MARK: - Companion Skins
public enum CompanionSkin: String, Codable, CaseIterable, Identifiable {
    case mochi = "mochi"
    case kuro = "kuro"
    case boba = "boba"
    case pixel = "pixel"
    case cyber = "cyber"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .mochi: return "Mochi (Fluff)"
        case .kuro: return "Kuro (Cat)"
        case .boba: return "Boba (Dino)"
        case .pixel: return "Pixel (8-Bit)"
        case .cyber: return "Cyber (Bot)"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .mochi: return "Classic warm marshmallow with pink blush"
        case .kuro: return "Midnight obsidian cat with emerald eyes"
        case .boba: return "Matcha green pastel dinosaur with spine bumps"
        case .pixel: return "Nostalgic retro arcade chunky sprite"
        case .cyber: return "Futuristic chrome chassis with cyan LED visor"
        }
    }
    
    public var primaryColor: Color {
        switch self {
        case .mochi: return Color(red: 0.98, green: 0.97, blue: 0.95)
        case .kuro: return Color(red: 0.12, green: 0.12, blue: 0.14)
        case .boba: return Color(red: 0.45, green: 0.82, blue: 0.55)
        case .pixel: return Color(red: 0.95, green: 0.75, blue: 0.25)
        case .cyber: return Color(red: 0.18, green: 0.22, blue: 0.28)
        }
    }
    
    public var bodyColor: Color { primaryColor }
    
    public var eyeColor: Color {
        switch self {
        case .kuro: return accentColor
        case .cyber: return accentColor
        default: return Color(red: 0.12, green: 0.12, blue: 0.15)
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .mochi: return Color(red: 1.0, green: 0.60, blue: 0.70) // Pink blush
        case .kuro: return Color(red: 0.30, green: 0.95, blue: 0.65) // Emerald eyes
        case .boba: return Color(red: 0.98, green: 0.55, blue: 0.50) // Coral belly
        case .pixel: return Color(red: 0.20, green: 0.55, blue: 0.95) // Cyan accents
        case .cyber: return Color(red: 0.20, green: 0.85, blue: 1.0) // Neon cyan visor
        }
    }
}

// MARK: - Companion Activity Frequency
public enum CompanionActivityLevel: String, Codable, CaseIterable, Identifiable {
    case calm = "calm"
    case balanced = "balanced"
    case playful = "playful"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .calm: return "Calm"
        case .balanced: return "Balanced"
        case .playful: return "Playful"
        }
    }
    
    public var description: String {
        switch self {
        case .calm: return "Appears rarely (every 60–120s); mostly snoozes quietly"
        case .balanced: return "Natural pacing (every 30–60s); explores and mimics"
        case .playful: return "Energetic (every 15–30s); frequent peeks, walks and slips"
        }
    }
    
    public var intervalRange: ClosedRange<Double> {
        switch self {
        case .calm: return 60.0...120.0
        case .balanced: return 30.0...60.0
        case .playful: return 15.0...30.0
        }
    }
}

// MARK: - Behavior States
public enum CompanionBehaviorState: Equatable {
    case inDen                      // Hidden inside notch (0% CPU)
    case peekingLeft                // Peeking from left curve of notch
    case peekingRight               // Peeking from right curve of notch
    case walking                    // Walking along notch ledge
    case typingMimic                // Furiously typing on miniature laptop
    case musicGroove                // Head bobbing with miniature headphones
    case slipping                   // Foot slips off ledge
    case dangling                   // Hanging by paws with kicking feet
    case pullingUp                  // Hauling itself back up
    case sleeping                   // Dozing under camera with floating Zzz
    case curious                    // Tilting head curiously
    case celebrating                // Backflip / happy bounce on tap
}
