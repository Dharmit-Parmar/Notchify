import AppKit
import SwiftUI
import Combine

@MainActor
public final class CompanionCoordinator: ObservableObject {
    public static let shared = CompanionCoordinator()
    
    // MARK: - State Properties
    @Published public var state: CompanionBehaviorState = .inDen
    @Published public var isHovered: Bool = false
    
    public weak var panel: CompanionPanel?
    
    // Internal Timers & Monitored Events
    private var schedulerTimer: Timer?
    private var actionDurationTimer: Timer?
    private var typingDecayTimer: Timer?
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
    private var recentKeystrokes: Int = 0
    private var isSequenceRunning: Bool = false
    private var hasSlippedInSession: Bool = false
    private var isStarted: Bool = false
    private var isObserving: Bool = false
    
    private init() {}
    
    // MARK: - AppKit Hit-Test Target Frame
    public var creatureInteractiveRectInWindow: NSRect {
        guard state != .inDen else { return .zero }
        let geom = NotchGeometry.current()
        let winW = geom.physicalNotchWidth + 140
        let winH = geom.physicalNotchHeight + 60
        
        let centerAppKitX = winW / 2.0
        let notchLipY = geom.physicalNotchHeight
        
        let rootPose = KinematicEngine.shared.currentPose.root
        let appKitX = centerAppKitX + rootPose.x
        let appKitY = (winH - notchLipY) - rootPose.y
        
        return NSRect(x: appKitX - 26, y: appKitY - 24, width: 52, height: 48)
    }
    
    // MARK: - Lifecycle
    public func start() {
        guard SettingsStore.shared.isCompanionEnabled else { return }
        guard !isStarted else { return }
        isStarted = true
        setupObservers()
        setupTypingMonitor()
        scheduleNextBehavior()
    }
    
    public func stop() {
        isStarted = false
        schedulerTimer?.invalidate()
        schedulerTimer = nil
        actionDurationTimer?.invalidate()
        actionDurationTimer = nil
        typingDecayTimer?.invalidate()
        typingDecayTimer = nil
        
        if let km = keyMonitor {
            NSEvent.removeMonitor(km)
            keyMonitor = nil
        }
        
        retreatToDen(immediate: true)
    }
    
    // MARK: - Observers
    private func setupObservers() {
        guard !isObserving else { return }
        isObserving = true
        
        // 1. Observe Settings Enable / Disable Toggle
        SettingsStore.shared.$isCompanionEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self = self else { return }
                if enabled {
                    self.start()
                } else {
                    self.stop()
                }
            }
            .store(in: &cancellables)
        
        // 2. Observe Notch Expansion State
        NotchShellCoordinator.shared.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] notchState in
                guard let self = self else { return }
                if notchState == .expanded {
                    self.retreatToDen(immediate: true)
                } else if notchState == .collapsed && SettingsStore.shared.isCompanionEnabled {
                    self.scheduleNextBehavior(delay: 2.0)
                }
            }
            .store(in: &cancellables)
            
        // 3. Observe Now Playing Audio State
        NowPlayingModule.shared.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] isPlaying in
                guard let self = self else { return }
                guard SettingsStore.shared.isCompanionEnabled,
                      SettingsStore.shared.companionGrooveMusic,
                      NotchShellCoordinator.shared.state == .collapsed else { return }
                
                if isPlaying && self.state == .inDen && !self.isSequenceRunning {
                    self.triggerMusicGroove()
                } else if !isPlaying && self.state == .musicGroove {
                    self.retreatToDen()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Passive Typing Cadence Monitor
    private func setupTypingMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.registerTypingCadence()
            }
        }
    }
    
    private func registerTypingCadence() {
        guard SettingsStore.shared.isCompanionEnabled,
              SettingsStore.shared.companionMimicTyping,
              NotchShellCoordinator.shared.state == .collapsed else { return }
        
        recentKeystrokes += 1
        
        typingDecayTimer?.invalidate()
        typingDecayTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.recentKeystrokes = 0
                if self.state == .typingMimic {
                    self.retreatToDen()
                }
            }
        }
        
        if recentKeystrokes >= 4 && (state == .inDen || state == .sleeping) && !isSequenceRunning {
            triggerTypingMimic()
        }
    }
    
    // MARK: - State Machine Scheduler
    public func scheduleNextBehavior(delay: TimeInterval? = nil) {
        schedulerTimer?.invalidate()
        guard SettingsStore.shared.isCompanionEnabled,
              NotchShellCoordinator.shared.state == .collapsed else { return }
        
        let waitTime: TimeInterval
        if let explicitDelay = delay {
            waitTime = explicitDelay
        } else {
            let interval = SettingsStore.shared.companionActivityLevel.intervalRange
            waitTime = Double.random(in: interval)
        }
        
        schedulerTimer = Timer.scheduledTimer(withTimeInterval: waitTime, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.executeRandomAction()
            }
        }
        schedulerTimer?.tolerance = 0.5
    }
    
    private func executeRandomAction() {
        guard SettingsStore.shared.isCompanionEnabled,
              NotchShellCoordinator.shared.state == .collapsed,
              !isSequenceRunning else { return }
        
        if NowPlayingModule.shared.isPlaying && SettingsStore.shared.companionGrooveMusic && Bool.random() {
            triggerMusicGroove()
            return
        }
        
        let choices: [CompanionBehaviorState] = [
            .peekingLeft,
            .peekingRight,
            .walking,
            .crawling,
            .thinking,
            .sleeping
        ]
        
        guard let chosenState = choices.randomElement() else { return }
        
        switch chosenState {
        case .peekingLeft:
            triggerPeek(side: .left)
        case .peekingRight:
            triggerPeek(side: .right)
        case .walking:
            triggerWalking()
        case .crawling:
            triggerCrawling()
        case .thinking:
            triggerThinking()
        case .sleeping:
            triggerSleeping()
        default:
            triggerPeek(side: .left)
        }
    }
    
    // MARK: - Action Triggers (Kinematic Skeleton Driven)
    public func triggerPeek(side: PeekSide) {
        isSequenceRunning = true
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        let peekState: CompanionBehaviorState = (side == .left) ? .peekingLeft : .peekingRight
        state = peekState
        KinematicEngine.shared.setBehavior(peekState, notchWidth: geom.physicalNotchWidth)
        
        actionDurationTimer?.invalidate()
        let peekDuration = Double.random(in: 6.0...8.5)
        actionDurationTimer = Timer.scheduledTimer(withTimeInterval: peekDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.retreatToDen()
            }
        }
    }
    
    public enum PeekSide { case left, right }
    
    public func triggerWalking() {
        isSequenceRunning = true
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        state = .walking
        KinematicEngine.shared.setBehavior(.walking, notchWidth: geom.physicalNotchWidth)
        
        actionDurationTimer?.invalidate()
        let walkDuration = Double.random(in: 8.0...14.0)
        actionDurationTimer = Timer.scheduledTimer(withTimeInterval: walkDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if SettingsStore.shared.companionAllowSlips && !self.hasSlippedInSession && Bool.random() {
                    self.executeSlipSequence()
                } else {
                    self.retreatToDen()
                }
            }
        }
    }
    
    public func triggerCrawling() {
        isSequenceRunning = true
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        state = .crawling
        KinematicEngine.shared.setBehavior(.crawling, notchWidth: geom.physicalNotchWidth)
        
        actionDurationTimer?.invalidate()
        let crawlDuration = Double.random(in: 6.0...10.0)
        actionDurationTimer = Timer.scheduledTimer(withTimeInterval: crawlDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.retreatToDen()
            }
        }
    }
    
    public func triggerThinking() {
        isSequenceRunning = true
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        state = .thinking
        KinematicEngine.shared.setBehavior(.thinking, notchWidth: geom.physicalNotchWidth)
        
        actionDurationTimer?.invalidate()
        let thinkDuration = Double.random(in: 5.0...8.0)
        actionDurationTimer = Timer.scheduledTimer(withTimeInterval: thinkDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.retreatToDen()
            }
        }
    }
    
    // MARK: - Signature Slip & Dangle Comedy Sequence
    public func executeSlipSequence() {
        hasSlippedInSession = true
        isSequenceRunning = true
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        state = .dangling
        FeedbackManager.playClick()
        KinematicEngine.shared.setBehavior(.dangling, notchWidth: geom.physicalNotchWidth)
        
        actionDurationTimer?.invalidate()
        // Dangle for 3.0s swinging as a damped pendulum, then initiate pull-up!
        actionDurationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.state = .pullingUp
                KinematicEngine.shared.setBehavior(.pullingUp)
                
                // Allow pull-up and sigh to finish before retreating
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    self?.retreatToDen()
                }
            }
        }
    }
    
    public func triggerTypingMimic() {
        isSequenceRunning = true
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        state = .typingMimic
        KinematicEngine.shared.setBehavior(.typingMimic, notchWidth: geom.physicalNotchWidth)
    }
    
    public func triggerMusicGroove() {
        isSequenceRunning = true
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        state = .musicGroove
        KinematicEngine.shared.setBehavior(.musicGroove, notchWidth: geom.physicalNotchWidth)
        
        actionDurationTimer?.invalidate()
        let grooveDuration = Double.random(in: 8.0...14.0)
        actionDurationTimer = Timer.scheduledTimer(withTimeInterval: grooveDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !NowPlayingModule.shared.isPlaying {
                    self.retreatToDen()
                } else {
                    self.actionDurationTimer = nil
                }
            }
        }
    }
    
    public func triggerSleeping() {
        isSequenceRunning = true
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        state = .sleeping
        KinematicEngine.shared.setBehavior(.sleeping, notchWidth: geom.physicalNotchWidth)
        
        actionDurationTimer?.invalidate()
        let napDuration = Double.random(in: 14.0...26.0)
        actionDurationTimer = Timer.scheduledTimer(withTimeInterval: napDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.retreatToDen()
            }
        }
    }
    
    // MARK: - Retreat into Physical Notch Den (0% CPU Contract)
    public func retreatToDen(immediate: Bool = false) {
        actionDurationTimer?.invalidate()
        actionDurationTimer = nil
        
        state = .inDen
        KinematicEngine.shared.setBehavior(.inDen)
        panel?.orderOut(nil)
        isSequenceRunning = false
        
        if !immediate {
            scheduleNextBehavior()
        }
    }
    
    // MARK: - User Direct Interaction
    public func onCursorHover(_ hovering: Bool) {
        isHovered = hovering
        if hovering && (state == .walking || state == .inDen) {
            triggerThinking()
        }
    }
    
    public func onCreatureClicked() {
        FeedbackManager.playClick()
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
        state = .celebrating
        KinematicEngine.shared.setBehavior(.celebrating)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            if self.state == .celebrating {
                self.retreatToDen()
            }
        }
    }
}
