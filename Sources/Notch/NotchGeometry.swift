import AppKit
import Foundation

public struct NotchGeometry {
    public let hasPhysicalNotch: Bool
    public let screenFrame: CGRect
    public let topInset: CGFloat
    
    // Physical Notch Cutout Bounds
    public let physicalNotchWidth: CGFloat
    public let physicalNotchHeight: CGFloat
    public let notchCenterX: CGFloat
    
    public static func current(for screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) -> NotchGeometry {
        let frame = screen.frame
        let safeArea = screen.safeAreaInsets
        let hasNotch = safeArea.top > 0
        
        let notchHeight: CGFloat = hasNotch ? safeArea.top : 32.0
        let notchWidth: CGFloat
        
        if hasNotch, let tl = screen.auxiliaryTopLeftArea, let tr = screen.auxiliaryTopRightArea {
            // Precise physical notch calculated from left and right menu bar cutouts
            let measured = tr.origin.x - (tl.origin.x + tl.width)
            notchWidth = measured > 100 ? measured : 185.0
        } else {
            notchWidth = hasNotch ? 185.0 : 160.0
        }
        
        // Exact hardware center of the screen
        let centerX = frame.origin.x + (frame.width / 2.0)
        
        return NotchGeometry(
            hasPhysicalNotch: hasNotch,
            screenFrame: frame,
            topInset: notchHeight,
            physicalNotchWidth: notchWidth,
            physicalNotchHeight: notchHeight,
            notchCenterX: centerX
        )
    }
    
    // Center-Anchored Rect: Always centers on notchCenterX and extends downward
    public func centerRect(width: CGFloat, height: CGFloat) -> CGRect {
        let x = notchCenterX - (width / 2.0)
        let y = screenFrame.origin.y + screenFrame.height - height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
