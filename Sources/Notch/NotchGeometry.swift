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
        
        // Precise hardware notch center derived directly from AppKit auxiliary menu bar cutouts
        let centerX: CGFloat
        if hasNotch, let tl = screen.auxiliaryTopLeftArea, let tr = screen.auxiliaryTopRightArea {
            centerX = (tl.origin.x + tl.width + tr.origin.x) / 2.0
        } else {
            centerX = frame.origin.x + (frame.width / 2.0)
        }
        
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
    
    // MARK: - Pure Expanded-Layout Model (One Source of Truth)
    
    public static func expandedLayout(
        geometry: NotchGeometry,
        notchWidth: CGFloat = 620.0,
        notchHeight: CGFloat = 330.0,
        attachment: NotchPositionAttachment = .hardwareNotch,
        horizontalOffset: CGFloat = 0.0,
        verticalOffset: CGFloat = 0.0,
        dashboardLayoutFlow: DashboardLayoutFlow = .bentoQuad,
        activeWidgetsCount: Int = 2
    ) -> ExpandedLayout {
        let screenFrame = geometry.screenFrame
        
        // Target Width: Respect user setting; expand for 4+ widgets in horizontal strip if needed
        let targetWidth: CGFloat
        if dashboardLayoutFlow == .horizontalStrip && activeWidgetsCount >= 4 {
            targetWidth = max(notchWidth, 720.0)
        } else {
            targetWidth = notchWidth
        }
        
        // Notch Inset and Content Top Padding:
        // Expanded height = notch inset + content height.
        // Content top padding = notch inset.
        let notchInset: CGFloat
        let contentTopPadding: CGFloat
        
        if attachment == .belowMenuBar {
            notchInset = 0.0
            contentTopPadding = 8.0
        } else if geometry.hasPhysicalNotch {
            notchInset = geometry.physicalNotchHeight
            contentTopPadding = geometry.physicalNotchHeight
        } else {
            notchInset = 0.0
            contentTopPadding = 10.0
        }
        
        let contentHeight = max(280.0, notchHeight)
        let totalHeight = notchInset + contentHeight
        
        // Center X: Anchored to hardware notch center + user offset, clamped to screen bounds
        let rawCenterX = geometry.notchCenterX + horizontalOffset
        let minCenterX = screenFrame.minX + (targetWidth / 2.0)
        let maxCenterX = screenFrame.maxX - (targetWidth / 2.0)
        let clampedCenterX = min(max(minCenterX, rawCenterX), maxCenterX)
        let x = clampedCenterX - (targetWidth / 2.0)
        
        // Top Y: Flush with top bezel + user vertical offset, extending downward
        let topY: CGFloat
        switch attachment {
        case .hardwareNotch, .custom:
            topY = screenFrame.maxY + verticalOffset
        case .belowMenuBar:
            topY = screenFrame.maxY - geometry.topInset + verticalOffset
        }
        let clampedTopY = min(screenFrame.maxY, topY)
        let y = clampedTopY - totalHeight
        
        let windowRect = NSRect(x: x, y: y, width: targetWidth, height: totalHeight)
        let contentRect = NSRect(x: x, y: y, width: targetWidth, height: contentHeight)
        let hoverBounds = windowRect.insetBy(dx: -24.0, dy: -14.0)
        
        return ExpandedLayout(
            windowRect: windowRect,
            contentRect: contentRect,
            notchInset: notchInset,
            contentTopPadding: contentTopPadding,
            targetWidth: targetWidth,
            targetHeight: totalHeight,
            hoverBounds: hoverBounds
        )
    }
    
    // MARK: - Pure Collapsed-Layout Model (Phase 1)
    
    public static func collapsedLayout(
        geometry: NotchGeometry,
        style: CompactIndicatorStyle,
        mode: CollapsedNotchMode = .hideBehindNotch,
        attachment: NotchPositionAttachment = .hardwareNotch,
        wingWidth: CGFloat = 56.0,
        collapsedHeight: CGFloat = 34.0,
        horizontalOffset: CGFloat = 0.0,
        verticalOffset: CGFloat = 0.0,
        activeEvents: ActiveNotchEvents = ActiveNotchEvents()
    ) -> CollapsedLayout {
        let screenFrame = geometry.screenFrame
        let targetHeight = max(24.0, min(60.0, collapsedHeight))
        
        let isWingsVisible: Bool
        let effectiveWingWidth: CGFloat
        
        if geometry.hasPhysicalNotch {
            switch mode {
            case .hideBehindNotch:
                isWingsVisible = false
                effectiveWingWidth = 0.0
            case .wingsOnEvents:
                isWingsVisible = activeEvents.hasAnyActiveEvent
                effectiveWingWidth = isWingsVisible ? min(max(0, wingWidth), 160.0) : 0.0
            case .alwaysShowWings:
                isWingsVisible = true
                effectiveWingWidth = min(max(0, wingWidth), 160.0)
            }
            
            // 2 pt overlap on each side to avoid subpixel seams with hardware bezel
            let cutoutWidth = geometry.physicalNotchWidth + 4.0
            let totalContentWidth = cutoutWidth + (effectiveWingWidth * 2.0)
            
            let rawCenterX = geometry.notchCenterX + horizontalOffset
            let minCenterX = screenFrame.minX + (totalContentWidth / 2.0)
            let maxCenterX = screenFrame.maxX - (totalContentWidth / 2.0)
            let clampedCenterX = min(max(minCenterX, rawCenterX), maxCenterX)
            
            let topY: CGFloat
            switch attachment {
            case .hardwareNotch, .custom:
                topY = screenFrame.maxY + verticalOffset
            case .belowMenuBar:
                topY = screenFrame.maxY - geometry.topInset + verticalOffset
            }
            // Strict guard: Never render above the top of the physical screen
            let clampedTopY = min(screenFrame.maxY, topY)
            let contentY = clampedTopY - targetHeight
            let contentX = clampedCenterX - (totalContentWidth / 2.0)
            
            let contentRect = NSRect(x: contentX, y: contentY, width: totalContentWidth, height: targetHeight)
            let windowRect = contentRect
            
            let leftWingRect: NSRect
            let centerCutoutRect: NSRect
            let rightWingRect: NSRect
            
            if isWingsVisible && effectiveWingWidth > 0 {
                leftWingRect = NSRect(x: contentX, y: contentY, width: effectiveWingWidth, height: targetHeight)
                centerCutoutRect = NSRect(x: contentX + effectiveWingWidth, y: contentY, width: cutoutWidth, height: targetHeight)
                rightWingRect = NSRect(x: contentX + effectiveWingWidth + cutoutWidth, y: contentY, width: effectiveWingWidth, height: targetHeight)
            } else {
                leftWingRect = .zero
                centerCutoutRect = contentRect
                rightWingRect = .zero
            }
            
            // Hover trigger covers the full physical notch plus slop
            let hoverWidth = max(totalContentWidth, geometry.physicalNotchWidth + 8.0)
            let hoverX = clampedCenterX - (hoverWidth / 2.0)
            let hoverTriggerRect = NSRect(x: hoverX, y: contentY, width: hoverWidth, height: targetHeight + 4.0)
            
            return CollapsedLayout(
                windowRect: windowRect,
                contentRect: contentRect,
                leftWingRect: leftWingRect,
                centerCutoutRect: centerCutoutRect,
                rightWingRect: rightWingRect,
                hoverTriggerRect: hoverTriggerRect,
                effectiveWingWidth: effectiveWingWidth,
                isWingsVisible: isWingsVisible
            )
        } else {
            // Display without physical notch: centered top pill
            let basePillWidth: CGFloat = 160.0
            let effectiveWings: CGFloat
            switch mode {
            case .hideBehindNotch:
                isWingsVisible = false
                effectiveWings = 0.0
            case .wingsOnEvents:
                isWingsVisible = activeEvents.hasAnyActiveEvent
                effectiveWings = isWingsVisible ? min(max(0, wingWidth), 160.0) : 0.0
            case .alwaysShowWings:
                isWingsVisible = true
                effectiveWings = min(max(0, wingWidth), 160.0)
            }
            
            let totalContentWidth = basePillWidth + (effectiveWings * 2.0)
            let rawCenterX = geometry.notchCenterX + horizontalOffset
            let minCenterX = screenFrame.minX + (totalContentWidth / 2.0)
            let maxCenterX = screenFrame.maxX - (totalContentWidth / 2.0)
            let clampedCenterX = min(max(minCenterX, rawCenterX), maxCenterX)
            
            let topY = screenFrame.maxY + verticalOffset
            let clampedTopY = min(screenFrame.maxY, topY)
            let contentY = clampedTopY - targetHeight
            let contentX = clampedCenterX - (totalContentWidth / 2.0)
            
            let contentRect = NSRect(x: contentX, y: contentY, width: totalContentWidth, height: targetHeight)
            let windowRect = contentRect
            
            let leftWingRect = effectiveWings > 0 ? NSRect(x: contentX, y: contentY, width: effectiveWings, height: targetHeight) : .zero
            let centerCutoutRect = NSRect(x: contentX + effectiveWings, y: contentY, width: basePillWidth, height: targetHeight)
            let rightWingRect = effectiveWings > 0 ? NSRect(x: contentX + effectiveWings + basePillWidth, y: contentY, width: effectiveWings, height: targetHeight) : .zero
            
            let hoverTriggerRect = contentRect.insetBy(dx: -4.0, dy: -2.0)
            
            return CollapsedLayout(
                windowRect: windowRect,
                contentRect: contentRect,
                leftWingRect: leftWingRect,
                centerCutoutRect: centerCutoutRect,
                rightWingRect: rightWingRect,
                hoverTriggerRect: hoverTriggerRect,
                effectiveWingWidth: effectiveWings,
                isWingsVisible: isWingsVisible
            )
        }
    }
}

// MARK: - Active Events for Event-Driven Wings
public struct ActiveNotchEvents: Equatable, Sendable {
    public var isMediaPlaying: Bool
    public var isCharging: Bool
    public var hasActiveTimer: Bool
    public var hasNotification: Bool
    
    public init(
        isMediaPlaying: Bool = false,
        isCharging: Bool = false,
        hasActiveTimer: Bool = false,
        hasNotification: Bool = false
    ) {
        self.isMediaPlaying = isMediaPlaying
        self.isCharging = isCharging
        self.hasActiveTimer = hasActiveTimer
        self.hasNotification = hasNotification
    }
    
    public var hasAnyActiveEvent: Bool {
        isMediaPlaying || isCharging || hasActiveTimer || hasNotification
    }
}

// MARK: - Resolved Collapsed Layout Result
public struct CollapsedLayout: Equatable, Sendable {
    public let windowRect: NSRect
    public let contentRect: NSRect
    public let leftWingRect: NSRect
    public let centerCutoutRect: NSRect
    public let rightWingRect: NSRect
    public let hoverTriggerRect: NSRect
    public let effectiveWingWidth: CGFloat
    public let isWingsVisible: Bool
    
    public init(
        windowRect: NSRect,
        contentRect: NSRect,
        leftWingRect: NSRect,
        centerCutoutRect: NSRect,
        rightWingRect: NSRect,
        hoverTriggerRect: NSRect,
        effectiveWingWidth: CGFloat,
        isWingsVisible: Bool
    ) {
        self.windowRect = windowRect
        self.contentRect = contentRect
        self.leftWingRect = leftWingRect
        self.centerCutoutRect = centerCutoutRect
        self.rightWingRect = rightWingRect
        self.hoverTriggerRect = hoverTriggerRect
        self.effectiveWingWidth = effectiveWingWidth
        self.isWingsVisible = isWingsVisible
    }
}

// MARK: - Resolved Expanded Layout Result (One Source of Truth)
public struct ExpandedLayout: Equatable, Sendable {
    public let windowRect: NSRect
    public let contentRect: NSRect
    public let notchInset: CGFloat
    public let contentTopPadding: CGFloat
    public let targetWidth: CGFloat
    public let targetHeight: CGFloat
    public let hoverBounds: NSRect
    
    public init(
        windowRect: NSRect,
        contentRect: NSRect,
        notchInset: CGFloat,
        contentTopPadding: CGFloat,
        targetWidth: CGFloat,
        targetHeight: CGFloat,
        hoverBounds: NSRect
    ) {
        self.windowRect = windowRect
        self.contentRect = contentRect
        self.notchInset = notchInset
        self.contentTopPadding = contentTopPadding
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        self.hoverBounds = hoverBounds
    }
}
