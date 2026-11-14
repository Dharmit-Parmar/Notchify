import Foundation
import AppKit
import Darwin

@_silgen_name("responsibility_get_pid_responsible_for_pid")
private func responsibility_get_pid_responsible_for_pid(_ pid: pid_t) -> pid_t

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
        guard !AirDropModule.shared.isSharingSheetActive && !AirDropModule.shared.isBeaming else { return }
        guard !LocalShareModule.shared.isSending && !LocalShareModule.shared.isReceiving else { return }
        
        let now = Date()
        let idleDuration = now.timeIntervalSince(lastUserActivity)
        let panelIdleDuration = now.timeIntervalSince(lastPanelClosedTime)
        
        // When collapsed and idle for >= 30 seconds (or panel has been closed for >= 30s)
        if NotchShellCoordinator.shared.state == .collapsed && (idleDuration >= 30.0 || panelIdleDuration >= 30.0) {
            reclaimUnusedMemory(reason: "Inactivity Timeout (>=30s Idle)")
        }
    }
    
    public func reclaimUnusedMemory(reason: String) {
        // 1. Safe Helper Process Reaping (Reclaim ~50 MB RAM from orphaned AppKit/AirDrop services)
        reapIdleHelperProcesses()
        
        // 2. Shelf In-Memory Caches:
        // CAUTION: ShelfModule.shared.items MUST NEVER be cleared! Preserved so user never has to re-upload files.
        ShelfModule.shared.evictCaches()
        if ShelfModule.shared.items.isEmpty {
            ShelfModule.shared.cleanStaleTempFiles(all: true)
        }
        
        // 3. LocalShare Idle Network State:
        // CAUTION: LocalShareModule.shared.selectedFiles MUST NEVER be cleared! Preserved so user never has to re-select files.
        let localShare = LocalShareModule.shared
        if localShare.selectedFiles.isEmpty && !localShare.isSending && !localShare.isReceiving {
            localShare.stopDiscovery()
        }
        
        // 4. AirDrop Idle State:
        // CAUTION: AirDropModule.shared.recentFiles MUST NEVER be cleared!
        // Helper processes have already been evaluated and reaped in step 1.
        
        // 5. Mirror Camera Hardware:
        if MirrorModule.shared.viewers == 0 {
            MirrorModule.shared.stop()
        }
        
        // 6. NowPlaying Artwork Bitmaps:
        NowPlayingModule.shared.evictArtworkOnCollapse()
        
        // 7. Kernel Memory Relief: Release unused dirty pages back to macOS Darwin kernel
        malloc_zone_pressure_relief(malloc_default_zone(), 0)
    }
    
    private func reapIdleHelperProcesses() {
        guard !isSystemPanelActive else { return }
        guard !AirDropModule.shared.isSharingSheetActive && !AirDropModule.shared.isBeaming else { return }
        guard !NotchShellCoordinator.shared.isMenuOrPopoverOpen else { return }
        
        let myPid = getpid()
        let myUID = geteuid()
        
        var pids = [pid_t](repeating: 0, count: 2048)
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.stride * pids.count))
        guard byteCount > 0 else { return }
        let count = Int(byteCount) / MemoryLayout<pid_t>.stride
        
        var pathBuf = [CChar](repeating: 0, count: 4096)
        var pidsToKill: [pid_t] = []
        
        for i in 0..<count {
            let pid = pids[i]
            guard pid > 1 && pid != myPid else { continue }
            
            var bsdInfo = proc_bsdinfo()
            let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
            guard size > 0, bsdInfo.pbi_uid == myUID else { continue }
            
            let pathLen = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
            guard pathLen > 0 else { continue }
            let path = pathBuf.withUnsafeBufferPointer { ptr in
                String(cString: ptr.baseAddress!)
            }
            
            let isOpenSave = path.contains("openAndSavePanelService")
            let isAirDrop = path.contains("AirDrop.appex")
            let isQuickLook = path.contains("QuickLookUIService")
            
            guard isOpenSave || isAirDrop || isQuickLook else { continue }
            
            let responsiblePid = responsibility_get_pid_responsible_for_pid(pid)
            
            if isOpenSave && responsiblePid == myPid {
                pidsToKill.append(pid)
            } else if isAirDrop && (responsiblePid == myPid || responsiblePid == pid) {
                pidsToKill.append(pid)
            } else if isQuickLook && (responsiblePid == myPid || pidsToKill.contains(responsiblePid)) {
                pidsToKill.append(pid)
            }
        }
        
        for pid in pidsToKill {
            kill(pid, SIGKILL)
        }
    }
}
