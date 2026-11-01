import AppKit
import SwiftUI

// MARK: - Dedicated Floating Companion Panel
@MainActor
public final class CompanionPanel: NSPanel {
    public static var shared: CompanionPanel?
    
    public init(screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) {
        let geom = NotchGeometry.current(for: screen)
        let width = geom.physicalNotchWidth + 140
        let height = geom.physicalNotchHeight + 60
        
        let frameRect = NSRect(
            x: geom.notchCenterX - (width / 2.0),
            y: geom.screenFrame.origin.y + geom.screenFrame.height - height,
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
        
        let hostingView = CompanionHostingView(rootView: CreatureContainerView())
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView
        
        CompanionPanel.shared = self
        
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
    
    public func updateFramePosition(for screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) {
        let geom = NotchGeometry.current(for: screen)
        let width = geom.physicalNotchWidth + 140
        let height = geom.physicalNotchHeight + 60
        
        let targetRect = NSRect(
            x: geom.notchCenterX - (width / 2.0),
            y: geom.screenFrame.origin.y + geom.screenFrame.height - height,
            width: width,
            height: height
        )
        self.setFrame(targetRect, display: true)
    }
}

// MARK: - Specialized Hit-Testing Host View
// Pass-through architecture: ONLY the creature body intercepts mouse events.
// Transparent window regions pass clicks directly to underlying applications!
public final class CompanionHostingView<Content: View>: NSHostingView<Content> {
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let coord = CompanionCoordinator.shared
        guard coord.state != .inDen else { return nil }
        
        let interactiveRect = coord.creatureInteractiveRectInWindow
        if interactiveRect.contains(point) {
            return super.hitTest(point)
        }
        
        // Pass click straight through to active macOS window / menu bar!
        return nil
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
