import Foundation
import SwiftUI
import AppKit

// MARK: - Perceptually Uniform OKLab Color Model
public struct OKLabColor: Sendable, Equatable {
    public var l: CGFloat // Perceived lightness [0, 1]
    public var a: CGFloat // Green (-) to Red (+)
    public var b: CGFloat // Blue (-) to Yellow (+)
    
    public init(l: CGFloat, a: CGFloat, b: CGFloat) {
        self.l = l
        self.a = a
        self.b = b
    }
    
    // Convert standard sRGB [0, 1] to OKLab
    public static func from(rgb: (CGFloat, CGFloat, CGFloat)) -> OKLabColor {
        // Step 1: Linearize sRGB
        func linearize(_ c: CGFloat) -> CGFloat {
            let clamped = max(0, min(1, c))
            return clamped <= 0.04045 ? clamped / 12.92 : pow((clamped + 0.055) / 1.055, 2.4)
        }
        
        let r = linearize(rgb.0)
        let g = linearize(rgb.1)
        let b = linearize(rgb.2)
        
        // Step 2: Convert to LMS cone responses
        let l_ = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
        let m_ = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
        let s_ = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
        
        // Step 3: Non-linear cube root compression
        let l_c = cbrt(Double(l_))
        let m_c = cbrt(Double(m_))
        let s_c = cbrt(Double(s_))
        
        // Step 4: Convert to OKLab
        let l = CGFloat(0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720404 * s_c)
        let a = CGFloat(1.9779984951 * l_c - 2.4285922050 * m_c + 0.4505937099 * s_c)
        let b_val = CGFloat(0.0259040371 * l_c + 0.7827717662 * m_c - 0.8086757660 * s_c)
        
        return OKLabColor(l: l, a: a, b: b_val)
    }
    
    // Convert OKLab back to standard sRGB [0, 1]
    public func toRGB() -> (CGFloat, CGFloat, CGFloat) {
        let l_ = Double(l) + 0.3963377774 * Double(a) + 0.2158037573 * Double(b)
        let m_ = Double(l) - 0.1055613458 * Double(a) - 0.0638541728 * Double(b)
        let s_ = Double(l) - 0.0894841775 * Double(a) - 1.2914855480 * Double(b)
        
        let l_cubed = l_ * l_ * l_
        let m_cubed = m_ * m_ * m_
        let s_cubed = s_ * s_ * s_
        
        let r_lin = CGFloat(+4.0767416621 * l_cubed - 3.3077115913 * m_cubed + 0.2309699292 * s_cubed)
        let g_lin = CGFloat(-1.2684380046 * l_cubed + 2.6097574011 * m_cubed - 0.3413193965 * s_cubed)
        let b_lin = CGFloat(-0.0041960863 * l_cubed - 0.7034186147 * m_cubed + 1.7076147010 * s_cubed)
        
        func delinearize(_ c: CGFloat) -> CGFloat {
            let clamped = max(0, min(1, c))
            return clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
        }
        
        return (delinearize(r_lin), delinearize(g_lin), delinearize(b_lin))
    }
    
    // Perceptually uniform blend between two colors
    public static func blend(_ c1: OKLabColor, _ c2: OKLabColor, progress: CGFloat) -> OKLabColor {
        let t = max(0, min(1, progress))
        return OKLabColor(
            l: c1.l + (c2.l - c1.l) * t,
            a: c1.a + (c2.a - c1.a) * t,
            b: c1.b + (c2.b - c1.b) * t
        )
    }
}

// MARK: - WCAG AA/AAA Contrast Guard
public struct ContrastGuard {
    // Relative luminance according to WCAG 2.1 specifications
    public static func relativeLuminance(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
        func linearize(_ c: CGFloat) -> CGFloat {
            let clamped = max(0, min(1, c))
            return clamped <= 0.04045 ? clamped / 12.92 : pow((clamped + 0.055) / 1.055, 2.4)
        }
        let lr = linearize(r)
        let lg = linearize(g)
        let lb = linearize(b)
        return 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
    }
    
    // Computes (L1 + 0.05) / (L2 + 0.05)
    public static func contrastRatio(lum1: CGFloat, lum2: CGFloat) -> CGFloat {
        let lighter = max(lum1, lum2)
        let darker = min(lum1, lum2)
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    // Guarantee contrast >= 4.5:1 against target text luminance (default: white text, L=1.0)
    public static func ensureContrast(
        background: (CGFloat, CGFloat, CGFloat),
        forTextLuminance textLum: CGFloat = 1.0,
        minRatio: CGFloat = 4.5
    ) -> (CGFloat, CGFloat, CGFloat) {
        let bgLum = relativeLuminance(r: background.0, g: background.1, b: background.2)
        let currentRatio = contrastRatio(lum1: textLum, lum2: bgLum)
        
        if currentRatio >= minRatio {
            return background
        }
        
        if textLum >= 0.5 {
            // Light text: Background must be darkened
            let targetMaxLum = max(0.005, (textLum + 0.05) / minRatio - 0.05)
            let scale = sqrt(targetMaxLum / max(0.0001, bgLum))
            return (
                max(0, min(1, background.0 * scale)),
                max(0, min(1, background.1 * scale)),
                max(0, min(1, background.2 * scale))
            )
        } else {
            // Dark text: Background must be lightened
            let targetMinLum = minRatio * (textLum + 0.05) - 0.05
            let scale = max(1.0, sqrt(targetMinLum / max(0.0001, bgLum)))
            return (
                max(0, min(1, background.0 * scale)),
                max(0, min(1, background.1 * scale)),
                max(0, min(1, background.2 * scale))
            )
        }
    }
}
