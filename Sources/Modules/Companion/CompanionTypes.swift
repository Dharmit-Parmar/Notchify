import SwiftUI

// MARK: - Companion Skins
public enum CompanionSkin: String, Codable, CaseIterable, Identifiable {
    case bubu = "bubu"
    case mochi = "mochi"
    case kuro = "kuro"
    case boba = "boba"
    case pixel = "pixel"
    case cyber = "cyber"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .bubu: return "Bubu (Bear)"
        case .mochi: return "Mochi (Fluff)"
        case .kuro: return "Kuro (Cat)"
        case .boba: return "Boba (Dino)"
        case .pixel: return "Pixel (8-Bit)"
        case .cyber: return "Cyber (Bot)"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .bubu: return "Sweet chubby bear with warm cream fur and rosy cheeks"
        case .mochi: return "Classic warm marshmallow with pink blush"
        case .kuro: return "Midnight obsidian cat with emerald eyes"
        case .boba: return "Matcha green pastel dinosaur with spine bumps"
        case .pixel: return "Nostalgic retro arcade chunky sprite"
        case .cyber: return "Futuristic chrome chassis with cyan LED visor"
        }
    }
    
    public var primaryColor: Color {
        switch self {
        case .bubu: return Color(red: 0.99, green: 0.99, blue: 0.98) // Pure warm white
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
        case .bubu: return Color(red: 0.17, green: 0.12, blue: 0.13)
        case .kuro: return accentColor
        case .cyber: return accentColor
        default: return Color(red: 0.17, green: 0.12, blue: 0.13)
        }
    }
    
    public var outlineColor: Color {
        switch self {
        case .kuro: return Color(red: 0.06, green: 0.06, blue: 0.08)
        case .cyber: return Color(red: 0.10, green: 0.12, blue: 0.16)
        default: return Color(red: 0.17, green: 0.12, blue: 0.13)
        }
    }
    
    public var darkAccentColor: Color {
        switch self {
        case .bubu: return Color(red: 0.22, green: 0.14, blue: 0.15) // Dark chocolate ears/pads/band
        case .kuro: return Color(red: 0.08, green: 0.08, blue: 0.10)
        case .mochi: return Color(red: 0.88, green: 0.82, blue: 0.84)
        case .boba: return Color(red: 0.20, green: 0.45, blue: 0.28)
        case .pixel: return Color(red: 0.15, green: 0.15, blue: 0.20)
        case .cyber: return Color(red: 0.10, green: 0.14, blue: 0.20)
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .bubu: return Color(red: 1.0, green: 0.68, blue: 0.71) // Giant rosy pink blush
        case .mochi: return Color(red: 1.0, green: 0.68, blue: 0.71) // Pink blush
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
    case crawling                   // Quadruped low-profile crawl along notch
    case typingMimic                // Furiously typing on miniature laptop
    case musicGroove                // Head bobbing with miniature headphones
    case slipping                   // Foot slips off ledge
    case dangling                   // Hanging by paws with kicking feet
    case pullingUp                  // Hauling itself back up
    case sleeping                   // Dozing under camera with floating Zzz
    case curious                    // Tilting head curiously
    case thinking                   // One hand on chin, watching cursor smoothly
    case celebrating                // Backflip / happy bounce on tap
}
