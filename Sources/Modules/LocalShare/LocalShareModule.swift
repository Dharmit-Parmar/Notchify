import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import UserNotifications
import LocalShare

// MARK: - LocalShare Received Message Model
public struct LocalShareReceivedMessage: Identifiable, Sendable {
    public let id = UUID()
    public let peerAlias: String
    public let text: String
    public let fileURL: URL?
    public let timestamp: Date
    
    public init(peerAlias: String, text: String, fileURL: URL?, timestamp: Date = Date()) {
        self.peerAlias = peerAlias
        self.text = text
        self.fileURL = fileURL
        self.timestamp = timestamp
    }
}

// MARK: - LocalShare Main Application Module
@MainActor
public final class LocalShareModule: NSObject, NotchModule, UNUserNotificationCenterDelegate {
    public static let shared = LocalShareModule()
    
    // NotchModule Conformance
    public let id = "localshare"
    public let title = "Local Share"
    public let iconName = "shareplay"
    @Published public var isEnabled: Bool = true
    public var themeColor: Color {
        Color(red: 0.20, green: 0.78, blue: 0.85)
    }
    
    // Status and UI Observables
    @Published public var statusMessage: String = "Ready to share with nearby devices"
    @Published public var isDropTargeted: Bool = false
    @Published public var isReceiveActive: Bool = false
    @Published public var isScanning: Bool = false
    @Published public var discoveredPeers: [LocalShareDiscoveredPeer] = []
    @Published public var selectedFiles: [URL] = [] {
        didSet {
            LocalShareServer.shared.sharedDownloadFiles = selectedFiles
        }
    }
    
    // Active Transfer State
    @Published public var isSending: Bool = false
    @Published public var isReceiving: Bool = false
    @Published public var transferProgress: Double = 0.0
    @Published public var activePeerAlias: String? = nil
    @Published public var incomingSession: LocalShareSession? = nil
    @Published public var recentTransfers: [LocalShareHistoryItem] = []
    @Published public var lastReceivedMessage: LocalShareReceivedMessage? = nil
    
    // Popover & Sheet Coordination
    public private(set) var isTransferSheetActive = false
    private var activeClientSession: LocalShareClientSession?
    private var pendingAcceptanceCompletion: ((Bool) -> Void)?
    private let historyStorageKey = "NotchApp_LocalShare_RecentTransfers"
    
    public override init() {
        super.init()
        loadRecentHistory()
        configureServerHooks()
        
        // Connect discovery update callback via multi-observer
        _ = LocalShareDiscovery.shared.addPeersObserver { [weak self] peers in
            Task { @MainActor in
                self?.discoveredPeers = peers
            }
        }
        
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
        }
        
        if LocalShareSettingsStore.shared.isReceiveEnabled {
            startReceiver()
        }
    }
    
    // MARK: - Lifecycle Management
    
    public func start() {
        // If receive mode is enabled in settings, start server listener
        if LocalShareSettingsStore.shared.isReceiveEnabled {
            startReceiver()
        }
        
        // Start foreground discovery while module is active
        startDiscovery()
    }
    
    public func stop() {
        // Stop foreground discovery if no active transfer in flight
        if !isSending && !isReceiving {
            stopDiscovery()
        }
        
        // Stop receiver listener if receive is disabled
        if !LocalShareSettingsStore.shared.isReceiveEnabled {
            stopReceiver()
        }
    }
    
    public func startDiscovery() {
        LocalShareDiscovery.shared.start(
            alias: LocalShareSettingsStore.shared.alias,
            port: LocalShareSettingsStore.shared.tcpPort,
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
    
    private func startReceiver() {
        do {
            try LocalShareServer.shared.start(
                port: LocalShareSettingsStore.shared.tcpPort,
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
    
    private func stopReceiver() {
        LocalShareServer.shared.stop()
        isReceiveActive = false
        updateStatusMessage()
    }
    
    private func updateStatusMessage() {
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
    
    // MARK: - Popover Lifecycle (registerPopoverOpened / Closed)
    
    public func markTransferActive() {
        guard !isTransferSheetActive else { return }
        isTransferSheetActive = true
        NotchShellCoordinator.shared.registerPopoverOpened()
        NotchShellCoordinator.shared.panel?.level = .floating
        ProcessMemoryGovernor.shared.notifySystemPanelOpened()
    }
    
    public func markTransferFinished() {
        guard isTransferSheetActive else { return }
        isTransferSheetActive = false
        NotchShellCoordinator.shared.panel?.level = .popUpMenu
        NotchShellCoordinator.shared.registerPopoverClosed()
        ProcessMemoryGovernor.shared.notifySystemPanelClosed()
    }
    
    // MARK: - Incoming Request Server Hooks
    
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
        
        LocalShareServer.shared.onIncomingSessionOffered = { [weak self] session, completion in
            Task { @MainActor in
                guard let self = self else {
                    completion(false)
                    return
                }
                
                // Check if Local Share tab is currently visible in expanded notch
                let isLocalShareVisible = (NotchShellCoordinator.shared.state == .expanded && ModuleRegistry.shared.activeModuleId == "localshare")
                if !isLocalShareVisible {
                    self.postIncomingNotification(for: session)
                    withAnimation {
                        NotchShellCoordinator.shared.state = .expanded
                        ModuleRegistry.shared.selectFileDropTarget(for: "localshare")
                    }
                }
                
                self.incomingSession = session
                self.pendingAcceptanceCompletion = completion
                self.markTransferActive()
                FeedbackManager.playHover()
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
        FeedbackManager.playSuccess()
        
        // Track progress in background
        observeIncomingSessionProgress(session)
    }
    
    public func declineIncomingTransfer() {
        guard let completion = pendingAcceptanceCompletion else { return }
        pendingAcceptanceCompletion = nil
        let session = incomingSession
        self.incomingSession = nil
        completion(false)
        markTransferFinished()
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
    
    private func observeIncomingSessionProgress(_ session: LocalShareSession) {
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
                    self.markTransferFinished()
                    FeedbackManager.playSuccess()
                    
                    if let sessionDir = session.sessionDirectory {
                        let savedFiles = LocalShareFileManager.shared.promoteSessionFiles(sessionId: session.sessionId, sessionDirectory: sessionDir)
                        self.detectAndSetReceivedTextMessage(from: session, savedFiles: savedFiles)
                    }
                    
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
                    self.markTransferFinished()
                    
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
                    self.markTransferFinished()
                    return
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Received Text / Message Management
    
    private func detectAndSetReceivedTextMessage(from session: LocalShareSession, savedFiles: [URL]) {
        for (_, meta) in session.filesMetadata {
            let baseName = (meta.fileName as NSString).deletingPathExtension
            let ext = (meta.fileName as NSString).pathExtension.lowercased()
            let matchedURL = savedFiles.first(where: {
                $0.lastPathComponent == meta.fileName ||
                ($0.pathExtension.lowercased() == ext && $0.lastPathComponent.hasPrefix(baseName))
            }) ?? (savedFiles.count == 1 ? savedFiles.first : nil)
            
            // Check if preview already contains message string
            if let preview = meta.preview, !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.lastReceivedMessage = LocalShareReceivedMessage(
                    peerAlias: session.peerInfo.alias,
                    text: preview,
                    fileURL: matchedURL
                )
                self.statusMessage = "Received message from \(session.peerInfo.alias)"
                return
            }
            
            let isTextType = meta.fileType.hasPrefix("text/") ||
                             ext == "txt" || ext == "md" || ext == "json" || ext == "log"
            
            if isTextType, let fileURL = matchedURL {
                if let content = try? String(contentsOf: fileURL, encoding: .utf8),
                   !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.lastReceivedMessage = LocalShareReceivedMessage(
                        peerAlias: session.peerInfo.alias,
                        text: content,
                        fileURL: fileURL
                    )
                    self.statusMessage = "Received message from \(session.peerInfo.alias)"
                    return
                }
            }
        }
    }
    
    public func copyReceivedMessageText(_ message: LocalShareReceivedMessage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.text, forType: .string)
        statusMessage = "Message copied to clipboard"
        FeedbackManager.playSuccess()
    }
    
    public func saveReceivedMessageToFile(_ message: LocalShareReceivedMessage) {
        FeedbackManager.playClick()
        let savePanel = NSSavePanel()
        savePanel.title = "Save Received Message"
        savePanel.nameFieldStringValue = message.fileURL?.lastPathComponent ?? "Message_\(Int(message.timestamp.timeIntervalSince1970)).txt"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.prompt = "Save"
        
        markTransferActive()
        NSApp.activate(ignoringOtherApps: true)
        savePanel.begin { [weak self] response in
            guard let self = self else { return }
            self.markTransferFinished()
            if response == .OK, let targetURL = savePanel.url {
                do {
                    try message.text.write(to: targetURL, atomically: true, encoding: .utf8)
                    self.statusMessage = "Message saved to \(targetURL.lastPathComponent)"
                    FeedbackManager.playSuccess()
                } catch {
                    self.statusMessage = "Failed to save message: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Outgoing File Transfer
    
    private func expandDirectoriesIfNeeded(in urls: [URL]) -> [URL] {
        var expanded: [URL] = []
        let fm = FileManager.default
        let ws = NSWorkspace.shared
        for url in urls {
            guard url.isFileURL else {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("WebLink_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(4)).txt")
                if (try? url.absoluteString.write(to: tempURL, atomically: true, encoding: .utf8)) != nil {
                    expanded.append(tempURL)
                }
                continue
            }
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if ws.isFilePackage(atPath: url.path) {
                    expanded.append(url)
                    continue
                }
                if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
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
        guard !expanded.isEmpty else {
            statusMessage = "No files found or folder is empty"
            return
        }
        for f in expanded {
            if !selectedFiles.contains(f) {
                selectedFiles.append(f)
            }
        }
        
        // Select Local Share tab in registry
        ModuleRegistry.shared.selectFileDropTarget(for: "localshare")
        startDiscovery()
        updateStatusMessage()
    }
    
    public func shareClipboardText() {
        pasteFromClipboard()
    }
    
    public func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        
        // 1. File URLs in clipboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let fileURLs = urls.filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }
            if !fileURLs.isEmpty {
                startSending(files: fileURLs)
                statusMessage = "Pasted \(fileURLs.count) file(s) from clipboard"
                FeedbackManager.playSuccess()
                return
            }
        }
        
        // 2. Image in clipboard
        if let image = NSImage(pasteboard: pasteboard),
           let tiffData = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiffData),
           let pngData = rep.representation(using: .png, properties: [:]) {
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "Pasted_Image_\(Int(Date().timeIntervalSince1970)).png"
            let fileURL = tempDir.appendingPathComponent(fileName)
            do {
                try pngData.write(to: fileURL)
                startSending(files: [fileURL])
                statusMessage = "Pasted image from clipboard"
                FeedbackManager.playSuccess()
                return
            } catch {
                // fall through to text
            }
        }
        
        // 3. Plain Text / Message
        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "Snippet_\(Int(Date().timeIntervalSince1970)).txt"
            let fileURL = tempDir.appendingPathComponent(fileName)
            do {
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
                startSending(files: [fileURL])
                statusMessage = "Pasted text message from clipboard"
                FeedbackManager.playSuccess()
                return
            } catch {
                statusMessage = "Failed to prepare text snippet"
                return
            }
        }
        
        statusMessage = "Clipboard is empty or unsupported"
    }
    
    public func stageTextMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Message_\(Int(Date().timeIntervalSince1970)).txt"
        let fileURL = tempDir.appendingPathComponent(fileName)
        do {
            try trimmed.write(to: fileURL, atomically: true, encoding: .utf8)
            startSending(files: [fileURL])
            statusMessage = "Message ready to send (\(trimmed.count) chars)"
            FeedbackManager.playSuccess()
        } catch {
            statusMessage = "Failed to stage message: \(error.localizedDescription)"
        }
    }
    
    public func removeSelectedFile(_ url: URL) {
        selectedFiles.removeAll(where: { $0 == url })
    }
    
    public func clearSelectedFiles() {
        selectedFiles.removeAll()
    }
    
    public func sendFiles(to peer: LocalShareDiscoveredPeer, pin: String? = nil) {
        guard !selectedFiles.isEmpty else { return }
        let filesToSend = self.selectedFiles
        let isTextMessageTransfer = filesToSend.allSatisfy { url in
            let name = url.lastPathComponent
            return name.hasPrefix("Message_") || name.hasPrefix("Snippet_") || name.hasPrefix("Dropped_Text_") || name.hasPrefix("WebLink_")
        }
        self.isSending = true
        self.activePeerAlias = peer.alias
        self.transferProgress = 0.0
        self.statusMessage = isTextMessageTransfer ? "Delivering message to \(peer.alias)..." : "Waiting for \(peer.alias) to accept..."
        markTransferActive()
        FeedbackManager.playSend()
        
        Task {
            do {
                // 1. Prepare upload in a single session
                let (clientSession, prepResp) = try await LocalShareClient.shared.prepareUpload(
                    to: peer,
                    fileURLs: filesToSend,
                    pin: pin
                )
                self.activeClientSession = clientSession
                
                // 2. Stream files with controlled parallelism and aggregate progress
                let totalBytes = filesToSend.reduce(Int64(0)) { acc, url in
                    acc + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                }
                
                if prepResp.files.isEmpty && isTextMessageTransfer {
                    // For pure text messages, LocalSend embeds preview in prepareUpload and accepts without file streaming
                    self.transferProgress = 1.0
                } else {
                    self.statusMessage = "Sending to \(peer.alias)..."
                    try await LocalShareClient.shared.uploadFiles(
                        session: clientSession,
                        prepResp: prepResp,
                        maxConcurrency: 2
                    ) { overallFraction in
                        Task { @MainActor in
                            self.transferProgress = overallFraction
                        }
                    }
                    self.transferProgress = 1.0
                }
                
                // Clean up temporary text/message/weblink files from temporary directory
                for f in filesToSend {
                    let name = f.lastPathComponent
                    if name.hasPrefix("Message_") || name.hasPrefix("Snippet_") || name.hasPrefix("Dropped_Text_") || name.hasPrefix("WebLink_") {
                        try? FileManager.default.removeItem(at: f)
                    }
                }
                
                // Success
                self.isSending = false
                self.activeClientSession = nil
                self.selectedFiles.removeAll()
                self.statusMessage = isTextMessageTransfer ? "Message delivered to \(peer.alias)" : "Sent \(filesToSend.count) file(s) to \(peer.alias)"
                self.markTransferFinished()
                FeedbackManager.playSuccess()
                
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
                self.markTransferFinished()
                
                self.addHistoryItem(
                    peerAlias: peer.alias,
                    fileNames: filesToSend.map { $0.lastPathComponent },
                    totalBytes: 0,
                    isOutgoing: true,
                    statusText: "Failed"
                )
            }
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
        transferProgress = 0.0
        statusMessage = "Transfer cancelled"
        markTransferFinished()
    }
    
    // MARK: - File Picker & Finder Revelation
    
    public func openFilePicker(thenSendTo peer: LocalShareDiscoveredPeer? = nil) {
        FeedbackManager.playClick()
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Files for Local Share"
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.prompt = "Select"
        
        markTransferActive()
        NSApp.activate(ignoringOtherApps: true)
        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            self.markTransferFinished()
            if response == .OK {
                self.startSending(files: openPanel.urls)
                if let targetPeer = peer {
                    self.sendFiles(to: targetPeer)
                }
            }
        }
    }
    
    public func openFolderPicker(thenSendTo peer: LocalShareDiscoveredPeer? = nil) {
        FeedbackManager.playClick()
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Folder for Local Share"
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.prompt = "Select Folder"
        
        markTransferActive()
        NSApp.activate(ignoringOtherApps: true)
        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            self.markTransferFinished()
            if response == .OK {
                self.startSending(files: openPanel.urls)
                if let targetPeer = peer {
                    self.sendFiles(to: targetPeer)
                }
            }
        }
    }
    
    public func openReceiveFolder() {
        let dir = LocalShareFileManager.shared.activeReceiveDirectory
        _ = try? LocalShareFileManager.shared.ensureBaseDirectoryExists()
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
    }
    
    // MARK: - Bounded Recent History
    
    private func addHistoryItem(peerAlias: String, fileNames: [String], totalBytes: Int64, isOutgoing: Bool, statusText: String) {
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
    
    private func loadRecentHistory() {
        if let data = UserDefaults.standard.data(forKey: historyStorageKey),
           let items = try? JSONDecoder().decode([LocalShareHistoryItem].self, from: data) {
            self.recentTransfers = items
        }
    }
    
    // MARK: - Collapsed Notch Notification Delegate
    
    private func postIncomingNotification(for session: LocalShareSession) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Local Share"
        content.subtitle = "Incoming Transfer from \(session.peerInfo.alias)"
        content.body = "\(session.filesMetadata.count) file(s)"
        content.categoryIdentifier = "localshare_incoming_transfer"
        content.sound = .default
        
        let acceptAction = UNNotificationAction(identifier: "ACCEPT_ACTION", title: "Accept", options: .foreground)
        let declineAction = UNNotificationAction(identifier: "DECLINE_ACTION", title: "Decline", options: .destructive)
        let category = UNNotificationCategory(
            identifier: "localshare_incoming_transfer",
            actions: [acceptAction, declineAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
        
        let request = UNNotificationRequest(
            identifier: "localshare_incoming_\(session.sessionId)",
            content: content,
            trigger: nil
        )
        center.add(request) { _ in }
    }
    
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        guard identifier.hasPrefix("localshare_incoming_") else {
            completionHandler()
            return
        }
        
        let actionId = response.actionIdentifier
        Task { @MainActor in
            if actionId == "ACCEPT_ACTION" {
                // User clicked "Accept"
                withAnimation {
                    NotchShellCoordinator.shared.state = .expanded
                    ModuleRegistry.shared.selectFileDropTarget(for: "localshare")
                }
                LocalShareModule.shared.acceptIncomingTransfer()
            } else if actionId == UNNotificationDefaultActionIdentifier {
                // User clicked notification body -> expand notch and present card
                withAnimation {
                    NotchShellCoordinator.shared.state = .expanded
                    ModuleRegistry.shared.selectFileDropTarget(for: "localshare")
                }
            } else {
                // Declined or dismissed
                LocalShareModule.shared.declineIncomingTransfer()
            }
        }
        completionHandler()
    }
    
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    // MARK: - View Builders
    
    public func makeCompactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: "shareplay")
                    .font(.system(size: 9))
                    .foregroundColor(themeColor)
                Text("Local Share")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(DesignSystem.primaryText)
            }
        )
    }
    
    public func makeExpandedView() -> AnyView {
        AnyView(
            LocalShareExpandedView(module: self)
        )
    }
}
