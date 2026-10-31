import Foundation
import AppKit
import ImageIO

public struct SystemMediaTrack: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: Double
    public let elapsedTime: Double
    public let isPlaying: Bool
    public let artwork: NSImage?
    public let bundleIdentifier: String?
    public let sourceApp: String
}

public final class MediaRemoteBridge: @unchecked Sendable {
    public static let shared = MediaRemoteBridge()
    
    private typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRMediaRemoteGetNowPlayingClientFunction = @convention(c) (DispatchQueue, @escaping (AnyObject?) -> Void) -> Void
    private typealias MRMediaRemoteGetNowPlayingApplicationPIDFunction = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
    private typealias MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias MRMediaRemoteRegisterFunction = @convention(c) (DispatchQueue) -> Void
    private typealias MRMediaRemoteSendCommandFunction = @convention(c) (UInt32, CFDictionary?) -> Bool
    
    private var getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction?
    private var getNowPlayingClient: MRMediaRemoteGetNowPlayingClientFunction?
    private var getNowPlayingApplicationPID: MRMediaRemoteGetNowPlayingApplicationPIDFunction?
    private var getNowPlayingApplicationIsPlaying: MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction?
    private var registerForNotifications: MRMediaRemoteRegisterFunction?
    private var sendCommand: MRMediaRemoteSendCommandFunction?
    
    private var cachedBundleId: String? = nil
    private var cachedAppIcon: NSImage? = nil
    private var cachedIsPlaying: Bool = false
    private var cachedArtworkData: Data?
    private var cachedArtworkImage: NSImage?
    private var appIconCache: [String: NSImage] = [:]
    
    public func clearCachedArtwork() {
        cachedArtworkData = nil
        cachedArtworkImage = nil
        cachedAppIcon = nil
        if appIconCache.count > 5 {
            appIconCache.removeAll()
        }
    }
    
    private init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) {
            if let getSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
                getNowPlayingInfo = unsafeBitCast(getSym, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
            }
            if let clientSym = dlsym(handle, "MRMediaRemoteGetNowPlayingClient") {
                getNowPlayingClient = unsafeBitCast(clientSym, to: MRMediaRemoteGetNowPlayingClientFunction.self)
            }
            if let pidSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") {
                getNowPlayingApplicationPID = unsafeBitCast(pidSym, to: MRMediaRemoteGetNowPlayingApplicationPIDFunction.self)
            }
            if let isPlayingSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
                getNowPlayingApplicationIsPlaying = unsafeBitCast(isPlayingSym, to: MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction.self)
            }
            if let regSym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
                registerForNotifications = unsafeBitCast(regSym, to: MRMediaRemoteRegisterFunction.self)
            }
            if let cmdSym = dlsym(handle, "MRMediaRemoteSendCommand") {
                sendCommand = unsafeBitCast(cmdSym, to: MRMediaRemoteSendCommandFunction.self)
            }
            registerForNotifications?(DispatchQueue.main)
        }
    }
    
    public func fetchCurrentTrack(completion: @escaping @Sendable (SystemMediaTrack?) -> Void) {
        guard let getInfo = getNowPlayingInfo else {
            completion(nil)
            return
        }
        
        // 1. Query PID of active media application first
        if let getPID = getNowPlayingApplicationPID {
            getPID(DispatchQueue.main) { [weak self] pid in
                guard let self = self else { completion(nil); return }
                if pid > 0, let app = NSRunningApplication(processIdentifier: pid) {
                    if self.cachedBundleId != app.bundleIdentifier {
                        self.cachedBundleId = app.bundleIdentifier
                        let icon = app.icon
                        icon?.size = NSSize(width: 128, height: 128)
                        self.cachedAppIcon = icon
                    }
                }
                self.fetchPlaybackStatusAndInfo(getInfo: getInfo, completion: completion)
            }
        } else {
            fetchPlaybackStatusAndInfo(getInfo: getInfo, completion: completion)
        }
    }
    
    private func fetchPlaybackStatusAndInfo(
        getInfo: @escaping MRMediaRemoteGetNowPlayingInfoFunction,
        completion: @escaping @Sendable (SystemMediaTrack?) -> Void
    ) {
        // 2. Query system playback active state
        if let getPlaying = getNowPlayingApplicationIsPlaying {
            getPlaying(DispatchQueue.main) { [weak self] isPlaying in
                guard let self = self else { completion(nil); return }
                self.cachedIsPlaying = isPlaying
                self.fetchTrackMetadata(getInfo: getInfo, completion: completion)
            }
        } else {
            fetchTrackMetadata(getInfo: getInfo, completion: completion)
        }
    }
    
    private func fetchTrackMetadata(
        getInfo: @escaping MRMediaRemoteGetNowPlayingInfoFunction,
        completion: @escaping @Sendable (SystemMediaTrack?) -> Void
    ) {
        // 3. Fetch track metadata
        getInfo(DispatchQueue.main) { [weak self] info in
            guard let self = self else { completion(nil); return }
            
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
            let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0.0
            let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0
            let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0
            let isPlaying = (rate > 0.0) || self.cachedIsPlaying
            
            var artworkImage: NSImage? = nil
            if let artData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                if self.cachedArtworkData?.count != artData.count || self.cachedArtworkData != artData {
                    self.cachedArtworkData = artData
                    self.cachedArtworkImage = Self.makeArtworkImage(from: artData)
                }
                artworkImage = self.cachedArtworkImage
            } else {
                self.cachedArtworkData = nil
                self.cachedArtworkImage = nil
            }
            
            let bundleId = self.cachedBundleId ?? self.findActiveMediaAppBundleId()
            
            // High-resolution app icon fallback when artwork is absent
            if artworkImage == nil {
                artworkImage = self.cachedAppIcon ?? (bundleId != nil ? self.iconForBundle(bundleId!) : nil)
            }
            
            let appDisplayName = self.displayNameForBundle(bundleId) ?? "Media Player"
            
            if title.isEmpty && artist.isEmpty {
                if let bid = bundleId {
                    let fallbackTrack = SystemMediaTrack(
                        title: "Audio Active",
                        artist: appDisplayName,
                        album: "",
                        duration: 0.0,
                        elapsedTime: 0.0,
                        isPlaying: isPlaying,
                        artwork: artworkImage,
                        bundleIdentifier: bid,
                        sourceApp: appDisplayName
                    )
                    completion(fallbackTrack)
                } else {
                    completion(nil)
                }
            } else {
                let track = SystemMediaTrack(
                    title: title.isEmpty ? "Media Playing" : title,
                    artist: artist.isEmpty ? appDisplayName : artist,
                    album: album,
                    duration: duration,
                    elapsedTime: elapsed,
                    isPlaying: isPlaying,
                    artwork: artworkImage,
                    bundleIdentifier: bundleId,
                    sourceApp: appDisplayName
                )
                completion(track)
            }
        }
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
                kCGImageSourceThumbnailMaxPixelSize: 128,
                kCGImageSourceShouldCache: false
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return NSImage(data: data)
            }
            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }
    }
    
    // Command codes: 0 = Play, 1 = Pause, 2 = TogglePlayPause, 4 = NextTrack, 5 = PreviousTrack
    public func togglePlayPause() {
        let handled = sendCommand?(2, nil) ?? false
        if !handled {
            postMediaKeyEvent(key: 16)
        }
    }
    
    public func nextTrack() {
        let handled = sendCommand?(4, nil) ?? false
        if !handled {
            postMediaKeyEvent(key: 19)
        }
    }
    
    public func previousTrack() {
        let handled = sendCommand?(5, nil) ?? false
        if !handled {
            postMediaKeyEvent(key: 20)
        }
    }
    
    public func iconForBundle(_ bundleId: String) -> NSImage? {
        if let cached = appIconCache[bundleId] {
            return cached
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 64, height: 64)
            if appIconCache.count > 10 {
                appIconCache.removeAll()
            }
            appIconCache[bundleId] = icon
            return icon
        }
        return nil
    }
    
    public func displayNameForBundle(_ bundleId: String?) -> String? {
        guard let bid = bundleId,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) else {
            return nil
        }
        return FileManager.default.displayName(atPath: appURL.path)
    }
    
    private var cachedRunningPlayerId: String? = nil
    private var lastRunningAppsScan: Date = .distantPast

    private func findActiveMediaAppBundleId() -> String? {
        let now = Date()
        if let cached = cachedRunningPlayerId, now.timeIntervalSince(lastRunningAppsScan) < 4.0 {
            return cached
        }
        let knownPlayers = [
            "com.brave.Browser",
            "com.google.Chrome",
            "com.apple.Safari",
            "company.thebrowser.Browser",
            "com.spotify.client",
            "com.apple.Music",
            "com.colliderli.iina",
            "org.videolan.vlc"
        ]
        let runningSet = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        lastRunningAppsScan = now
        for player in knownPlayers {
            if runningSet.contains(player) {
                cachedRunningPlayerId = player
                return player
            }
        }
        cachedRunningPlayerId = nil
        return nil
    }
    
    // Hardware media key dispatcher for universal browser audio / video compatibility
    private func postMediaKeyEvent(key: Int32) {
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
        down?.cgEvent?.post(tap: .cghidEventTap)
        up?.cgEvent?.post(tap: .cghidEventTap)
    }
}
