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
    @Published public var sourceBundleId: String? = nil
    @Published public var isPlaying: Bool = false
    @Published public var duration: Double = 0.0
    @Published public var hasActiveMedia: Bool = false
    @Published public var artwork: NSImage? = nil
    @Published public var appIcon: NSImage? = nil

    @Published public var artworkVersion: Int = 0
    @Published public var appIconVersion: Int = 0

    private var storedProgress: Double = 0.0
    private var lastProgressUpdate = Date()
    private var observerTokens: [NSObjectProtocol] = []
    private var missedFetchCount: Int = 0
    private var pollingTimer: Timer?
    private var currentFetchGeneration: UInt64 = 0
    private var pendingRefreshWorkItem: DispatchWorkItem?

    public var progress: Double {
        guard duration > 0 else { return 0 }
        let elapsed = isPlaying ? Date().timeIntervalSince(lastProgressUpdate) / duration : 0
        return min(1, max(0, storedProgress + elapsed))
    }

    public init() {
        refreshMediaState()
        startPollingTimer()

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

        // B14: distributed observers are owned by MediaRemoteBridge (which
        // also calls refreshMediaState()). Registering them here would cause
        // duplicate refreshes for every Spotify/Music event.
    }

    // B15: adaptive polling. 2 s when a track is active, 5 s when idle.
    private func startPollingTimer() {
        pollingTimer?.invalidate()
        let interval: TimeInterval = hasActiveMedia ? 2.0 : 5.0
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.refreshMediaState()
                self.startPollingTimer()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer
    }

    public func evictArtworkOnCollapse() {
        if SettingsStore.shared.compactIndicatorStyle != .media {
            self.artwork = nil
            self.artworkVersion &+= 1
        }
    }

    public func teardown() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        observerTokens.removeAll()
        pendingRefreshWorkItem?.cancel()
        pendingRefreshWorkItem = nil
        // B16: invalidate in-flight fetches so a late completion can't
        // resurrect state after teardown.
        currentFetchGeneration &+= 1
    }

    public func refreshMediaState(force: Bool = false) {
        pendingRefreshWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.performFetchMediaState()
        }
        pendingRefreshWorkItem = item
        if force {
            DispatchQueue.main.async(execute: item)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: item)
        }
    }

    private func performFetchMediaState() {
        currentFetchGeneration &+= 1
        let thisGeneration = currentFetchGeneration

        MediaRemoteBridge.shared.fetchCurrentTrack { [weak self] track in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard thisGeneration == self.currentFetchGeneration else { return }

                if let track = track {
                    self.missedFetchCount = 0
                    if self.trackTitle != track.title { self.trackTitle = track.title }
                    if self.artistName != track.artist { self.artistName = track.artist }
                    if self.sourceApp != track.sourceApp { self.sourceApp = track.sourceApp }
                    if self.sourceBundleId != track.bundleIdentifier { self.sourceBundleId = track.bundleIdentifier }
                    if self.isPlaying != track.isPlaying { self.isPlaying = track.isPlaying }

                    // B17: guard against NaN/Inf.
                    let rawDuration = track.duration
                    let duration = (rawDuration.isFinite && rawDuration >= 0) ? rawDuration : 0
                    if self.duration != duration { self.duration = duration }

                    let rawElapsed = track.elapsedTime
                    let elapsed = (rawElapsed.isFinite && rawElapsed >= 0) ? rawElapsed : 0
                    let progress = duration > 0 ? min(1, max(0, elapsed / duration)) : 0.0
                    self.storedProgress = progress
                    self.lastProgressUpdate = Date()

                    if !self.hasActiveMedia { self.hasActiveMedia = true }

                    if self.artwork !== track.artwork {
                        self.artwork = track.artwork
                        self.artworkVersion &+= 1
                        if SettingsStore.shared.currentTheme == .musicReactive {
                            DynamicThemeEngine.shared.refreshColors()
                        }
                    }
                    if self.appIcon !== track.appIcon {
                        self.appIcon = track.appIcon
                        self.appIconVersion &+= 1
                    }
                } else {
                    self.missedFetchCount += 1
                    if self.missedFetchCount >= 2 {
                        if self.trackTitle != "No Media Playing" { self.trackTitle = "No Media Playing" }
                        if self.artistName != "Play YouTube, Spotify, Music or Safari" { self.artistName = "Play YouTube, Spotify, Music or Safari" }
                        if !self.sourceApp.isEmpty { self.sourceApp = "" }
                        if self.sourceBundleId != nil { self.sourceBundleId = nil }
                        if self.isPlaying { self.isPlaying = false }
                        self.storedProgress = 0
                        self.lastProgressUpdate = Date()
                        if self.duration != 0 { self.duration = 0 }
                        if self.hasActiveMedia { self.hasActiveMedia = false }
                        if self.artwork != nil {
                            self.artwork = nil
                            self.artworkVersion &+= 1
                        }
                        if self.appIcon != nil {
                            self.appIcon = nil
                            self.appIconVersion &+= 1
                        }
                        MediaRemoteBridge.shared.clearCachedArtwork()
                        MediaRemoteBridge.shared.resetActiveSource()
                    }
                }
            }
        }
    }

    // B12: no optimistic toggle. Only `performFetchMediaState` writes isPlaying.
    // B13: progress snapshot is preserved; only reset on success.
    public func togglePlayPause() {
        guard hasActiveMedia else { return }
        FeedbackManager.playClick()

        // Freeze the live progress before the player changes anything, so we
        // don't drift if the reconcile is slow.
        self.storedProgress = self.progress
        self.lastProgressUpdate = Date()

        let target = self.sourceBundleId
        _ = MediaRemoteBridge.shared.togglePlayPause(targetBundleId: target)
        // The bridge schedules post-command refreshes; isPlaying will settle
        // to the authoritative value on the next fetch.
    }

    public func nextTrack() {
        guard hasActiveMedia else { return }
        FeedbackManager.playClick()

        let target = self.sourceBundleId
        _ = MediaRemoteBridge.shared.nextTrack(targetBundleId: target)
        // B13: only reset progress after the command has been dispatched.
        self.storedProgress = 0
        self.lastProgressUpdate = Date()
    }

    public func previousTrack() {
        guard hasActiveMedia else { return }
        FeedbackManager.playClick()

        let target = self.sourceBundleId
        _ = MediaRemoteBridge.shared.previousTrack(targetBundleId: target)
        self.storedProgress = 0
        self.lastProgressUpdate = Date()
    }

    public func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(max(0, seconds))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Home Card

public struct NowPlayingHomeCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchCompact) private var notchCompact
    @Environment(\.notchTight) private var notchTight
    @ObservedObject var module: NowPlayingModule = NowPlayingModule.shared

    @ObservedObject private var shell = NotchShellCoordinator.shared
    @ObservedObject private var settings = SettingsStore.shared

    public var body: some View {
        let artBoxSize: CGFloat = notchTight ? 38 : (notchCompact ? 46 : 58)
        let artImgSize: CGFloat = notchTight ? 34 : (notchCompact ? 42 : 54)

        VStack(alignment: .leading, spacing: notchTight ? 4 : (notchCompact ? 6 : 10)) {
            HStack(spacing: notchTight ? 8 : 12) {
                artworkView(boxSize: artBoxSize, imgSize: artImgSize)

                VStack(alignment: .leading, spacing: notchTight ? 1 : 3) {
                    HStack(spacing: 6) {
                        Text(module.trackTitle)
                            .font(.system(size: notchTight ? 11.5 : 13, weight: .bold, design: .rounded))
                            // B19: theme-aware primary text.
                            .foregroundColor(DesignSystem.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .contentTransition(.opacity)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: module.trackTitle)

                        Spacer()

                        if module.hasActiveMedia && module.isPlaying {
                            LiveEqualizerIndicator(
                                isPlaying: module.isPlaying,
                                color: DesignSystem.accentColor,
                                barWidth: 2,
                                maxHeight: notchTight ? 8 : 11
                            )
                        }
                    }

                    HStack(spacing: 6) {
                        Text(module.artistName)
                            .font(.system(size: notchTight ? 9.5 : 11, weight: .medium))
                            .foregroundColor(DesignSystem.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                        if !module.sourceApp.isEmpty && module.hasActiveMedia && !notchTight {
                            sourcePill
                        }
                    }

                    progressSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // B20: tighter spacer so short widgets still fit.
            Spacer(minLength: 4)

            transportControls
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private func artworkView(boxSize: CGFloat, imgSize: CGFloat) -> some View {
        ZStack {
            if module.isPlaying && settings.currentTheme == .musicReactive {
                RoundedRectangle(cornerRadius: notchTight ? 10 : 14, style: .continuous)
                    .fill(DesignSystem.accentColor.opacity(0.35))
                    .frame(width: boxSize, height: boxSize)
                    .blur(radius: notchTight ? 3 : 6)
            }

            RoundedRectangle(cornerRadius: notchTight ? 10 : 14, style: .continuous)
                .fill(DesignSystem.surfaceFill)
                .frame(width: boxSize, height: boxSize)

            if let art = module.artwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: imgSize, height: imgSize)
                    .clipShape(RoundedRectangle(cornerRadius: notchTight ? 8 : 12, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: notchTight ? 8 : 12, style: .continuous)
                        // B19: theme-aware placeholder.
                        .fill(DesignSystem.fill(0.04))
                        .frame(width: imgSize, height: imgSize)
                    Image(systemName: "music.note")
                        .font(.system(size: notchTight ? 16 : 22))
                        .foregroundColor(DesignSystem.accentColor)
                }
                .transition(.opacity)
            }

            RoundedRectangle(cornerRadius: notchTight ? 10 : 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        // B19: theme-aware bevel.
                        colors: [DesignSystem.primaryText.opacity(0.25), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: module.artworkVersion)
    }

    private var sourcePill: some View {
        HStack(spacing: 3) {
            if let icon = module.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 10, height: 10)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            }
            Text(module.sourceApp)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(DesignSystem.accentColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 76, alignment: .leading)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(Capsule().fill(DesignSystem.accentColor.opacity(0.16)))
        .layoutPriority(-1)
    }

    @ViewBuilder
    private var progressSection: some View {
        VStack(spacing: 2) {
            if module.duration > 0 {
                let isExpanded = shell.state == .expanded
                TimelineView(.animation(minimumInterval: 1, paused: !module.isPlaying || !isExpanded)) { _ in
                    let progress = module.progress
                    VStack(spacing: 2) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    // B19: theme-aware track.
                                    .fill(DesignSystem.fill(0.12))
                                    .frame(height: 3)

                                Capsule()
                                    .fill(DesignSystem.accentColor)
                                    .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 3)
                                    .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
                            }
                        }
                        .frame(height: 3)

                        if !notchTight {
                            HStack {
                                Text(module.formatTime(module.duration * progress))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(DesignSystem.tertiaryText)
                                Spacer()
                                Text(module.formatTime(module.duration))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(DesignSystem.tertiaryText)
                            }
                        }
                    }
                }
            } else {
                Capsule()
                    // B19: theme-aware empty track.
                    .fill(DesignSystem.fill(0.06))
                    .frame(height: 3)
                if !notchTight {
                    HStack {
                        Text(module.hasActiveMedia ? "Live Audio" : "--:--")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(DesignSystem.tertiaryText.opacity(0.6))
                        Spacer()
                        Text(module.hasActiveMedia ? "Streaming" : "--:--")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(DesignSystem.tertiaryText.opacity(0.6))
                    }
                }
            }
        }
        .frame(height: notchTight ? 6 : 18)
        .padding(.top, 2)
    }

    private var transportControls: some View {
        HStack(spacing: notchTight ? 16 : (notchCompact ? 20 : 24)) {
            Spacer()

            Button(action: { module.previousTrack() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: notchTight ? 12 : 14))
                    .foregroundColor(DesignSystem.primaryText)
                    .frame(width: notchTight ? 28 : 32, height: notchTight ? 28 : 32)
                    .background(Circle().fill(DesignSystem.surfaceFill))
            }
            .buttonStyle(.spring)
            .disabled(!module.hasActiveMedia)
            .opacity(module.hasActiveMedia ? 1.0 : 0.35)
            .accessibilityLabel("Previous Track")

            Button(action: { module.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(module.hasActiveMedia ? DesignSystem.accentColor : DesignSystem.surfaceFill)
                        .frame(width: notchTight ? 34 : 38, height: notchTight ? 34 : 38)
                    Image(systemName: module.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: notchTight ? 12 : 14, weight: .bold))
                        // NOTE / WHY THIS IS RUNNING NOW:
                        // Resolved missing DesignSystem.accentInkColor member in DesignSystem.swift.
                        // On an accent circle, keep black/white depending on
                        // theme ink; on the disabled surface, use secondary.
                        .foregroundColor(module.hasActiveMedia ? DesignSystem.accentInkColor : DesignSystem.tertiaryText)
                        .offset(x: module.isPlaying ? 0 : 1)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: module.isPlaying)
                }
            }
            .buttonStyle(.spring(scale: 0.97))
            .disabled(!module.hasActiveMedia)
            .opacity(module.hasActiveMedia ? 1.0 : 0.45)
            .accessibilityLabel(module.isPlaying ? "Pause" : "Play")

            Button(action: { module.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: notchTight ? 12 : 14))
                    .foregroundColor(DesignSystem.primaryText)
                    .frame(width: notchTight ? 28 : 32, height: notchTight ? 28 : 32)
                    .background(Circle().fill(DesignSystem.surfaceFill))
            }
            .buttonStyle(.spring)
            .disabled(!module.hasActiveMedia)
            .opacity(module.hasActiveMedia ? 1.0 : 0.35)
            .accessibilityLabel("Next Track")

            Spacer()
        }
    }
}

// MARK: - Compact Tile

public struct NowPlayingCompactTileView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchCompact) private var notchCompact
    @Environment(\.notchTight) private var notchTight
    @ObservedObject var module: NowPlayingModule = NowPlayingModule.shared
    // B18: observe theme changes in the compact tile too.
    @ObservedObject private var settings = SettingsStore.shared

    public var body: some View {
        let tileArtSize: CGFloat = notchTight ? 32 : (notchCompact ? 38 : 44)

        VStack(spacing: notchTight ? 3 : 6) {
            HStack(spacing: notchTight ? 6 : 10) {
                artworkThumb(tileArtSize: tileArtSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text(module.trackTitle.isEmpty ? "Not Playing" : module.trackTitle)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                    Text(subtitleText)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(DesignSystem.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                if module.isPlaying {
                    LiveEqualizerIndicator(isPlaying: module.isPlaying)
                        .frame(width: 14, height: 12)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignSystem.fill(0.12))
                        .frame(height: 3)

                    Capsule()
                        .fill(DesignSystem.accentColor)
                        .frame(width: max(0, min(geo.size.width * CGFloat(module.progress), geo.size.width)), height: 3)
                }
            }
            .frame(height: 3)

            transportDock
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var subtitleText: String {
        if !module.artistName.isEmpty { return module.artistName }
        if !module.sourceApp.isEmpty { return module.sourceApp }
        return "Media Ready"
    }

    private var shouldShowSourcePill: Bool {
        guard module.hasActiveMedia, !module.sourceApp.isEmpty else { return false }
        return !module.artistName.isEmpty
    }

    private func artworkThumb(tileArtSize: CGFloat) -> some View {
        ZStack {
            if let artwork = module.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else if let icon = module.appIcon, module.hasActiveMedia {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(notchTight ? 4 : 6)
                    .transition(.opacity)
            } else {
                Rectangle()
                    .fill(DesignSystem.fill(0.08))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: notchTight ? 12 : 16))
                            .foregroundColor(DesignSystem.secondaryText)
                    )
                    .transition(.opacity)
            }
        }
        .frame(width: tileArtSize, height: tileArtSize)
        .clipShape(RoundedRectangle(cornerRadius: notchTight ? 7 : 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: notchTight ? 7 : 10, style: .continuous)
                .strokeBorder(DesignSystem.fill(0.12), lineWidth: 0.8)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: module.artworkVersion)
    }

    private var transportDock: some View {
        HStack(spacing: 8) {
            Button(action: { module.previousTrack() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.secondaryText)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!module.hasActiveMedia)
            .opacity(module.hasActiveMedia ? 1.0 : 0.35)
            .accessibilityLabel("Previous Track")

            Button(action: { module.togglePlayPause() }) {
                Image(systemName: module.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(module.hasActiveMedia ? DesignSystem.primaryText : DesignSystem.tertiaryText)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(module.hasActiveMedia ? DesignSystem.fill(0.14) : DesignSystem.fill(0.04)))
            }
            .buttonStyle(.plain)
            .disabled(!module.hasActiveMedia)
            .opacity(module.hasActiveMedia ? 1.0 : 0.45)
            .accessibilityLabel(module.isPlaying ? "Pause" : "Play")

            Button(action: { module.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.secondaryText)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!module.hasActiveMedia)
            .opacity(module.hasActiveMedia ? 1.0 : 0.35)
            .accessibilityLabel("Next Track")

            Spacer(minLength: 2)

            if shouldShowSourcePill {
                HStack(spacing: 3) {
                    if let icon = module.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 10, height: 10)
                            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    }
                    if !notchTight {
                        Text(module.sourceApp)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(DesignSystem.accentColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 72, alignment: .leading)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(DesignSystem.accentColor.opacity(0.14)))
                .layoutPriority(-1)
            }
        }
    }
}

// MARK: - Adaptive Container

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // B20: layout now fits; keep clipped() as a safety net for the
        // background shape but no longer relies on it to hide content.
        .clipped()
    }
}