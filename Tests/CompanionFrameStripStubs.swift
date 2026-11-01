import AppKit
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    @Published var companionSkin: CompanionSkin = .mochi
    @Published var companionDebugSkeleton = false
}

@MainActor
final class CompanionCoordinator: ObservableObject {
    static let shared = CompanionCoordinator()
    @Published var state: CompanionBehaviorState = .inDen

    func onCursorHover(_ hovering: Bool) {}
    func onCreatureClicked() {}
    func companionRouteDidAdvance() {}
}

@MainActor
final class CompanionClickPanel {
    func updatePosition(pose: SkeletonPose, screen: NSScreen) {}
}

@MainActor
final class CompanionPanel {
    static var shared: CompanionPanel? { CompanionPanel.instance }
    private static let instance = CompanionPanel()
    var screen: NSScreen? { NSScreen.main }
    let clickPanel: CompanionClickPanel? = CompanionClickPanel()
}
