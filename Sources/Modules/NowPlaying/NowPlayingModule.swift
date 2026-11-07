import SwiftUI

@MainActor
public final class NowPlayingModule: ObservableObject {
    public static let shared = NowPlayingModule()
    
    public let id = "nowPlaying"
    public let title = "Now Playing"
    public let iconName = "play.fill"
    
    @Published public var trackTitle: String = "No Media Playing"
    @Published public var artistName: String = "Play YouTube, Spotify, Music or Safari"
    @Published public var sourceApp: String = ""
    @Published public var isPlaying: Bool = false
    @Published public var duration: Double = 0.0
    @Published public var hasActiveMedia: Bool = false
    @Published public var artwork: NSImage? = nil
    
    private var storedProgress: Double = 0.0
    private var lastProgressUpdate = Date()
    private var observerTokens: [NSObjectProtocol] = []

    public var progress: Double {
        guard duration > 0 else { return 0 }
        let elapsed = isPlaying ? Date().timeIntervalSince(lastProgressUpdate) / duration : 0
        return min(1, max(0, storedProgress + elapsed))
    }
    
    public init() {
        refreshMediaState()
        // Register for all macOS MediaRemote system notifications for instant updates
        let notifNames = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "MRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
            "MRMediaRemoteNowPlayingApplicationDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            "MRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
        ]
        for name in notifNames {
            let token = NotificationCenter.default.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshMediaState()
                }
            }
            observerTokens.append(token)
        }
        
        let wsToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshMediaState()
            }
        }
        observerTokens.append(wsToken)
    }

    public func teardown() {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        observerTokens.removeAll()
        pendingRefreshWorkItem?.cancel()
        pendingRefreshWorkItem = nil
    }
    
    private var pendingRefreshWorkItem: DispatchWorkItem?
    private var isFetching = false
    private var lastFetchTimestamp: Date = .distantPast
    
    public func refreshMediaState() {
        let isCollapsed = NotchShellCoordinator.shared.state == .collapsed
        let showsMediaIndicator = SettingsStore.shared.compactIndicatorStyle == .media
        if isCollapsed && !showsMediaIndicator {
            return
        }
        
        pendingRefreshWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.performFetchMediaState()
        }
        pendingRefreshWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
    }

    private func performFetchMediaState() {
        let now = Date()
        if isFetching {
            if now.timeIntervalSince(lastFetchTimestamp) > 2.5 {
                isFetching = false
            } else {
                return
            }
        }
        isFetching = true
        lastFetchTimestamp = now

        MediaRemoteBridge.shared.fetchCurrentTrack { [weak self] track in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isFetching = false
                if let track = track {
                    if self.trackTitle != track.title { self.trackTitle = track.title }
                    if self.artistName != track.artist { self.artistName = track.artist }
                    if self.sourceApp != track.sourceApp { self.sourceApp = track.sourceApp }
                    if self.isPlaying != track.isPlaying { self.isPlaying = track.isPlaying }
                    let duration = max(0.0, track.duration)
                    if self.duration != duration { self.duration = duration }
                    let progress = track.duration > 0 ? min(1, max(0, track.elapsedTime / track.duration)) : 0.0
                    self.storedProgress = progress
                    self.lastProgressUpdate = Date()
                    if !self.hasActiveMedia { self.hasActiveMedia = true }
                    if self.artwork !== track.artwork {
                        self.artwork = track.artwork
                        if SettingsStore.shared.currentTheme == .musicReactive {
                            DynamicThemeEngine.shared.refreshColors()
                        }
                    }
                } else {
                    if self.trackTitle != "No Media Playing" { self.trackTitle = "No Media Playing" }
                    if self.artistName != "Play YouTube, Spotify, Music or Safari" { self.artistName = "Play YouTube, Spotify, Music or Safari" }
                    if !self.sourceApp.isEmpty { self.sourceApp = "" }
                    if self.isPlaying { self.isPlaying = false }
                    self.storedProgress = 0
                    self.lastProgressUpdate = Date()
                    if self.duration != 0 { self.duration = 0 }
                    if self.hasActiveMedia { self.hasActiveMedia = false }
                    if self.artwork != nil { self.artwork = nil }
                    MediaRemoteBridge.shared.clearCachedArtwork()
                }
            }
        }
    }
    
    public func togglePlayPause() {
        isPlaying.toggle()
        lastProgressUpdate = Date()
        MediaRemoteBridge.shared.togglePlayPause()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshMediaState()
        }
    }
    
    public func nextTrack() {
        MediaRemoteBridge.shared.nextTrack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.refreshMediaState()
        }
    }
    
    public func previousTrack() {
        MediaRemoteBridge.shared.previousTrack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.refreshMediaState()
        }
    }
    
    public func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(max(0, seconds))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// Left-side Now Playing Media Card for Home Dashboard
public struct NowPlayingHomeCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var module: NowPlayingModule = NowPlayingModule.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Double-Bezel Squircle Album Art / App Icon
                ZStack {
                    if module.isPlaying && SettingsStore.shared.currentTheme == .musicReactive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignSystem.accentColor.opacity(0.35))
                            .frame(width: 58, height: 58)
                            .blur(radius: 6)
                    }
                    
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 58, height: 58)
                    
                    if let art = module.artwork {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else {
                        Image(systemName: module.hasActiveMedia ? "tv.music.note.fill" : "music.note")
                            .font(.system(size: 22))
                            .foregroundColor(DesignSystem.accentColor)
                    }
                    
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(module.trackTitle)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: module.trackTitle)
                        
                        Spacer()
                        
                        if module.hasActiveMedia && module.isPlaying {
                            LiveEqualizerIndicator(isPlaying: true, color: DesignSystem.accentColor, barWidth: 2, maxHeight: 11)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text(module.artistName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.secondaryText)
                            .lineLimit(1)
                        
                        if !module.sourceApp.isEmpty && module.hasActiveMedia {
                            Text(module.sourceApp)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(DesignSystem.accentColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(DesignSystem.accentColor.opacity(0.16)))
                                .lineLimit(1)
                        }
                    }
                    
                    // Scrubber progress bar
                    if module.duration > 0 {
                        let isExpanded = NotchShellCoordinator.shared.state == .expanded
                        TimelineView(.animation(minimumInterval: 1, paused: !module.isPlaying || !isExpanded)) { _ in
                            let progress = module.progress
                            VStack(spacing: 2) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.12))
                                            .frame(height: 3)

                                        Capsule()
                                            .fill(DesignSystem.accentColor)
                                            .frame(width: geo.size.width * CGFloat(progress), height: 3)
                                            .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
                                    }
                                }
                                .frame(height: 3)

                                HStack {
                                    Text(module.formatTime(module.duration * progress))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Color.white.opacity(0.4))
                                    Spacer()
                                    Text(module.formatTime(module.duration))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Color.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }

            Spacer(minLength: 8)
            
            // Transport Controls with Spring Physics
            HStack(spacing: 24) {
                Spacer()
                
                Button(action: {
                    FeedbackManager.playClick()
                    module.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(DesignSystem.surfaceFill))
                }
                .buttonStyle(.spring)
                
                Button(action: {
                    FeedbackManager.playClick()
                    module.togglePlayPause()
                }) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.accentColor)
                            .frame(width: 38, height: 38)
                        Image(systemName: module.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: module.isPlaying ? 0 : 1)
                            .contentTransition(.symbolEffect(.replace))
                            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: module.isPlaying)
                    }
                }
                .buttonStyle(.spring(scale: 0.97))
                
                Button(action: {
                    FeedbackManager.playClick()
                    module.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(DesignSystem.surfaceFill))
                }
                .buttonStyle(.spring)
                
                Spacer()
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
        )
        .onAppear { module.refreshMediaState() }
    }
}

// MARK: - 1-Space Compact Media Tile View
public struct NowPlayingCompactTileView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var module: NowPlayingModule = NowPlayingModule.shared
    
    public var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // Album Art / App Icon
                ZStack {
                    if let artwork = module.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundColor(DesignSystem.secondaryText)
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                )
                
                // Track Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(module.trackTitle.isEmpty ? "Not Playing" : module.trackTitle)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(module.artistName.isEmpty ? (module.sourceApp.isEmpty ? "Media Ready" : module.sourceApp) : module.artistName)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(DesignSystem.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Live mini equalizer or transport
                if module.isPlaying {
                    LiveEqualizerIndicator(isPlaying: module.isPlaying)
                        .frame(width: 14, height: 12)
                }
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(DesignSystem.accentColor)
                        .frame(width: max(0, min(geo.size.width * CGFloat(module.progress), geo.size.width)), height: 3)
                }
            }
            .frame(height: 3)
            
            // Transport Dock
            HStack(spacing: 12) {
                Button(action: {
                    FeedbackManager.playClick()
                    module.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    FeedbackManager.playClick()
                    module.togglePlayPause()
                }) {
                    Image(systemName: module.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    FeedbackManager.playClick()
                    module.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(module.sourceApp.isEmpty ? "macOS" : module.sourceApp)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(DesignSystem.secondaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
        )
        .onAppear { module.refreshMediaState() }
    }
}

// MARK: - Adaptive Now Playing Widget Container
public struct NowPlayingAdaptiveWidgetView: View {
    public var span: Int
    
    public init(span: Int = 2) {
        self.span = span
    }
    
    public var body: some View {
        Group {
            if span == 1 {
                NowPlayingCompactTileView()
            } else {
                NowPlayingHomeCardView()
            }
        }
    }
}
