import Foundation
import AppKit
import ImageIO
import CryptoKit

// MARK: - Track value type

public struct SystemMediaTrack: @unchecked Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: Double
    public let elapsedTime: Double
    public let isPlaying: Bool
    public let artwork: NSImage?
    public let appIcon: NSImage?
    public let bundleIdentifier: String?
    public let sourceApp: String

    public init(
        title: String,
        artist: String,
        album: String = "",
        duration: Double = 0.0,
        elapsedTime: Double = 0.0,
        isPlaying: Bool = true,
        artwork: NSImage? = nil,
        appIcon: NSImage? = nil,
        bundleIdentifier: String? = nil,
        sourceApp: String
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.isPlaying = isPlaying
        self.artwork = artwork
        self.appIcon = appIcon
        self.bundleIdentifier = bundleIdentifier
        self.sourceApp = sourceApp
    }
}

extension SystemMediaTrack: Equatable {
    public static func == (lhs: SystemMediaTrack, rhs: SystemMediaTrack) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.album == rhs.album &&
        lhs.duration == rhs.duration &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.sourceApp == rhs.sourceApp
    }
}

public enum MediaTransportAction: Sendable {
    case playPause
    case next
    case previous
}

// MARK: - MediaRemote bridge

public final class MediaRemoteBridge: @unchecked Sendable {
    public static let shared = MediaRemoteBridge()

    // The `MRMediaRemote…` C APIs take `Boolean` (unsigned char).
    private typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    private typealias MRMediaRemoteGetNowPlayingApplicationPIDFunction = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
    private typealias MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias MRMediaRemoteRegisterFunction = @convention(c) (DispatchQueue) -> Void
    private typealias MRMediaRemoteSendCommandFunction = @convention(c) (UInt32, CFDictionary?) -> UInt8
    private typealias CGEventPostToPidFunction = @convention(c) (pid_t, CGEvent) -> Void

    private var getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction?
    private var getNowPlayingApplicationPID: MRMediaRemoteGetNowPlayingApplicationPIDFunction?
    private var getNowPlayingApplicationIsPlaying: MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction?
    private var registerForNotifications: MRMediaRemoteRegisterFunction?
    private var sendCommand: MRMediaRemoteSendCommandFunction?
    private var postToPidFunc: CGEventPostToPidFunction?

    // ---- cached state (all access MUST go through cacheLock) ----
    private var cachedBundleId: String? = nil
    private var cachedAppIcon: NSImage? = nil
    private var cachedIsPlaying: Bool = false
    private var cachedArtworkDigest: SHA256Digest? = nil
    private var cachedArtworkImage: NSImage? = nil
    private var cachedArtworkSourceBundleId: String? = nil
    private var appIconCache: [String: NSImage] = [:]
    private let cacheLock = NSLock()
    private var fetchGeneration: UInt64 = 0

    private var cachedSpotifyTrack: SystemMediaTrack?
    private var cachedMusicTrack: SystemMediaTrack?
    private var _lastActiveSource: String? = nil
    // B7: lock-protected accessors.
    public var lastActiveSource: String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return _lastActiveSource
    }
    private func setLastActiveSource(_ value: String?) {
        cacheLock.lock()
        _lastActiveSource = value
        cacheLock.unlock()
    }

    // B10: running-apps scan cache must be lock-protected.
    private var cachedRunningPlayerId: String? = nil
    private var lastRunningAppsScan: Date = .distantPast

    private var inFlightThumbnailLoads: Set<String> = []
    private let inFlightLock = NSLock()

    private let thumbnailCache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 20
        return c
    }()

    private let scriptQueue = DispatchQueue(label: "com.notch.MediaRemote.scripts", qos: .userInitiated)

    // B9: retain observer tokens for teardown.
    private var distributedObserverTokens: [NSObjectProtocol] = []
    private var workspaceObserverTokens: [NSObjectProtocol] = []

    // B11: strict YouTube ID validation.
    private static let youtubeIdRegex: NSRegularExpression = {
        // YouTube IDs are 11 chars: [A-Za-z0-9_-].
        try! NSRegularExpression(pattern: "^[A-Za-z0-9_-]{11}$")
    }()
    private static func isValidYouTubeId(_ id: String) -> Bool {
        guard id.utf16.count == 11 else { return false }
        let range = NSRange(location: 0, length: id.utf16.count)
        return youtubeIdRegex.firstMatch(in: id, range: range) != nil
    }

    // ---- lifecycle ----

    public func clearCachedArtwork() {
        cacheLock.lock()
        cachedArtworkDigest = nil
        cachedArtworkImage = nil
        cachedArtworkSourceBundleId = nil
        cachedAppIcon = nil
        appIconCache.removeAll()
        cacheLock.unlock()
        thumbnailCache.removeAllObjects()
    }

    private init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) {
            if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
                getNowPlayingInfo = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
            }
            if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") {
                getNowPlayingApplicationPID = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingApplicationPIDFunction.self)
            }
            if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
                getNowPlayingApplicationIsPlaying = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction.self)
            }
            if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
                registerForNotifications = unsafeBitCast(sym, to: MRMediaRemoteRegisterFunction.self)
            }
            if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
                sendCommand = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFunction.self)
            }
            registerForNotifications?(DispatchQueue.main)
        }

        if let cgHandle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW) {
            if let sym = dlsym(cgHandle, "CGEventPostToPid") {
                postToPidFunc = unsafeBitCast(sym, to: CGEventPostToPidFunction.self)
            }
        }

        setupDistributedObservers()
    }

    deinit {
        for token in distributedObserverTokens {
            DistributedNotificationCenter.default().removeObserver(token)
        }
        for token in workspaceObserverTokens {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    // MARK: - Distributed notifications

    private func setupDistributedObservers() {
        distributedObserverTokens.append(
            DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
                object: nil,
                queue: .main
            ) { [weak self] notif in
                self?.handleSpotifyNotification(notif)
            }
        )
        distributedObserverTokens.append(
            DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name("com.apple.Music.playerInfo"),
                object: nil,
                queue: .main
            ) { [weak self] notif in
                self?.handleMusicNotification(notif)
            }
        )
        distributedObserverTokens.append(
            DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name("com.apple.iTunes.playerInfo"),
                object: nil,
                queue: .main
            ) { [weak self] notif in
                self?.handleMusicNotification(notif)
            }
        )
        workspaceObserverTokens.append(
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notif in
                guard let self = self,
                      let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      let bid = app.bundleIdentifier else { return }
                self.cacheLock.lock()
                if bid == "com.spotify.client" {
                    self.cachedSpotifyTrack = nil
                    if self._lastActiveSource == "com.spotify.client" { self._lastActiveSource = nil }
                } else if bid == "com.apple.Music" {
                    self.cachedMusicTrack = nil
                    if self._lastActiveSource == "com.apple.Music" { self._lastActiveSource = nil }
                } else if bid == self.cachedBundleId {
                    self.cachedBundleId = nil
                    self.cachedAppIcon = nil
                }
                self.cacheLock.unlock()
                Task { @MainActor in NowPlayingModule.shared.refreshMediaState() }
            }
        )
    }

    private func handleSpotifyNotification(_ notif: Notification) {
        guard let info = notif.userInfo else { return }
        let state = (info["Player State"] as? String ?? "").lowercased()
        let isPlaying = (state == "playing" || state == "kplaybackstateplaying")
        let isStopped = (state == "stopped")
        let title = info["Name"] as? String ?? ""
        let artist = info["Artist"] as? String ?? ""
        let album = info["Album"] as? String ?? ""

        let durMs = (info["Duration"] as? Double)
            ?? ((info["Duration"] as? Int).map(Double.init) ?? 0.0)
        let duration = durMs / 1000.0
        let posMs = (info["Position"] as? Double)
            ?? ((info["Position"] as? Int).map(Double.init) ?? 0.0)
        let position = posMs / 1000.0

        let appIcon = self.iconForBundle("com.spotify.client")

        cacheLock.lock()
        let sourceArt: NSImage? = (self.cachedArtworkSourceBundleId == "com.spotify.client")
            ? self.cachedArtworkImage
            : self.cachedSpotifyTrack?.artwork

        if !title.isEmpty && !isStopped {
            self.cachedSpotifyTrack = SystemMediaTrack(
                title: title,
                artist: artist.isEmpty ? "Spotify" : artist,
                album: album,
                duration: duration,
                elapsedTime: position,
                isPlaying: isPlaying,
                artwork: sourceArt,
                appIcon: appIcon,
                bundleIdentifier: "com.spotify.client",
                sourceApp: "Spotify"
            )
            self._lastActiveSource = "com.spotify.client"
            cacheLock.unlock()
            Task { @MainActor in NowPlayingModule.shared.refreshMediaState() }
            return
        }

        if isStopped {
            self.cachedSpotifyTrack = nil
            if self._lastActiveSource == "com.spotify.client" { self._lastActiveSource = nil }
            cacheLock.unlock()
            Task { @MainActor in NowPlayingModule.shared.refreshMediaState() }
            return
        }

        if !isPlaying, let existing = self.cachedSpotifyTrack {
            self.cachedSpotifyTrack = SystemMediaTrack(
                title: existing.title,
                artist: existing.artist,
                album: existing.album,
                duration: existing.duration,
                elapsedTime: position > 0 ? position : existing.elapsedTime,
                isPlaying: false,
                artwork: sourceArt ?? existing.artwork,
                appIcon: existing.appIcon,
                bundleIdentifier: existing.bundleIdentifier,
                sourceApp: existing.sourceApp
            )
            cacheLock.unlock()
            Task { @MainActor in NowPlayingModule.shared.refreshMediaState() }
            return
        }

        cacheLock.unlock()
    }

    private func handleMusicNotification(_ notif: Notification) {
        guard let info = notif.userInfo else { return }
        let state = (info["Player State"] as? String ?? "").lowercased()
        let isPlaying = (state == "playing")
        let isStopped = (state == "stopped")
        let title = info["Name"] as? String ?? ""
        let artist = info["Artist"] as? String ?? ""
        let album = info["Album"] as? String ?? ""

        let totalMs = (info["Total Time"] as? Double)
            ?? ((info["Total Time"] as? Int).map(Double.init) ?? 0.0)
        let duration = totalMs / 1000.0
        let position = (info["Elapsed Time"] as? Double)
            ?? ((info["Elapsed Time"] as? Int).map(Double.init) ?? 0.0)

        // B8: decode image data on main only. The notification is already on
        // main (queue: .main), so this is safe.
        var artFromNotification: NSImage? = nil
        if let artData = info["Artwork Data"] as? Data {
            artFromNotification = NSImage(data: artData)
        }

        let appIcon = self.iconForBundle("com.apple.Music")

        cacheLock.lock()
        let sourceArt: NSImage? = (self.cachedArtworkSourceBundleId == "com.apple.Music")
            ? self.cachedArtworkImage
            : self.cachedMusicTrack?.artwork

        if !title.isEmpty && !isStopped {
            self.cachedMusicTrack = SystemMediaTrack(
                title: title,
                artist: artist.isEmpty ? "Apple Music" : artist,
                album: album,
                duration: duration,
                elapsedTime: position,
                isPlaying: isPlaying,
                artwork: artFromNotification ?? sourceArt,
                appIcon: appIcon,
                bundleIdentifier: "com.apple.Music",
                sourceApp: "Apple Music"
            )
            self._lastActiveSource = "com.apple.Music"
            cacheLock.unlock()
            Task { @MainActor in NowPlayingModule.shared.refreshMediaState() }
            return
        }

        if isStopped {
            self.cachedMusicTrack = nil
            if self._lastActiveSource == "com.apple.Music" { self._lastActiveSource = nil }
            cacheLock.unlock()
            Task { @MainActor in NowPlayingModule.shared.refreshMediaState() }
            return
        }

        if !isPlaying, let existing = self.cachedMusicTrack {
            self.cachedMusicTrack = SystemMediaTrack(
                title: existing.title,
                artist: existing.artist,
                album: existing.album,
                duration: existing.duration,
                elapsedTime: position > 0 ? position : existing.elapsedTime,
                isPlaying: false,
                artwork: artFromNotification ?? sourceArt ?? existing.artwork,
                appIcon: existing.appIcon,
                bundleIdentifier: existing.bundleIdentifier,
                sourceApp: existing.sourceApp
            )
            cacheLock.unlock()
            Task { @MainActor in NowPlayingModule.shared.refreshMediaState() }
            return
        }

        cacheLock.unlock()
    }

    // MARK: - Multi-tier track discovery

    public func fetchCurrentTrack(completion: @escaping @Sendable (SystemMediaTrack?) -> Void) {
        cacheLock.lock()
        fetchGeneration &+= 1
        let currentGen = fetchGeneration
        cacheLock.unlock()

        let safeCompletion: @Sendable (SystemMediaTrack?) -> Void = { [weak self] track in
            guard let self = self else { completion(track); return }
            self.cacheLock.lock()
            let isCurrent = (self.fetchGeneration == currentGen)
            self.cacheLock.unlock()
            if isCurrent { completion(track) }
        }

        let group = DispatchGroup()

        // NOTE / WHY THIS IS RUNNING NOW (Error Fix):
        // Previously used loose mutable local `var`s (didFinalize, playingSnapshot, pidBundleId, pidIcon).
        // Capturing those loose vars inside the `@Sendable` finalize closure and completion blocks triggered:
        //   "error: reference to captured var 'didFinalize' in concurrently-executing code [#SendableClosureCaptures]"
        //   "error: mutation of captured var 'didFinalize' in concurrently-executing code [#SendableClosureCaptures]"
        //   "error: reference to captured var 'playingSnapshot' in concurrently-executing code [#SendableClosureCaptures]"
        //   "error: reference to captured var 'pidBundleId' in concurrently-executing code [#SendableClosureCaptures]"
        //   "error: reference to captured var 'pidIcon' in concurrently-executing code [#SendableClosureCaptures]"
        // Wrapping them in a thread-safe, lock-protected Sendable class box satisfies Swift 6 strict concurrency checks.
        final class FetchStateBox: @unchecked Sendable {
            let lock = NSLock()
            var didFinalize = false
            var playingSnapshot = false
            var pidBundleId: String? = nil
            var pidIcon: NSImage? = nil
        }
        let state = FetchStateBox()

        if let getIsPlaying = getNowPlayingApplicationIsPlaying {
            group.enter()
            getIsPlaying(DispatchQueue.main) { isPlaying in
                state.lock.lock()
                state.playingSnapshot = isPlaying
                state.lock.unlock()
                group.leave()
            }
        }
        if let getPID = getNowPlayingApplicationPID {
            group.enter()
            getPID(DispatchQueue.main) { pid in
                if pid > 0, let app = NSRunningApplication(processIdentifier: pid) {
                    let bid = app.bundleIdentifier
                    let icon = app.icon
                    icon?.size = NSSize(width: 128, height: 128)
                    state.lock.lock()
                    state.pidBundleId = bid
                    state.pidIcon = icon
                    state.lock.unlock()
                }
                group.leave()
            }
        }

        let finalize: @Sendable () -> Void = { [weak self] in
            state.lock.lock()
            if state.didFinalize { state.lock.unlock(); return }
            state.didFinalize = true
            let playingSnapshot = state.playingSnapshot
            let pidBundleId = state.pidBundleId
            let pidIcon = state.pidIcon
            state.lock.unlock()

            guard let self = self else { safeCompletion(nil); return }

            // B5: guard cache mutation with the generation check too, so a
            // stale fetch cannot overwrite a newer fetch's identity.
            self.cacheLock.lock()
            let isCurrent = (self.fetchGeneration == currentGen)
            if isCurrent {
                self.cachedIsPlaying = playingSnapshot
                if let bid = pidBundleId {
                    if bid != self.cachedBundleId {
                        self.cachedBundleId = bid
                        self.cachedAppIcon = pidIcon
                    }
                } else {
                    self.cachedBundleId = nil
                    self.cachedAppIcon = nil
                }
            }
            self.cacheLock.unlock()

            guard isCurrent else { return }

            self.queryMediaRemote(
                playingSnapshot: playingSnapshot,
                generation: currentGen,
                completion: safeCompletion
            )
        }

        group.notify(queue: .main, execute: finalize)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: finalize)
    }

    private func queryMediaRemote(
        playingSnapshot: Bool,
        generation: UInt64,
        completion: @escaping @Sendable (SystemMediaTrack?) -> Void
    ) {
        guard let getInfo = getNowPlayingInfo else {
            self.fallbackAfterMediaRemote(completion: completion)
            return
        }

        getInfo(DispatchQueue.main) { [weak self] dict in
            guard let self = self else { completion(nil); return }

            // B5: never mutate anything if a newer fetch has started.
            self.cacheLock.lock()
            let isCurrent = (self.fetchGeneration == generation)
            self.cacheLock.unlock()
            guard isCurrent else { return }

            guard let dict = dict, let info = dict as? [String: Any], !info.isEmpty else {
                self.fallbackAfterMediaRemote(completion: completion)
                return
            }

            let rawTitle = (info["kMRMediaRemoteNowPlayingInfoTitle"] as? String)
                ?? (info["title"] as? String)
                ?? (info["kMRMediaRemoteNowPlayingInfoContentItemIdentifier"] as? String)
                ?? ""
            let rawArtist = (info["kMRMediaRemoteNowPlayingInfoArtist"] as? String)
                ?? (info["artist"] as? String)
                ?? ""
            let album = (info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String)
                ?? (info["album"] as? String)
                ?? ""
            let duration = (info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double)
                ?? (info["duration"] as? Double)
                ?? 0.0
            let elapsed = (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double)
                ?? (info["elapsedTime"] as? Double)
                ?? 0.0

            let rateValue: Double? = {
                if let v = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double { return v }
                if let v = info["playbackRate"] as? Double { return v }
                return nil
            }()
            let isPlaying: Bool = rateValue.map { $0 > 0.0 } ?? playingSnapshot

            let title = rawTitle
                .replacingOccurrences(of: " - YouTube", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = rawArtist.trimmingCharacters(in: .whitespacesAndNewlines)

            if title.isEmpty && artist.isEmpty {
                self.fallbackAfterMediaRemote(completion: completion)
                return
            }

            let clientBundleId = (info["kMRMediaRemoteNowPlayingInfoClientBundleIdentifier"] as? String)
                ?? (info["clientBundleIdentifier"] as? String)
            self.cacheLock.lock()
            let cachedBundle = self.cachedBundleId
            let cachedIcon = self.cachedAppIcon
            self.cacheLock.unlock()
            let bundleId = clientBundleId ?? cachedBundle ?? self.findActiveMediaAppBundleId()
            let appDisplayName = self.displayNameForBundle(bundleId) ?? "Media Player"
            let appIcon = (bundleId != nil ? self.iconForBundle(bundleId!) : nil) ?? cachedIcon

            var directArt: NSImage? = nil
            let rawArtData = (info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data)
                ?? (info["artworkData"] as? Data)
            if let artData = rawArtData, !artData.isEmpty {
                // B6: include bundle ID in the identity; digest the whole blob.
                let digest = SHA256.hash(data: artData)

                self.cacheLock.lock()
                let identityMatches = (self.cachedArtworkDigest == digest)
                    && (self.cachedArtworkSourceBundleId == bundleId)
                if !identityMatches {
                    self.cachedArtworkDigest = digest
                    self.cachedArtworkSourceBundleId = bundleId
                    // B8: image construction already on main (this callback is
                    // dispatched to main). Safe.
                    self.cachedArtworkImage = Self.makeArtworkImage(from: artData)
                }
                directArt = self.cachedArtworkImage
                self.cacheLock.unlock()
            }

            let track = SystemMediaTrack(
                title: title.isEmpty ? "Media Playing" : title,
                artist: artist.isEmpty ? appDisplayName : artist,
                album: album,
                duration: duration,
                elapsedTime: elapsed,
                isPlaying: isPlaying,
                artwork: directArt,
                appIcon: appIcon,
                bundleIdentifier: bundleId,
                sourceApp: appDisplayName
            )
            completion(track)
        }
    }

    private func fallbackAfterMediaRemote(completion: @escaping @Sendable (SystemMediaTrack?) -> Void) {
        cacheLock.lock()
        let spotify = self.cachedSpotifyTrack
        let music = self.cachedMusicTrack
        cacheLock.unlock()

        if let spotify = spotify, spotify.isPlaying, self.isAppRunning(bundleId: "com.spotify.client") {
            setLastActiveSource("com.spotify.client")
            completion(spotify)
            return
        }
        if let music = music, music.isPlaying, self.isAppRunning(bundleId: "com.apple.Music") {
            setLastActiveSource("com.apple.Music")
            completion(music)
            return
        }

        self.scriptQueue.async { [weak self] in
            guard let self = self else { completion(nil); return }
            if let scriptTrack = self.queryRunningMediaAppsViaScript() {
                self.setLastActiveSource(scriptTrack.bundleIdentifier)
                // B8: scriptTrack may carry an image built on the script
                // queue. Rebuild it on main if needed. For our paths the
                // images we return come from caches under lock, not NSImage
                // created off-main — see query*Script implementations.
                DispatchQueue.main.async { completion(scriptTrack) }
                return
            }

            if let spotify = spotify, self.isAppRunning(bundleId: "com.spotify.client") {
                self.setLastActiveSource("com.spotify.client")
                DispatchQueue.main.async { completion(spotify) }
                return
            }
            if let music = music, self.isAppRunning(bundleId: "com.apple.Music") {
                self.setLastActiveSource("com.apple.Music")
                DispatchQueue.main.async { completion(music) }
                return
            }
            DispatchQueue.main.async { completion(nil) }
        }
    }

    // MARK: - AppleScript polling

    private func queryRunningMediaAppsViaScript() -> SystemMediaTrack? {
        let runningBundleIds = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))

        let browsers: [(bundleId: String, appName: String)] = [
            ("com.brave.Browser", "Brave Browser"),
            ("com.google.Chrome", "Google Chrome"),
            ("com.apple.Safari", "Safari"),
            ("company.thebrowser.Browser", "Arc"),
            ("com.microsoft.edgemac", "Microsoft Edge")
        ]
        for b in browsers where runningBundleIds.contains(b.bundleId) {
            if let track = queryBrowserScript(bundleId: b.bundleId, appName: b.appName) {
                return track
            }
        }
        if runningBundleIds.contains("com.spotify.client"), let track = querySpotifyScript() {
            return track
        }
        if runningBundleIds.contains("com.apple.Music"), let track = queryMusicScript() {
            return track
        }
        return nil
    }

    private func querySpotifyScript() -> SystemMediaTrack? {
        let src = """
        tell application "Spotify"
            if it is running then
                set pState to (player state as string)
                if pState is not "stopped" then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tDur to (duration of current track) / 1000.0
                    set tPos to player position
                    return tName & ":::" & tArtist & ":::" & tAlbum & ":::" & tDur & ":::" & tPos & ":::" & pState
                end if
            end if
        end tell
        return ""
        """
        guard let script = NSAppleScript(source: src) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil, let str = result.stringValue, !str.isEmpty else { return nil }
        let parts = str.components(separatedBy: ":::")
        guard !parts.isEmpty, !parts[0].isEmpty else { return nil }

        let title = parts[0]
        let artist = parts.count > 1 ? parts[1] : "Spotify"
        let album = parts.count > 2 ? parts[2] : ""
        let dur = parts.count > 3 ? (Double(parts[3]) ?? 0.0) : 0.0
        let pos = parts.count > 4 ? (Double(parts[4]) ?? 0.0) : 0.0
        let isPlaying = parts.count > 5 ? (parts[5].lowercased() == "playing") : true

        let appIcon = self.iconForBundle("com.spotify.client")

        self.cacheLock.lock()
        let spotifyArt: NSImage? = (self.cachedArtworkSourceBundleId == "com.spotify.client")
            ? self.cachedArtworkImage
            : self.cachedSpotifyTrack?.artwork
        self.cacheLock.unlock()

        return SystemMediaTrack(
            title: title,
            artist: artist.isEmpty ? "Spotify" : artist,
            album: album,
            duration: dur,
            elapsedTime: pos,
            isPlaying: isPlaying,
            artwork: spotifyArt,
            appIcon: appIcon,
            bundleIdentifier: "com.spotify.client",
            sourceApp: "Spotify"
        )
    }

    private func queryMusicScript() -> SystemMediaTrack? {
        let src = """
        tell application "Music"
            if it is running then
                set pState to (player state as string)
                if pState is not "stopped" then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tDur to duration of current track
                    set tPos to player position
                    return tName & ":::" & tArtist & ":::" & tAlbum & ":::" & tDur & ":::" & tPos & ":::" & pState
                end if
            end if
        end tell
        return ""
        """
        guard let script = NSAppleScript(source: src) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil, let str = result.stringValue, !str.isEmpty else { return nil }
        let parts = str.components(separatedBy: ":::")
        guard !parts.isEmpty, !parts[0].isEmpty else { return nil }

        let title = parts[0]
        let artist = parts.count > 1 ? parts[1] : "Apple Music"
        let album = parts.count > 2 ? parts[2] : ""
        let dur = parts.count > 3 ? (Double(parts[3]) ?? 0.0) : 0.0
        let pos = parts.count > 4 ? (Double(parts[4]) ?? 0.0) : 0.0
        let isPlaying = parts.count > 5 ? (parts[5].lowercased() == "playing") : true

        let appIcon = self.iconForBundle("com.apple.Music")

        self.cacheLock.lock()
        let musicArt: NSImage? = (self.cachedArtworkSourceBundleId == "com.apple.Music")
            ? self.cachedArtworkImage
            : self.cachedMusicTrack?.artwork
        self.cacheLock.unlock()

        return SystemMediaTrack(
            title: title,
            artist: artist.isEmpty ? "Apple Music" : artist,
            album: album,
            duration: dur,
            elapsedTime: pos,
            isPlaying: isPlaying,
            artwork: musicArt,
            appIcon: appIcon,
            bundleIdentifier: "com.apple.Music",
            sourceApp: "Apple Music"
        )
    }

    private func queryBrowserScript(bundleId: String, appName: String) -> SystemMediaTrack? {
        // B3: scan media tabs FIRST (background media is common). Only check
        // the front tab if it happens to be a media tab too.
        let scriptSrc: String
        if bundleId == "com.apple.Safari" {
            scriptSrc = """
            tell application "Safari"
                if (count of windows) = 0 then return ""
                repeat with w in windows
                    repeat with t in (tabs of w)
                        set u to URL of t
                        if u contains "youtube.com/watch" or u contains "youtu.be/" or u contains "youtube.com/shorts" or u contains "music.youtube.com/watch" or u contains "spotify.com" or u contains "soundcloud.com" or u contains "music.apple.com" then
                            set tabAudio to false
                            try
                                set tabJsPlaying to do JavaScript "document.querySelector('video, audio') ? !document.querySelector('video, audio').paused : false" in t
                                if tabJsPlaying is true or tabJsPlaying is "true" then set tabAudio to true
                            end try
                            if tabAudio then
                                return (name of t) & ":::" & u & ":::" & (tabAudio as string)
                            end if
                        end if
                    end repeat
                end repeat
                -- No tab is currently playing. Return the first media tab we
                -- find, marked as not playing, so metadata still shows.
                repeat with w in windows
                    repeat with t in (tabs of w)
                        set u to URL of t
                        if u contains "youtube.com/watch" or u contains "youtu.be/" or u contains "youtube.com/shorts" or u contains "music.youtube.com/watch" or u contains "spotify.com" or u contains "soundcloud.com" or u contains "music.apple.com" then
                            return (name of t) & ":::" & u & ":::false"
                        end if
                    end repeat
                end repeat
            end tell
            return ""
            """
        } else {
            scriptSrc = """
            tell application id "\(bundleId)"
                if (count of windows) = 0 then return ""
                repeat with w in windows
                    repeat with t in (tabs of w)
                        set u to URL of t
                        if u contains "youtube.com/watch" or u contains "youtu.be/" or u contains "youtube.com/shorts" or u contains "music.youtube.com/watch" or u contains "spotify.com" or u contains "soundcloud.com" or u contains "music.apple.com" then
                            set tabAudio to false
                            try
                                set tabJs to execute t javascript "document.querySelector('video, audio') ? !document.querySelector('video, audio').paused : false"
                                if tabJs is true or tabJs is "true" then set tabAudio to true
                            end try
                            if tabAudio then
                                return (title of t) & ":::" & u & ":::" & (tabAudio as string)
                            end if
                        end if
                    end repeat
                end repeat
                repeat with w in windows
                    repeat with t in (tabs of w)
                        set u to URL of t
                        if u contains "youtube.com/watch" or u contains "youtu.be/" or u contains "youtube.com/shorts" or u contains "music.youtube.com/watch" or u contains "spotify.com" or u contains "soundcloud.com" or u contains "music.apple.com" then
                            return (title of t) & ":::" & u & ":::false"
                        end if
                    end repeat
                end repeat
            end tell
            return ""
            """
        }

        guard let script = NSAppleScript(source: scriptSrc) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil, let str = result.stringValue, !str.isEmpty else { return nil }
        let parts = str.components(separatedBy: ":::")
        guard !parts.isEmpty, !parts[0].isEmpty else { return nil }

        let rawTitle = parts[0]
        let rawURL = parts.count > 1 ? parts[1].lowercased() : ""
        let isAudioPlaying = parts.count > 2 ? (parts[2].lowercased() == "true") : false

        let isMediaSite = rawURL.contains("youtube.com/watch")
            || rawURL.contains("youtu.be/")
            || rawURL.contains("youtube.com/shorts")
            || rawURL.contains("music.youtube.com/watch")
            || rawURL.contains("spotify.com")
            || rawURL.contains("soundcloud.com")
            || rawURL.contains("netflix.com")
            || rawURL.contains("twitch.tv")
            || rawURL.contains("bandcamp.com")
            || rawURL.contains("music.apple.com")
            || rawURL.contains("vimeo.com")
            || rawTitle.contains(" - YouTube")
            || rawTitle.contains(" | SoundCloud")
        guard isMediaSite else { return nil }

        var cleanTitle = rawTitle
            .replacingOccurrences(of: " - YouTube", with: "")
            .replacingOccurrences(of: " | SoundCloud", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lower = cleanTitle.lowercased()
        if lower == "youtube" || lower == "home" || lower.isEmpty || lower == "subscriptions" {
            return nil
        }

        var artist = appName
        if cleanTitle.contains(" - ") {
            let sub = cleanTitle.components(separatedBy: " - ")
            if sub.count >= 2 {
                artist = sub[0].trimmingCharacters(in: .whitespacesAndNewlines)
                cleanTitle = sub.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let appIcon = self.iconForBundle(bundleId)

        var thumbnailArt: NSImage? = nil
        if rawURL.contains("youtube.com/watch") || rawURL.contains("youtu.be/") || rawURL.contains("youtube.com/shorts") {
            if let videoId = extractYouTubeVideoId(from: rawURL) {
                thumbnailArt = thumbnailCache.object(forKey: videoId as NSString)
                if thumbnailArt == nil {
                    loadYouTubeThumbnail(videoId: videoId)
                }
            }
        }

        return SystemMediaTrack(
            title: cleanTitle.isEmpty ? "Media Playing" : cleanTitle,
            artist: artist,
            album: "",
            duration: 0.0,
            elapsedTime: 0.0,
            isPlaying: isAudioPlaying,
            artwork: thumbnailArt,
            appIcon: appIcon,
            bundleIdentifier: bundleId,
            sourceApp: appName
        )
    }

    private func extractYouTubeVideoId(from urlString: String) -> String? {
        if let range = urlString.range(of: "youtube.com/shorts/") {
            let after = urlString[range.upperBound...]
            let id = after.prefix(while: { $0 != "&" && $0 != "#" && $0 != "?" && $0 != "/" })
            return id.isEmpty ? nil : String(id)
        }
        if let range = urlString.range(of: "v=") {
            let afterV = urlString[range.upperBound...]
            let id = afterV.prefix(while: { $0 != "&" && $0 != "#" && $0 != "?" && $0 != "/" })
            return id.isEmpty ? nil : String(id)
        }
        if let range = urlString.range(of: "youtu.be/") {
            let after = urlString[range.upperBound...]
            let id = after.prefix(while: { $0 != "&" && $0 != "#" && $0 != "?" && $0 != "/" })
            return id.isEmpty ? nil : String(id)
        }
        return nil
    }

    private func loadYouTubeThumbnail(videoId: String) {
        // B11: only fetch for well-formed IDs.
        guard Self.isValidYouTubeId(videoId),
              let url = URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg") else { return }

        inFlightLock.lock()
        if inFlightThumbnailLoads.contains(videoId) {
            inFlightLock.unlock()
            return
        }
        inFlightThumbnailLoads.insert(videoId)
        inFlightLock.unlock()

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            defer {
                self.inFlightLock.lock()
                self.inFlightThumbnailLoads.remove(videoId)
                self.inFlightLock.unlock()
            }
            // B8: don't construct NSImage here — this callback runs off-main.
            // Pass the raw Data and construct on main.
            guard let data = data else { return }
            DispatchQueue.main.async {
                guard let img = NSImage(data: data) else { return }
                img.size = NSSize(width: 128, height: 128)
                self.thumbnailCache.setObject(img, forKey: videoId as NSString)
                NowPlayingModule.shared.refreshMediaState()
            }
        }.resume()
    }

    private static func makeArtworkImage(from data: Data) -> NSImage? {
        autoreleasepool {
            let sourceOpts: [CFString: Any] = [
                kCGImageSourceShouldCache: false,
                kCGImageSourceShouldCacheImmediately: false
            ]
            guard let source = CGImageSourceCreateWithData(data as CFData, sourceOpts as CFDictionary) else {
                return NSImage(data: data)
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 256,
                kCGImageSourceShouldCache: false
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return NSImage(data: data)
            }
            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }
    }

    // MARK: - Transport controls

    public func resetActiveSource() {
        setLastActiveSource(nil)
    }

    private let knownBrowsers: Set<String> = [
        "com.brave.Browser",
        "com.google.Chrome",
        "com.apple.Safari",
        "company.thebrowser.Browser",
        "com.microsoft.edgemac"
    ]

    // B4: dispatch AppleScript to `scriptQueue`, return true optimistically,
    // schedule a refresh so the authoritative state catches up.
    @discardableResult
    public func togglePlayPause(targetBundleId: String? = nil) -> Bool {
        let activeSource = targetBundleId ?? lastActiveSource
        scheduleTransport(action: .playPause, activeSource: activeSource)
        return true
    }

    @discardableResult
    public func nextTrack(targetBundleId: String? = nil) -> Bool {
        let activeSource = targetBundleId ?? lastActiveSource
        scheduleTransport(action: .next, activeSource: activeSource)
        return true
    }

    @discardableResult
    public func previousTrack(targetBundleId: String? = nil) -> Bool {
        let activeSource = targetBundleId ?? lastActiveSource
        scheduleTransport(action: .previous, activeSource: activeSource)
        return true
    }

    private func scheduleTransport(action: MediaTransportAction, activeSource: String?) {
        scriptQueue.async { [weak self] in
            guard let self = self else { return }
            self.performTransport(action: action, activeSource: activeSource)
            // Give the player a moment to react, then reconcile.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NowPlayingModule.shared.refreshMediaState(force: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                NowPlayingModule.shared.refreshMediaState(force: true)
            }
        }
    }

    private func performTransport(action: MediaTransportAction, activeSource: String?) {
        // Spotify / Music: direct AppleScript.
        if activeSource == "com.spotify.client" && isAppRunning(bundleId: "com.spotify.client") {
            switch action {
            case .playPause: _ = runAppleScript("tell application \"Spotify\" to playpause"); return
            case .next:      _ = runAppleScript("tell application \"Spotify\" to next track"); return
            case .previous:  _ = runAppleScript("tell application \"Spotify\" to previous track"); return
            }
        }
        if activeSource == "com.apple.Music" && isAppRunning(bundleId: "com.apple.Music") {
            switch action {
            case .playPause: _ = runAppleScript("tell application \"Music\" to playpause"); return
            case .next:      _ = runAppleScript("tell application \"Music\" to next track"); return
            case .previous:  _ = runAppleScript("tell application \"Music\" to previous track"); return
            }
        }
        // Browser: try per-tab JS, fall back to media keys.
        if let source = activeSource, knownBrowsers.contains(source) {
            if controlBrowser(bundleId: source, action: action) { return }
        }
        // Native players via MediaRemote.
        if let send = sendCommand {
            let cmd: UInt32
            switch action {
            case .playPause: cmd = 2
            case .next: cmd = 4
            case .previous: cmd = 5
            }
            if send(cmd, nil) != 0 { return }
        }
        // Last resort: system media keys. B1: single delivery path.
        let key: Int32
        switch action {
        case .playPause: key = 16
        case .next: key = 19
        case .previous: key = 20
        }
        _ = postMediaKeyEvent(key: key)
    }

    // B2: on browsers, only dispatch a click on real next/prev controls.
    // Never seek ±10s as a "next/previous" substitute.
    // B3: scan every tab; the JS itself checks the page has a real control.
    private func controlBrowser(bundleId: String, action: MediaTransportAction) -> Bool {
        let jsCode: String
        switch action {
        case .playPause:
            jsCode = "const m = document.querySelector('video, audio'); if (m) { m.paused ? m.play() : m.pause(); true } else { false }"
        case .next:
            jsCode = "const n = document.querySelector('.ytp-next-button'); if (n) { n.click(); true } else { false }"
        case .previous:
            jsCode = "const p = document.querySelector('.ytp-prev-button'); if (p) { p.click(); true } else { false }"
        }

        let src: String
        if bundleId == "com.apple.Safari" {
            src = """
            tell application "Safari"
                repeat with w in windows
                    repeat with t in (tabs of w)
                        set u to URL of t
                        if u contains "youtube.com" or u contains "youtu.be" or u contains "spotify.com" or u contains "music.apple.com" or u contains "soundcloud.com" or u contains "netflix.com" or u contains "twitch.tv" then
                            try
                                set res to do JavaScript "\(jsCode)" in t
                                if res is true or res is "true" then return true
                            end try
                        end if
                    end repeat
                end repeat
            end tell
            return false
            """
        } else {
            src = """
            tell application id "\(bundleId)"
                repeat with w in windows
                    repeat with t in (tabs of w)
                        set u to URL of t
                        if u contains "youtube.com" or u contains "youtu.be" or u contains "spotify.com" or u contains "music.apple.com" or u contains "soundcloud.com" or u contains "netflix.com" or u contains "twitch.tv" then
                            try
                                set res to execute t javascript "\(jsCode)"
                                if res is true or res is "true" then return true
                            end try
                        end if
                    end repeat
                end repeat
            end tell
            return false
            """
        }
        return runAppleScript(src)
    }

    @discardableResult
    public func runAppleScript(_ source: String) -> Bool {
        // Must be called from `scriptQueue`; transport runs there.
        guard let script = NSAppleScript(source: source) else {
            NSLog("[MediaRemoteBridge] Failed to create NSAppleScript")
            return false
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let err = error {
            let msg = err[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            let num = err[NSAppleScript.errorNumber] as? Int ?? 0
            NSLog("[MediaRemoteBridge] AppleScript error (%d): %@", num, msg)
            return false
        }
        if let str = result.stringValue, str.lowercased() == "false" {
            return false
        }
        return true
    }

    public func isAppRunning(bundleId: String) -> Bool {
        return NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleId })
    }

    public func iconForBundle(_ bundleId: String) -> NSImage? {
        cacheLock.lock()
        if let cached = appIconCache[bundleId] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 64, height: 64)

        cacheLock.lock()
        appIconCache[bundleId] = icon
        cacheLock.unlock()
        return icon
    }

    public func displayNameForBundle(_ bundleId: String?) -> String? {
        guard let bid = bundleId,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) else {
            return nil
        }
        return FileManager.default.displayName(atPath: appURL.path)
    }

    // B10: protect scan cache with cacheLock.
    private func findActiveMediaAppBundleId() -> String? {
        let now = Date()
        cacheLock.lock()
        let cached = cachedRunningPlayerId
        let lastScan = lastRunningAppsScan
        if let cached = cached, now.timeIntervalSince(lastScan) < 4.0 {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let knownPlayers = [
            "com.apple.Music",
            "com.spotify.client",
            "com.colliderli.iina",
            "org.videolan.vlc"
        ]
        let runningSet = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let found = knownPlayers.first(where: { runningSet.contains($0) })

        cacheLock.lock()
        cachedRunningPlayerId = found
        lastRunningAppsScan = now
        cacheLock.unlock()
        return found
    }

    // B1: post to exactly one route per event. Prefer direct-to-PID when
    // available (that's the only route an app actually sees); otherwise use
    // the system HID/session tap. Never both.
    @discardableResult
    private func postMediaKeyEvent(key: Int32, targetPid: pid_t? = nil) -> Bool {
        let down = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int((key << 16) | (0xa << 8)),
            data2: -1
        )
        let up = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int((key << 16) | (0xb << 8)),
            data2: -1
        )
        guard let downEvent = down?.cgEvent, let upEvent = up?.cgEvent else { return false }

        if let pid = targetPid, let postFunc = postToPidFunc {
            postFunc(pid, downEvent)
            postFunc(pid, upEvent)
            return true
        }

        let canUseHID = CGPreflightPostEventAccess()
        let tap: CGEventTapLocation = canUseHID ? .cghidEventTap : .cgSessionEventTap
        downEvent.post(tap: tap)
        upEvent.post(tap: tap)
        return true
    }
}