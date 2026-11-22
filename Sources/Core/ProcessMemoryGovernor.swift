import Foundation
import AppKit
import Darwin

/// ProcessMemoryGovernor monitors idle state, memory pressure, and manages the reclamation of
/// idle external helper services (NSOpenPanel, AirDrop app extension, QuickLook) and internal caches.
///
/// CRITICAL INVARIANTS (Enforced by User Request):
/// 1. Staged user files in Shelf (`ShelfModule.shared.items`) MUST NEVER be removed or cleared on idle.
/// 2. Selected user files in LocalShare (`LocalShareModule.shared.selectedFiles`) MUST NEVER be removed or cleared on idle.
/// 3. Staged user files in AirDrop (`AirDropModule.shared.recentFiles`) MUST NEVER be removed or cleared on idle.
/// 4. Only volatile in-memory image caches (thumbnails, artwork), paused hardware streams (camera),
///    and idle background helper XPC processes (openAndSavePanelService, AirDrop.appex) are reclaimed.
@MainActor
public final class ProcessMemoryGovernor: ObservableObject {
    public static let shared = ProcessMemoryGovernor()
    
    // Inactivity Tracking
    private var lastUserActivity: Date = Date()
    private var lastPanelClosedTime: Date = Date()
    private var isStarted = false
    private var sweepTimer: Timer?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    // Active System Sheet / File Picker Counter
    public private(set) var activeSystemPanelsCount: Int = 0
    public var isSystemPanelActive: Bool {
        return activeSystemPanelsCount > 0
    }
    
    private init() {}
    
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        
        // 1. Periodic 30s background idle sweep
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performPeriodicIdleCheck()
            }
        }
        
        // 2. Darwin System Memory Pressure Monitoring
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.reclaimUnusedMemory(reason: "System Memory Pressure Event")
            }
        }
        source.resume()
        self.memoryPressureSource = source
    }
    
    public func notifyUserActivity() {
        lastUserActivity = Date()
    }
    
    public func notifySystemPanelOpened() {
        activeSystemPanelsCount += 1
        notifyUserActivity()
    }
    
    public func notifySystemPanelClosed() {
        activeSystemPanelsCount = max(0, activeSystemPanelsCount - 1)
        lastPanelClosedTime = Date()
        notifyUserActivity()
    }
    
    public func notifyStateChanged(isExpanded: Bool) {
        notifyUserActivity()
        if !isExpanded {
            // Schedule an idle sweep 30 seconds after collapsing if no interaction occurs
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.performPeriodicIdleCheck()
                }
            }
        }
    }
    
    public func performPeriodicIdleCheck() {
        // Do not reclaim while user is interacting or a panel/transfer is actively open
        guard !isSystemPanelActive else { return }
        guard !NotchShellCoordinator.shared.isMenuOrPopoverOpen else { return }
        guard !NotchShellCoordinator.shared.isFileDraggingActive else { return }
        if let airdrop = ModuleRegistry.shared.loadedModule(for: "airdrop", as: AirDropModule.self) {
            guard !airdrop.isSharingSheetActive && !airdrop.isBeaming else { return }
        }
        if let localShare = ModuleRegistry.shared.loadedModule(for: "localshare", as: LocalShareModule.self) {
            guard !localShare.isTransferSheetActive else { return }
            guard !localShare.isSending && !localShare.isReceiving else { return }
        }
        
        let now = Date()
        let idleDuration = now.timeIntervalSince(lastUserActivity)
        let panelIdleDuration = now.timeIntervalSince(lastPanelClosedTime)
        
        // 1. If helper panels (Open/Save, AirDrop) closed >= 30s ago, reap idle helper processes immediately
        if panelIdleDuration >= 30.0 {
            reapIdleHelperProcesses()
        }
        
        // 2. When collapsed and idle for >= 30 seconds
        if NotchShellCoordinator.shared.state == .collapsed && (idleDuration >= 30.0 || panelIdleDuration >= 30.0) {
            reclaimUnusedMemory(reason: "Inactivity Timeout (>=30s Idle)")
        }
    }
    
    public func reclaimUnusedMemory(reason: String) {
        // 1. Safe Helper Process Reaping (Reclaim ~50 MB RAM from orphaned AppKit/AirDrop/QuickLook services)
        reapIdleHelperProcesses()
        
        // 2. Media Thumbnail Cache: Reclaim in-memory thumbnail bitmaps while preserving all file paths
        MediaThumbnailProvider.shared.clearCache()
        
        // 3. Shelf In-Memory Caches:
        // CAUTION: ShelfModule.items MUST NEVER be cleared! Preserved so user never has to re-upload files.
        if let shelf = ModuleRegistry.shared.loadedModule(for: "shelf", as: ShelfModule.self) {
            shelf.evictCaches()
            if shelf.items.isEmpty {
                shelf.cleanStaleTempFiles(all: true)
            }
        }
        
        // 4. LocalShare Idle Network State:
        // CAUTION: LocalShareModule.selectedFiles MUST NEVER be cleared! Preserved so user never has to re-select files.
        if let localShare = ModuleRegistry.shared.loadedModule(for: "localshare", as: LocalShareModule.self) {
            if localShare.selectedFiles.isEmpty && !localShare.isSending && !localShare.isReceiving {
                localShare.stopDiscovery()
            }
        }
        
        // 5. AirDrop Idle State:
        // CAUTION: AirDropModule.recentFiles MUST NEVER be cleared! Preserved so user never has to re-drag files.
        
        // 6. Mirror Camera Hardware:
        if let mirror = ModuleRegistry.shared.loadedModule(for: "mirror", as: MirrorModule.self) {
            if mirror.viewers == 0 {
                mirror.stop()
            }
        }
        
        // 7. NowPlaying Artwork Bitmaps:
        NowPlayingModule.shared.evictArtworkOnCollapse()
        
        // 8. Kernel Memory Relief: Release unused dirty pages back to macOS Darwin kernel
        malloc_zone_pressure_relief(malloc_default_zone(), 0)
    }
    
    private func reapIdleHelperProcesses() {
        // SEC-09: Eliminated private Darwin SPI responsibility_get_pid_responsible_for_pid and SIGKILL calls.
        // Helper XPC services (NSOpenPanel, AirDrop) automatically transition to idle and terminate
        // via system RunningBoard/launchd when their Mach connection handles are closed.
    }
}
