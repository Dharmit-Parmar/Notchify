import AppKit
import SwiftUI

// MARK: - Full-Screen Overlay Companion Panel
@MainActor
public final class CompanionPanel: NSPanel {
    public static var shared: CompanionPanel?
    public private(set) var clickPanel: CompanionClickPanel?
    
    public init(screen: NSScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]) {
        let width = screen.frame.width
        let height: CGFloat = 160.0
        
        let frameRect = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
        
        super.init(
            contentRect: frameRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .screenSaver // Renders above menu bar and full screen apps
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true // Full-screen click-through: menus, status icons and apps work uninterrupted!
        self.isMovable = false
        self.acceptsMouseMovedEvents = true
        
        let hostingView = NSHostingView(rootView: CreatureContainerView())
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView
        
        // Auxiliary Miniature Click-Target Panel following the creature's body
        let clickP = CompanionClickPanel(screen: screen)
        self.clickPanel = clickP
        
        CompanionPanel.shared = self
        CompanionCoordinator.shared.panel = self
        CompanionCoordinator.shared.clickPanel = clickP
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateFramePosition()
            }
        }
    }
    
    public func updateFramePosition(for screen: NSScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]) {
        let width = screen.frame.width
        let height: CGFloat = 160.0
        let targetRect = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
        self.setFrame(targetRect, display: true)
        KinematicEngine.shared.refreshScreenGeometry()
        clickPanel?.updatePosition(pose: KinematicEngine.shared.currentPose, screen: screen)
    }
}

// MARK: - Auxiliary Miniature Click Panel (Creature Body Tap & Hover)
@MainActor
public final class CompanionClickPanel: NSPanel {
    public init(screen: NSScreen) {
        let size: CGFloat = 48.0
        let rect = NSRect(x: -200, y: -200, width: size, height: size)
        
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .screenSaver
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isMovable = false
        self.acceptsMouseMovedEvents = true
        
        let clickHost = NSHostingView(rootView: CreatureClickTargetView())
        clickHost.autoresizingMask = [.width, .height]
        self.contentView = clickHost
    }
    
    public func updatePosition(pose: SkeletonPose, screen: NSScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]) {
        guard CompanionCoordinator.shared.state != .inDen else {
            if self.isVisible {
                self.orderOut(nil)
            }
            return
        }
        
        let root = pose.root
        // In screen coordinates: Y is measured from screen bottom
        let screenX = screen.frame.origin.x + root.x - 24.0
        let screenY = screen.frame.maxY - root.y - 24.0
        self.setFrameOrigin(NSPoint(x: screenX, y: screenY))
        
        if !self.isVisible && CompanionCoordinator.shared.state != .inDen {
            self.orderFrontRegardless()
        }
    }
}

// MARK: - Miniature Click Target View
public struct CreatureClickTargetView: View {
    @ObservedObject var coordinator = CompanionCoordinator.shared
    
    public init() {}
    
    public var body: some View {
        Color.clear
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
            .onHover { hovering in
                coordinator.onCursorHover(hovering)
            }
            .onTapGesture {
                coordinator.onCreatureClicked()
            }
    }
}

// MARK: - Creature Container View
public struct CreatureContainerView: View {
    @ObservedObject var coordinator = CompanionCoordinator.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if coordinator.state != .inDen {
                CreatureRigView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
