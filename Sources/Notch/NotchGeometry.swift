import AppKit
import Foundation
import SwiftUI

// MARK: - Dimension Limits & Clamping Constants
public struct NotchDimensionLimits: Sendable {
    public static let minHoverWidth: CGFloat = 40.0
    public static let maxHoverWidth: CGFloat = 380.0
    public static let minHoverHeight: CGFloat = 8.0
    public static let maxHoverHeight: CGFloat = 54.0
    
    public static let minExpandedWidth: CGFloat = 480.0
    public static let maxExpandedWidth: CGFloat = 800.0
    public static let minExpandedHeight: CGFloat = 200.0
    public static let maxExpandedHeight: CGFloat = 540.0
    
    public static let defaultHoverWidth: CGFloat = 210.0
    public static let defaultHoverHeight: CGFloat = 34.0
    public static let defaultExpandedWidth: CGFloat = 620.0
    public static let defaultExpandedHeight: CGFloat = 330.0
    public static let defaultWingWidth: CGFloat = 56.0
}

// MARK: - Dashboard Layout Flow
public enum DashboardLayoutFlow: String, Codable, CaseIterable, Identifiable, Sendable {
    case adaptiveAuto = "adaptiveAuto"
    case horizontalStrip = "horizontalStrip"
    case bentoQuad = "bentoQuad"
    case focusDominant = "focusDominant"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .adaptiveAuto: return "Smart Adaptive"
        case .horizontalStrip: return "4 Side-by-Side (Strip)"
        case .bentoQuad: return "2×2 Bento Grid"
        case .focusDominant: return "Focus (Dominant + Companion)"
        }
    }
    
    public var icon: String {
        switch self {
        case .adaptiveAuto: return "sparkles.square.filled.on.square"
        case .horizontalStrip: return "rectangle.split.3x1"
        case .bentoQuad: return "square.grid.2x2"
        case .focusDominant: return "rectangle.righthalf.inset.filled"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .adaptiveAuto: return "Auto-arranges based on active widgets"
        case .horizontalStrip: return "Single row with quick glances"
        case .bentoQuad: return "Balanced 2-column quad grid"
        case .focusDominant: return "Main focus widget with companion sidebar"
        }
    }
}

// MARK: - Collapsed Notch Width & Wings Mode
public enum CollapsedNotchMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case hideBehindNotch = "Hide behind notch"
    case wingsOnEvents = "Wings on events"
    case alwaysShowWings = "Always show wings"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .hideBehindNotch: return "eye.slash"
        case .wingsOnEvents: return "sparkles"
        case .alwaysShowWings: return "rectangle.expand.vertical"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .hideBehindNotch: return "Pill strictly matches physical cutout; nothing visible outside"
        case .wingsOnEvents: return "Wings slide out only when media, charging or events are active"
        case .alwaysShowWings: return "Wings remain comfortably visible with configured width"
        }
    }
}

// MARK: - Notch Position Attachment
public enum NotchPositionAttachment: String, CaseIterable, Identifiable, Codable, Sendable {
    case hardwareNotch = "Attach to hardware notch"
    case custom = "Custom"
    case belowMenuBar = "Below menu bar"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .hardwareNotch: return "display"
        case .custom: return "slider.horizontal.2.square"
        case .belowMenuBar: return "menubar.arrow.down.rectangle"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .hardwareNotch: return "Anchored flush to the top bezel and hardware cutout"
        case .custom: return "Freely adjusted via offsets and arrow-key nudges"
        case .belowMenuBar: return "Positioned directly below the macOS menu bar strip"
        }
    }
}

// MARK: - Per-Display Position & Size Profile (Versioned Codable)
public struct DisplayPositionProfile: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var wingMode: CollapsedNotchMode = .hideBehindNotch
    public var attachment: NotchPositionAttachment = .hardwareNotch
    public var wingWidth: CGFloat = 56.0
    public var collapsedHeight: CGFloat = 34.0
    public var horizontalOffset: CGFloat = 0.0
    public var verticalOffset: CGFloat = 0.0
    public var customX: CGFloat? = nil
    public var customY: CGFloat? = nil
    
    public init(
        version: Int = 1,
        wingMode: CollapsedNotchMode = .hideBehindNotch,
        attachment: NotchPositionAttachment = .hardwareNotch,
        wingWidth: CGFloat = 56.0,
        collapsedHeight: CGFloat = 34.0,
        horizontalOffset: CGFloat = 0.0,
        verticalOffset: CGFloat = 0.0,
        customX: CGFloat? = nil,
        customY: CGFloat? = nil
    ) {
        self.version = version
        self.wingMode = wingMode
        self.attachment = attachment
        self.wingWidth = wingWidth
        self.collapsedHeight = collapsedHeight
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.customX = customX
        self.customY = customY
    }
}

// MARK: - Collapsed Notch Indicator Style
public enum CompactIndicatorStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case media = "Now Playing"
    case minimal = "Minimal Jewel"
    case battery = "Battery"
    case dateTime = "Clock"
    case circadian = "Solar Status"
    case threeZoneStatusBar = "3-Zone Status Bar"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .media: return "music.note"
        case .minimal: return "circle.fill"
        case .battery: return "battery.100.bolt"
        case .dateTime: return "clock.fill"
        case .circadian: return "sun.max.fill"
        case .threeZoneStatusBar: return "menubar.rectangle"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .media: return Color(red: 0.98, green: 0.35, blue: 0.55) // Living Rose
        case .minimal: return Color(red: 0.35, green: 0.85, blue: 0.98) // Cyan Jewel
        case .battery: return Color(red: 0.40, green: 0.88, blue: 0.45) // Lime Green
        case .dateTime: return Color(red: 0.30, green: 0.65, blue: 1.00) // Electric Blue
        case .circadian: return Color(red: 0.98, green: 0.72, blue: 0.22) // Solar Gold
        case .threeZoneStatusBar: return Color(red: 0.35, green: 0.78, blue: 0.98) // Sky Cyan
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

// MARK: - Pure Layout Return Types
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

public typealias ExpandedLayoutResult = ExpandedLayout
public typealias CollapsedLayoutResult = CollapsedLayout

// MARK: - Production Pure Geometry Model
public struct NotchGeometry: Sendable {
    public typealias ExpandedLayoutResult = ExpandedLayout
    public typealias CollapsedLayoutResult = CollapsedLayout

    public let hasPhysicalNotch: Bool
    public let screenFrame: CGRect
    public let topInset: CGFloat
    
    // Physical Notch Cutout Bounds
    public let physicalNotchWidth: CGFloat
    public let physicalNotchHeight: CGFloat
    public let notchCenterX: CGFloat
    
    public init(
        hasPhysicalNotch: Bool,
        screenFrame: CGRect,
        topInset: CGFloat,
        physicalNotchWidth: CGFloat,
        physicalNotchHeight: CGFloat,
        notchCenterX: CGFloat
    ) {
        self.hasPhysicalNotch = hasPhysicalNotch
        self.screenFrame = screenFrame
        self.topInset = topInset
        self.physicalNotchWidth = physicalNotchWidth
        self.physicalNotchHeight = physicalNotchHeight
        self.notchCenterX = notchCenterX
    }
    
    public init(
        screenFrame: CGRect,
        hasPhysicalNotch: Bool,
        topInset: CGFloat,
        physicalNotchWidth: CGFloat,
        physicalNotchHeight: CGFloat,
        notchCenterX: CGFloat
    ) {
        self.hasPhysicalNotch = hasPhysicalNotch
        self.screenFrame = screenFrame
        self.topInset = topInset
        self.physicalNotchWidth = physicalNotchWidth
        self.physicalNotchHeight = physicalNotchHeight
        self.notchCenterX = notchCenterX
    }
    
#if canImport(AppKit)
    public static func current(for screen: NSScreen? = NSScreen.main ?? NSScreen.screens.first) -> NotchGeometry {
        guard let screen else {
            let fallbackFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
            return NotchGeometry(
                hasPhysicalNotch: false,
                screenFrame: fallbackFrame,
                topInset: 32.0,
                physicalNotchWidth: 160.0,
                physicalNotchHeight: 32.0,
                notchCenterX: fallbackFrame.midX
            )
        }
        let frame = screen.frame
        let safeArea = screen.safeAreaInsets
        let hasNotch = safeArea.top > 0
        
        let notchHeight: CGFloat = hasNotch ? safeArea.top : 32.0
        let notchWidth: CGFloat
        
        if hasNotch, let tl = screen.auxiliaryTopLeftArea, let tr = screen.auxiliaryTopRightArea {
            let measured = tr.origin.x - (tl.origin.x + tl.width)
            notchWidth = measured > 100 ? measured : 185.0
        } else {
            notchWidth = hasNotch ? 185.0 : 160.0
        }
        
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
#endif
    
    public func centerRect(width: CGFloat, height: CGFloat) -> CGRect {
        let x = notchCenterX - (width / 2.0)
        let y = screenFrame.origin.y + screenFrame.height - height
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Pure Expanded-Layout Model
    public static func expandedLayout(
        geometry: NotchGeometry,
        notchWidth: CGFloat = NotchDimensionLimits.defaultExpandedWidth,
        notchHeight: CGFloat = NotchDimensionLimits.defaultExpandedHeight,
        attachment: NotchPositionAttachment = .hardwareNotch,
        horizontalOffset: CGFloat = 0.0,
        verticalOffset: CGFloat = 0.0,
        dashboardLayoutFlow: DashboardLayoutFlow = .bentoQuad,
        activeWidgetsCount: Int = 2,
        quickControlsHeight: CGFloat = 0.0
    ) -> ExpandedLayout {
        let screenFrame = geometry.screenFrame
        let maxTargetWidth = screenFrame.width - 32.0
        
        let targetWidth: CGFloat
        if dashboardLayoutFlow == .horizontalStrip && activeWidgetsCount >= 4 {
            targetWidth = min(max(notchWidth, 720.0), maxTargetWidth)
        } else {
            targetWidth = min(max(NotchDimensionLimits.minExpandedWidth, notchWidth), maxTargetWidth)
        }
        
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
        
        let clampedHeight = min(max(NotchDimensionLimits.minExpandedHeight, notchHeight), NotchDimensionLimits.maxExpandedHeight)
        let contentHeight = max(180.0, clampedHeight + quickControlsHeight)
        let totalHeight = notchInset + contentHeight
        
        let rawCenterX = geometry.notchCenterX + horizontalOffset
        let minCenterX = screenFrame.minX + (targetWidth / 2.0)
        let maxCenterX = screenFrame.maxX - (targetWidth / 2.0)
        let clampedCenterX = min(max(minCenterX, rawCenterX), maxCenterX)
        let x = clampedCenterX - (targetWidth / 2.0)
        
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
    
    // MARK: - Pure Collapsed-Layout Model
    public static func collapsedLayout(
        geometry: NotchGeometry,
        style: CompactIndicatorStyle = .media,
        mode: CollapsedNotchMode = .hideBehindNotch,
        attachment: NotchPositionAttachment = .hardwareNotch,
        wingWidth: CGFloat = NotchDimensionLimits.defaultWingWidth,
        collapsedHeight: CGFloat = NotchDimensionLimits.defaultHoverHeight,
        hoverTriggerWidth: CGFloat = NotchDimensionLimits.defaultHoverWidth,
        hoverTriggerHeight: CGFloat = NotchDimensionLimits.defaultHoverHeight,
        horizontalOffset: CGFloat = 0.0,
        verticalOffset: CGFloat = 0.0,
        activeEvents: ActiveNotchEvents = ActiveNotchEvents()
    ) -> CollapsedLayout {
        let screenFrame = geometry.screenFrame
        let targetHeight = max(NotchDimensionLimits.minHoverHeight, min(60.0, collapsedHeight))
        
        let isWingsVisible: Bool
        let effectiveWingWidth: CGFloat
        
        // Clamped hover sensor dimensions strictly bounded by NotchDimensionLimits
        let effectiveHoverWidth = min(max(NotchDimensionLimits.minHoverWidth, hoverTriggerWidth), NotchDimensionLimits.maxHoverWidth)
        let effectiveHoverHeight = min(max(NotchDimensionLimits.minHoverHeight, hoverTriggerHeight), NotchDimensionLimits.maxHoverHeight)
        
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
            let clampedTopY = min(screenFrame.maxY, topY)
            let contentY = clampedTopY - targetHeight
            let contentX = clampedCenterX - (totalContentWidth / 2.0)
            
            let contentRect = NSRect(x: contentX, y: contentY, width: totalContentWidth, height: targetHeight)
            
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
            
            let hoverX = clampedCenterX - (effectiveHoverWidth / 2.0)
            let hoverY = clampedTopY - effectiveHoverHeight
            let hoverTriggerRect = NSRect(x: hoverX, y: hoverY, width: effectiveHoverWidth, height: effectiveHoverHeight)
            
            // Critical fix: When wings are hidden, windowRect is strictly hoverTriggerRect.
            // This guarantees window frame decreases for all slider values (e.g. 40...380pt width, 8...54pt height)
            // without being held open by unused 189x34 content bounds!
            let windowRect: NSRect
            if isWingsVisible && effectiveWingWidth > 0 {
                windowRect = contentRect.union(hoverTriggerRect)
            } else {
                windowRect = hoverTriggerRect
            }
            
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
            
            // Pill base adapts to compact choices
            let basePillWidth = min(160.0, max(40.0, effectiveHoverWidth))
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
            
            let leftWingRect = effectiveWings > 0 ? NSRect(x: contentX, y: contentY, width: effectiveWings, height: targetHeight) : .zero
            let centerCutoutRect = NSRect(x: contentX + effectiveWings, y: contentY, width: basePillWidth, height: targetHeight)
            let rightWingRect = effectiveWings > 0 ? NSRect(x: contentX + effectiveWings + basePillWidth, y: contentY, width: effectiveWings, height: targetHeight) : .zero
            
            let hoverX = clampedCenterX - (effectiveHoverWidth / 2.0)
            let hoverY = clampedTopY - effectiveHoverHeight
            let hoverTriggerRect = NSRect(x: hoverX, y: hoverY, width: effectiveHoverWidth, height: effectiveHoverHeight)
            
            let windowRect: NSRect
            if isWingsVisible && effectiveWings > 0 {
                windowRect = contentRect.union(hoverTriggerRect)
            } else {
                windowRect = hoverTriggerRect
            }
            
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
    
    public static func collapsedLayout(
        geometry: NotchGeometry,
        mode: String,
        wingWidth: CGFloat = NotchDimensionLimits.defaultWingWidth,
        collapsedHeight: CGFloat = NotchDimensionLimits.defaultHoverHeight,
        hoverTriggerWidth: CGFloat = NotchDimensionLimits.defaultHoverWidth,
        hoverTriggerHeight: CGFloat = NotchDimensionLimits.defaultHoverHeight
    ) -> CollapsedLayout {
        let notchMode: CollapsedNotchMode
        switch mode {
        case "alwaysShowWings": notchMode = .alwaysShowWings
        case "wingsOnEvents": notchMode = .wingsOnEvents
        default: notchMode = .hideBehindNotch
        }
        return collapsedLayout(
            geometry: geometry,
            mode: notchMode,
            wingWidth: wingWidth,
            collapsedHeight: collapsedHeight,
            hoverTriggerWidth: hoverTriggerWidth,
            hoverTriggerHeight: hoverTriggerHeight
        )
    }
}
