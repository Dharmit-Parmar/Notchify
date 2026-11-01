import AppKit
import SwiftUI
import Combine

// MARK: - Particle Models
public struct MusicNoteParticle: Identifiable {
    public let id = UUID()
    public let symbol: String
    public var x: CGFloat
    public var y: CGFloat
    public var opacity: Double
    
    public init(symbol: String, x: CGFloat, y: CGFloat, opacity: Double) {
        self.symbol = symbol
        self.x = x
        self.y = y
        self.opacity = opacity
    }
}

public struct SleepZzzParticle: Identifiable {
    public let id = UUID()
    public var x: CGFloat
    public var y: CGFloat
    public var size: CGFloat
    public var opacity: Double
    
    public init(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double) {
        self.x = x
        self.y = y
        self.size = size
        self.opacity = opacity
    }
}

public struct StarParticle: Identifiable {
    public let id = UUID()
    public var x: CGFloat
    public var y: CGFloat
    public var size: CGFloat
    public var opacity: Double
    
    public init(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double) {
        self.x = x
        self.y = y
        self.size = size
        self.opacity = opacity
    }
}

@MainActor
public final class CompanionCoordinator: ObservableObject {
    public static let shared = CompanionCoordinator()
    
    // MARK: - State Properties
    @Published public var state: CompanionBehaviorState = .inDen
    @Published public var creaturePosition: CGPoint = CGPoint(x: 0, y: -80)
    @Published public var isHovered: Bool = false
    @Published public var facingRight: Bool = true
    
    // Animation Phase Properties (ObservableObject pattern for zero macro dependencies)
    @Published public var blinkPhase: Bool = false
    @Published public var breathPhase: Bool = false
    @Published public var walkPhase: Double = 0.0
    @Published public var typingPawAlternate: Bool = false
    @Published public var musicBeatPhase: Bool = false
    @Published public var flailPhase: Double = 0.0
    @Published public var backflipAngle: Double = 0.0
    @Published public var isSquished: Bool = false
    
    // Floating Particles
    @Published public var musicalNotes: [MusicNoteParticle] = []
    @Published public var sleepZzzs: [SleepZzzParticle] = []
    @Published public var celebrationStars: [StarParticle] = []
    
    public weak var panel: CompanionPanel?
    
    // Internal Timers & Monitored Events
    private var schedulerTimer: Timer?
    private var walkTimer: Timer?
    private var actionDurationTimer: Timer?
    private var typingDecayTimer: Timer?
    private var cadenceTimer: Timer?
    private var blinkTimer: Timer?
    private var breathTimer: Timer?
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
    private var recentKeystrokes: Int = 0
    private var isSequenceRunning: Bool = false
    private var hasSlippedInSession: Bool = false
    private var isStarted: Bool = false
    private var isObserving: Bool = false
    
    private init() {}
    
    // MARK: - Physics & Dynamic Transforms
    public var bodySquashX: CGFloat {
        if isSquished { return 1.25 }
        switch state {
        case .slipping: return 0.90
        case .dangling: return 0.85
        case .celebrating: return 1.15
        default: return breathPhase ? 1.03 : 0.98
        }
    }
    
    public var bodyStretchY: CGFloat {
        if isSquished { return 0.75 }
        switch state {
        case .slipping: return 1.15
        case .dangling: return 1.22
        case .celebrating: return 1.18
        default: return breathPhase ? 0.98 : 1.02
        }
    }
    
    public var bodyTiltAngle: Double {
        switch state {
        case .peekingLeft: return 12.0
        case .peekingRight: return -12.0
        case .walking: return (facingRight ? 1.0 : -1.0) * 4.0 * sin(walkPhase)
        case .musicGroove: return musicBeatPhase ? 6.0 : -6.0
        case .slipping: return 18.0
        case .dangling: return sin(flailPhase) * 10.0
        case .curious: return facingRight ? 14.0 : -14.0
        default: return 0.0
        }
    }
    
    public var shadowOpacity: Double {
        switch state {
        case .inDen: return 0.0
        case .dangling, .slipping: return 0.10
        default: return 0.28
        }
    }
    
    public var shadowOffsetY: CGFloat {
        switch state {
        case .dangling: return 38
        default: return 24
        }
    }
    
    // MARK: - AppKit Hit-Test Target Frame
    public var creatureInteractiveRectInWindow: NSRect {
        guard state != .inDen else { return .zero }
        let geom = NotchGeometry.current()
        let winW = geom.physicalNotchWidth + 140
        let winH = geom.physicalNotchHeight + 60
        
        let centerAppKitX = winW / 2.0
        let centerAppKitY = winH / 2.0
        
        let appKitX = centerAppKitX + creaturePosition.x
        let appKitY = centerAppKitY - creaturePosition.y
        
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
        stopMicroAnimationLoops()
        schedulerTimer?.invalidate()
        schedulerTimer = nil
        walkTimer?.invalidate()
        walkTimer = nil
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
    
    // MARK: - Micro-Animation Loops (Zero CPU Invariant when inDen)
    private func startMicroAnimationLoops() {
        stopMicroAnimationLoops()
        
        // 1. Natural Blinking (every 3.5s)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.state != .inDen, self.state != .sleeping else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    self.blinkPhase = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        self?.blinkPhase = false
                    }
                }
            }
        }
        
        // 2. Idle Breathing
        breathTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.state != .inDen else { return }
                withAnimation(.easeInOut(duration: 1.5)) {
                    self.breathPhase.toggle()
                }
            }
        }
        
        // 3. Cadence Timer for walking, typing paws, and particles
        cadenceTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.state != .inDen else { return }
                if self.state == .walking {
                    self.walkPhase += 0.8
                }
                if self.state == .typingMimic {
                    self.typingPawAlternate.toggle()
                }
                if self.state == .musicGroove {
                    self.musicBeatPhase.toggle()
                    self.spawnMusicParticle()
                }
                if self.state == .dangling {
                    self.flailPhase += 0.9
                }
                if self.state == .sleeping {
                    self.spawnSleepParticle()
                }
            }
        }
    }
    
    private func stopMicroAnimationLoops() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        breathTimer?.invalidate()
        breathTimer = nil
        cadenceTimer?.invalidate()
        cadenceTimer = nil
        musicalNotes.removeAll()
        sleepZzzs.removeAll()
        celebrationStars.removeAll()
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
            .sleeping,
            .curious
        ]
        
        guard let chosenState = choices.randomElement() else { return }
        
        switch chosenState {
        case .peekingLeft:
            triggerPeek(side: .left)
        case .peekingRight:
            triggerPeek(side: .right)
        case .walking:
            triggerWalking()
        case .sleeping:
            triggerSleeping()
        case .curious:
            triggerCurious()
        default:
            triggerPeek(side: .left)
        }
    }
    
    // MARK: - Action Triggers
    public func triggerPeek(side: PeekSide) {
        isSequenceRunning = true
        startMicroAnimationLoops()
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        let halfNotch = geom.physicalNotchWidth / 2.0
        let targetX: CGFloat = side == .left ? (-halfNotch - 14) : (halfNotch + 14)
        
        facingRight = (side == .left)
        
        creaturePosition = CGPoint(x: targetX, y: -65)
        state = (side == .left) ? .peekingLeft : .peekingRight
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            creaturePosition = CGPoint(x: targetX, y: -18)
        }
        
        actionDurationTimer?.invalidate()
        let peekDuration = Double.random(in: 4.5...7.5)
        actionDurationTimer = Timer.scheduledTimer(withTimeInterval: peekDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.retreatToDen()
            }
        }
    }
    
    public enum PeekSide { case left, right }
    
    private var walkCurrentX: CGFloat = 0.0
    private var walkStepDelta: CGFloat = 0.0
    private var walkRemainingSteps: Int = 0
    private var walkSlipX: CGFloat = 0.0
    private var walkShouldSlip: Bool = false
    
    public func triggerWalking() {
        isSequenceRunning = true
        startMicroAnimationLoops()
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        let halfNotch = max(geom.physicalNotchWidth / 2.0 - 15, 60)
        let walkLeftToRight = Bool.random()
        
        let startX: CGFloat = walkLeftToRight ? -halfNotch : halfNotch
        let endX: CGFloat = walkLeftToRight ? halfNotch : -halfNotch
        facingRight = walkLeftToRight
        
        creaturePosition = CGPoint(x: startX, y: -50)
        state = .walking
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            creaturePosition = CGPoint(x: startX, y: -13)
        }
        
        walkShouldSlip = SettingsStore.shared.companionAllowSlips && (Bool.random() || !hasSlippedInSession)
        walkSlipX = CGFloat.random(in: -20...20)
        walkCurrentX = startX
        walkRemainingSteps = 100
        walkStepDelta = (endX - startX) / CGFloat(walkRemainingSteps)
        
        walkTimer?.invalidate()
        walkTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performWalkStep()
            }
        }
    }
    
    private func performWalkStep() {
        guard state == .walking else {
            walkTimer?.invalidate()
            walkTimer = nil
            return
        }
        
        walkRemainingSteps -= 1
        walkCurrentX += walkStepDelta
        creaturePosition.x = walkCurrentX
        creaturePosition.y = -13
        
        if walkShouldSlip && abs(walkCurrentX - walkSlipX) < 4 && !hasSlippedInSession {
            walkTimer?.invalidate()
            walkTimer = nil
            executeSlipSequence()
            return
        }
        
        if walkRemainingSteps <= 0 {
            walkTimer?.invalidate()
            walkTimer = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.retreatToDen()
            }
        }
    }
    
    // MARK: - Signature Slip & Dangle Comedy Sequence
    public func executeSlipSequence() {
        hasSlippedInSession = true
        walkTimer?.invalidate()
        
        state = .slipping
        FeedbackManager.playClick()
        
        withAnimation(.easeIn(duration: 0.28)) {
            creaturePosition.y = 2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            guard let self = self else { return }
            self.state = .dangling
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                self.creaturePosition.y = 12
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                guard let self = self else { return }
                
                self.state = .pullingUp
                withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                    self.creaturePosition.y = -13
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    self.performTapCelebration()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                        self?.retreatToDen()
                    }
                }
            }
        }
    }
    
    public func triggerTypingMimic() {
        isSequenceRunning = true
        startMicroAnimationLoops()
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        let halfNotch = geom.physicalNotchWidth / 2.0
        let targetX: CGFloat = -halfNotch * 0.4
        
        creaturePosition = CGPoint(x: targetX, y: -50)
        state = .typingMimic
        facingRight = true
        
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            creaturePosition = CGPoint(x: targetX, y: -13)
        }
    }
    
    public func triggerMusicGroove() {
        isSequenceRunning = true
        startMicroAnimationLoops()
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        let halfNotch = geom.physicalNotchWidth / 2.0
        let targetX: CGFloat = halfNotch * 0.4
        
        creaturePosition = CGPoint(x: targetX, y: -50)
        state = .musicGroove
        facingRight = false
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
            creaturePosition = CGPoint(x: targetX, y: -13)
        }
        
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
        startMicroAnimationLoops()
        panel?.orderFrontRegardless()
        
        creaturePosition = CGPoint(x: 0, y: -50)
        state = .sleeping
        
        withAnimation(.easeInOut(duration: 0.5)) {
            creaturePosition = CGPoint(x: 0, y: -13)
        }
        
        actionDurationTimer?.invalidate()
        let napDuration = Double.random(in: 14.0...26.0)
        actionDurationTimer = Timer.scheduledTimer(withTimeInterval: napDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.retreatToDen()
            }
        }
    }
    
    public func triggerCurious() {
        isSequenceRunning = true
        startMicroAnimationLoops()
        panel?.orderFrontRegardless()
        
        let geom = NotchGeometry.current()
        let halfNotch = geom.physicalNotchWidth / 2.0
        let targetX: CGFloat = Bool.random() ? (-halfNotch - 10) : (halfNotch + 10)
        facingRight = targetX < 0
        
        creaturePosition = CGPoint(x: targetX, y: -55)
        state = .curious
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            creaturePosition = CGPoint(x: targetX, y: -16)
        }
        
        actionDurationTimer?.invalidate()
        actionDurationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.retreatToDen()
            }
        }
    }
    
    // MARK: - Retreat into Physical Notch Den (0% CPU Contract)
    public func retreatToDen(immediate: Bool = false) {
        walkTimer?.invalidate()
        walkTimer = nil
        actionDurationTimer?.invalidate()
        actionDurationTimer = nil
        
        if immediate {
            state = .inDen
            creaturePosition = CGPoint(x: 0, y: -80)
            panel?.orderOut(nil)
            stopMicroAnimationLoops()
            isSequenceRunning = false
            return
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            creaturePosition.y = -80
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { [weak self] in
            guard let self = self else { return }
            self.state = .inDen
            self.panel?.orderOut(nil)
            self.stopMicroAnimationLoops()
            self.isSequenceRunning = false
            self.scheduleNextBehavior()
        }
    }
    
    // MARK: - User Direct Interaction
    public func onCursorHover(_ hovering: Bool) {
        isHovered = hovering
    }
    
    public func onCreatureClicked() {
        performTapCelebration()
    }
    
    public func performTapCelebration() {
        FeedbackManager.playClick()
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            isSquished = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self = self else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                self.isSquished = false
                self.backflipAngle += 360.0
            }
            self.spawnCelebrationBurst()
        }
    }
    
    // MARK: - Particle Spawners
    private func spawnMusicParticle() {
        guard musicalNotes.count < 4 else { return }
        let symbols = ["♪", "♫", "♩"]
        let newNote = MusicNoteParticle(
            symbol: symbols.randomElement() ?? "♪",
            x: CGFloat.random(in: -16...16),
            y: -14,
            opacity: 1.0
        )
        musicalNotes.append(newNote)
        withAnimation(.easeOut(duration: 1.2)) {
            if let idx = musicalNotes.firstIndex(where: { $0.id == newNote.id }) {
                musicalNotes[idx].y -= 26
                musicalNotes[idx].opacity = 0.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.musicalNotes.removeAll(where: { $0.id == newNote.id })
        }
    }
    
    private func spawnSleepParticle() {
        guard sleepZzzs.count < 3 else { return }
        let newZ = SleepZzzParticle(
            x: CGFloat.random(in: 4...14),
            y: -8,
            size: 9,
            opacity: 0.8
        )
        sleepZzzs.append(newZ)
        withAnimation(.easeOut(duration: 1.8)) {
            if let idx = sleepZzzs.firstIndex(where: { $0.id == newZ.id }) {
                sleepZzzs[idx].y -= 24
                sleepZzzs[idx].x += 8
                sleepZzzs[idx].opacity = 0.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.sleepZzzs.removeAll(where: { $0.id == newZ.id })
        }
    }
    
    private func spawnCelebrationBurst() {
        for _ in 0..<5 {
            let star = StarParticle(
                x: CGFloat.random(in: -24...24),
                y: CGFloat.random(in: -30...(-10)),
                size: CGFloat.random(in: 8...13),
                opacity: 1.0
            )
            celebrationStars.append(star)
        }
        withAnimation(.easeOut(duration: 0.8)) {
            for i in celebrationStars.indices {
                celebrationStars[i].opacity = 0.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            self?.celebrationStars.removeAll()
        }
    }
}
