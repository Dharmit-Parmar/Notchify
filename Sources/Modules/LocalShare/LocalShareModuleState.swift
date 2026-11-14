import Foundation
import Combine
import AppKit

// MARK: - LocalShare Module State & Engine (Target: LocalShare Library)
@MainActor
public final class LocalShareModuleState: ObservableObject, @unchecked Sendable {
    public static let shared = LocalShareModuleState()
    
    // Metadata
    public let id = "localshare"
    public let title = "Local Share"
    public let iconName = "shareplay"
    @Published public var isEnabled: Bool = true
    
    // Status & Discovered Peers
    @Published public var statusMessage: String = "Ready to share with nearby devices"
    @Published public var isDropTargeted: Bool = false
    @Published public var isReceiveActive: Bool = false
    @Published public var isScanning: Bool = false
    @Published public var discoveredPeers: [LocalShareDiscoveredPeer] = []
    @Published public var selectedFiles: [URL] = []
    
    // Active Transfer State
    @Published public var isSending: Bool = false
    @Published public var isReceiving: Bool = false
    @Published public var transferProgress: Double = 0.0
    @Published public var activePeerAlias: String? = nil
    @Published public var incomingSession: LocalShareSession? = nil
    @Published public var recentTransfers: [LocalShareHistoryItem] = []
    
    public var activeClientSession: LocalShareClientSession?
    public var pendingAcceptanceCompletion: ((Bool) -> Void)?
    private let historyStorageKey = "NotchApp_LocalShare_RecentTransfers"
    
    public init() {
        loadRecentHistory()
        configureServerHooks()
        
        _ = LocalShareDiscovery.shared.addPeersObserver { [weak self] peers in
            Task { @MainActor in
                self?.discoveredPeers = peers
            }
        }
    }
    
    // MARK: - Lifecycle Management
    
    public func start() {
        if LocalShareSettings.shared.isReceiveEnabled {
            startReceiver()
        }
        startDiscovery()
    }
    
    public func stop() {
        if !isSending && !isReceiving {
            stopDiscovery()
        }
        if !LocalShareSettings.shared.isReceiveEnabled {
            stopReceiver()
        }
    }
    
    public func startDiscovery() {
        LocalShareDiscovery.shared.start(
            alias: LocalShareSettings.shared.alias,
            port: LocalShareSettings.shared.tcpPort,
            enableMulticast: true
        )
    }
    
    public func stopDiscovery() {
        LocalShareDiscovery.shared.stop()
    }
    
    public func rescan() {
        guard !isScanning else { return }
        isScanning = true
        statusMessage = "Scanning for nearby devices..."
        LocalShareDiscovery.shared.rescan()
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self.isScanning = false
            self.updateStatusMessage()
        }
    }
    
    public func syncReceiveMode(_ enabled: Bool) {
        if enabled {
            startReceiver()
        } else {
            stopReceiver()
        }
    }
    
    public func startReceiver() {
        do {
            try LocalShareServer.shared.start(
                port: LocalShareSettings.shared.tcpPort,
                bindInterface: .localNetwork,
                enableTLS: true
            )
            isReceiveActive = true
            updateStatusMessage()
        } catch {
            isReceiveActive = false
            statusMessage = "Receiver error: \(error.localizedDescription)"
        }
    }
    
    public func stopReceiver() {
        LocalShareServer.shared.stop()
        isReceiveActive = false
        updateStatusMessage()
    }
    
    public func updateStatusMessage() {
        if isSending {
            statusMessage = "Sending to \(activePeerAlias ?? "peer")..."
        } else if isReceiving {
            statusMessage = "Receiving from \(activePeerAlias ?? "peer")..."
        } else if isReceiveActive {
            statusMessage = "Waiting for nearby Local Share devices"
        } else {
            statusMessage = "Receive OFF — Ready to send"
        }
    }
    
    // MARK: - Incoming Transfer Hooks
    
    private func configureServerHooks() {
        _ = LocalShareServer.shared.addStateObserver { [weak self] newState in
            Task { @MainActor in
                guard let self = self else { return }
                switch newState {
                case .running:
                    self.isReceiveActive = true
                    self.updateStatusMessage()
                case .stopped:
                    self.isReceiveActive = false
                    self.updateStatusMessage()
                case .failed(let err):
                    self.isReceiveActive = false
                    self.statusMessage = "Receiver error: \(err)"
                case .starting:
                    break
                }
            }
        }
        
        // Only attach fallback incoming transfer hook if authoritative UI module has not attached
        if LocalShareServer.shared.onIncomingSessionOffered == nil {
            LocalShareServer.shared.onIncomingSessionOffered = { [weak self] session, completion in
                Task { @MainActor in
                    guard let self = self else {
                        completion(false)
                        return
                    }
                    self.incomingSession = session
                    self.pendingAcceptanceCompletion = completion
                }
            }
        }
    }
    
    public func acceptIncomingTransfer() {
        guard let session = incomingSession, let completion = pendingAcceptanceCompletion else { return }
        pendingAcceptanceCompletion = nil
        self.isReceiving = true
        self.activePeerAlias = session.peerInfo.alias
        self.statusMessage = "Receiving from \(session.peerInfo.alias)..."
        completion(true)
        
        observeIncomingSessionProgress(session)
    }
    
    public func declineIncomingTransfer() {
        guard let completion = pendingAcceptanceCompletion else { return }
        pendingAcceptanceCompletion = nil
        let session = incomingSession
        self.incomingSession = nil
        completion(false)
        updateStatusMessage()
        
        if let session = session {
            LocalShareSessionCoordinator.shared.cancelSession(sessionId: session.sessionId, reason: "Declined by user")
            addHistoryItem(
                peerAlias: session.peerInfo.alias,
                fileNames: session.filesMetadata.values.map { $0.fileName },
                totalBytes: session.filesMetadata.values.reduce(0) { $0 + $1.size },
                isOutgoing: false,
                statusText: "Declined"
            )
        }
    }
    
    public func observeIncomingSessionProgress(_ session: LocalShareSession) {
        Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self = self else { return }
                let state = session.currentState
                self.transferProgress = session.overallFraction
                
                switch state {
                case .completed:
                    self.isReceiving = false
                    self.incomingSession = nil
                    self.statusMessage = "Transfer complete"
                    
                    self.addHistoryItem(
                        peerAlias: session.peerInfo.alias,
                        fileNames: session.filesMetadata.values.map { $0.fileName },
                        totalBytes: session.filesMetadata.values.reduce(0) { $0 + $1.size },
                        isOutgoing: false,
                        statusText: "Completed"
                    )
                    return
                case .failed(let err):
                    self.isReceiving = false
                    self.incomingSession = nil
                    self.statusMessage = "Receive failed: \(err.localizedDescription)"
                    
                    self.addHistoryItem(
                        peerAlias: session.peerInfo.alias,
                        fileNames: session.filesMetadata.values.map { $0.fileName },
                        totalBytes: session.filesMetadata.values.reduce(0) { $0 + $1.size },
                        isOutgoing: false,
                        statusText: "Failed"
                    )
                    return
                case .cancelled:
                    self.isReceiving = false
                    self.incomingSession = nil
                    self.statusMessage = "Transfer cancelled"
                    return
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Outgoing Transfers
    
    private func expandDirectoriesIfNeeded(in urls: [URL]) -> [URL] {
        var expanded: [URL] = []
        let fm = FileManager.default
        for url in urls {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        if let res = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]), res.isRegularFile == true {
                            expanded.append(fileURL)
                        }
                    }
                }
            } else {
                expanded.append(url)
            }
        }
        return expanded
    }
    
    public func startSending(files: [URL]) {
        let expanded = expandDirectoriesIfNeeded(in: files)
        guard !expanded.isEmpty else { return }
        for f in expanded {
            if !selectedFiles.contains(f) {
                selectedFiles.append(f)
            }
        }
        startDiscovery()
        updateStatusMessage()
    }
    
    public func shareClipboardText() {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "Clipboard is empty"
            return
        }
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Snippet_\(Int(Date().timeIntervalSince1970)).txt"
        let fileURL = tempDir.appendingPathComponent(fileName)
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            startSending(files: [fileURL])
            statusMessage = "Ready to send text snippet"
        } catch {
            statusMessage = "Failed to prepare text snippet"
        }
    }
    
    public func removeSelectedFile(_ url: URL) {
        selectedFiles.removeAll(where: { $0 == url })
    }
    
    public func clearSelectedFiles() {
        selectedFiles.removeAll()
    }
    
    public func sendFiles(to peer: LocalShareDiscoveredPeer, pin: String? = nil) async throws {
        guard !selectedFiles.isEmpty else { return }
        let filesToSend = self.selectedFiles
        self.isSending = true
        self.activePeerAlias = peer.alias
        self.transferProgress = 0.0
        self.statusMessage = "Connecting to \(peer.alias)..."
        
        do {
            let (clientSession, prepResp) = try await LocalShareClient.shared.prepareUpload(
                to: peer,
                fileURLs: filesToSend,
                pin: pin
            )
            self.activeClientSession = clientSession
            self.statusMessage = "Sending to \(peer.alias)..."
            
            let totalBytes = filesToSend.reduce(Int64(0)) { acc, url in
                acc + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
            
            try await LocalShareClient.shared.uploadFiles(
                session: clientSession,
                prepResp: prepResp,
                maxConcurrency: 2
            ) { overallFraction in
                Task { @MainActor in
                    self.transferProgress = overallFraction
                }
            }
            
            self.isSending = false
            self.activeClientSession = nil
            self.selectedFiles.removeAll()
            self.statusMessage = "Sent \(filesToSend.count) file(s) to \(peer.alias)"
            
            self.addHistoryItem(
                peerAlias: peer.alias,
                fileNames: filesToSend.map { $0.lastPathComponent },
                totalBytes: totalBytes,
                isOutgoing: true,
                statusText: "Completed"
            )
        } catch {
            self.isSending = false
            self.activeClientSession = nil
            self.statusMessage = "Send failed: \(error.localizedDescription)"
            
            self.addHistoryItem(
                peerAlias: peer.alias,
                fileNames: filesToSend.map { $0.lastPathComponent },
                totalBytes: 0,
                isOutgoing: true,
                statusText: "Failed"
            )
            throw error
        }
    }
    
    public func cancelActiveTransfer() {
        if let client = activeClientSession {
            Task {
                await LocalShareClient.shared.cancelSession(client)
            }
            activeClientSession = nil
        }
        
        if let session = incomingSession {
            LocalShareSessionCoordinator.shared.cancelSession(sessionId: session.sessionId, reason: "Cancelled by user")
            incomingSession = nil
        }
        
        isSending = false
        isReceiving = false
        statusMessage = "Transfer cancelled"
        updateStatusMessage()
    }
    
    // MARK: - Bounded History
    
    public func addHistoryItem(peerAlias: String, fileNames: [String], totalBytes: Int64, isOutgoing: Bool, statusText: String) {
        let item = LocalShareHistoryItem(
            peerAlias: peerAlias,
            fileNames: fileNames,
            totalBytes: totalBytes,
            isOutgoing: isOutgoing,
            statusText: statusText
        )
        recentTransfers.insert(item, at: 0)
        if recentTransfers.count > 10 {
            recentTransfers = Array(recentTransfers.prefix(10))
        }
        saveRecentHistory()
    }
    
    private func saveRecentHistory() {
        if let data = try? JSONEncoder().encode(recentTransfers) {
            UserDefaults.standard.set(data, forKey: historyStorageKey)
        }
    }
    
    public func loadRecentHistory() {
        if let data = UserDefaults.standard.data(forKey: historyStorageKey),
           let items = try? JSONDecoder().decode([LocalShareHistoryItem].self, from: data) {
            self.recentTransfers = items
        }
    }
}
