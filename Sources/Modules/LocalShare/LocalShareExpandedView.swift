import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LocalShare

// MARK: - LocalShare Expanded UI State
@MainActor
public final class LocalShareExpandedUIState: ObservableObject {
    @Published public var showingManualIPSheet = false
    @Published public var manualIPAddress = ""
    @Published public var manualPortText = "53317"
    @Published public var manualIPError: String? = nil
    @Published public var isConnectingManualIP = false
    @Published public var showingMessageComposer = false
    @Published public var messageText = ""
    
    public init() {}
}

// MARK: - LocalShare Expanded View
public struct LocalShareExpandedView: View {
    @ObservedObject var module: LocalShareModule
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchCompact) private var notchCompact
    @Environment(\.notchTight) private var notchTight
    @Environment(\.notchContentHeight) private var contentHeight
    @StateObject private var uiState = LocalShareExpandedUIState()
    
    public init(module: LocalShareModule) {
        self.module = module
    }
    
    public var body: some View {
        let radarSize: CGFloat = notchTight ? 85 : (notchCompact ? 110 : 135)
        let iconSize: CGFloat = notchTight ? 18 : (notchCompact ? 22 : 26)
        
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: notchTight ? 10 : 16) {
                // Left Column: Animated Local Share Radar Beacon
                VStack(spacing: 8) {
                    ZStack {
                        LocalShareRadarAnimation(
                            isTargeted: module.isDropTargeted,
                            isActive: module.isSending || module.isReceiving || module.isReceiveActive
                        )
                        .frame(width: radarSize, height: radarSize)
                        
                        VStack(spacing: notchTight ? 2 : 4) {
                            Image(systemName: "shareplay")
                                .font(.system(size: iconSize, weight: .bold))
                                .foregroundColor(module.isDropTargeted ? DesignSystem.primaryText : module.themeColor)
                                .scaleEffect(module.isDropTargeted ? 1.15 : 1.0)
                                .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: module.isDropTargeted)
                            
                            Text("Local Share")
                                .font(.system(size: notchTight ? 9.5 : 11, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.primaryText)
                        }
                    }
                    .frame(width: radarSize, height: radarSize)
                    
                    // Receive Mode Toggle Capsule
                    Button(action: {
                        LocalShareSettingsStore.shared.isReceiveEnabled.toggle()
                    }) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(module.isReceiveActive ? Color.green : DesignSystem.secondaryText.opacity(0.5))
                                .frame(width: 6, height: 6)
                            Text(module.isReceiveActive ? "Receive ON" : "Receive OFF")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundColor(DesignSystem.primaryText)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(module.isReceiveActive ? Color.green.opacity(0.16) : DesignSystem.surfaceFill)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(module.isReceiveActive ? Color.green.opacity(0.4) : DesignSystem.cardBorder, lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.spring)
                    .accessibilityLabel("Toggle Local Share Receiver")
                    .accessibilityHint(module.isReceiveActive ? "Receiver is on. Click to turn off." : "Receiver is off. Click to turn on.")
                    
                    // Open Downloads Button
                    Button(action: {
                        module.openReceiveFolder()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.system(size: 9))
                            Text("Downloads")
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(DesignSystem.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Local Share Downloads Folder")
                }
                .frame(width: radarSize)
                
                // Right Column: Drop Stage, Incoming Requests, Transfer Progress & Peers
                VStack(alignment: .leading, spacing: notchTight ? 6 : 8) {
                    // Header & Status Line
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Local Network Transfer")
                                .font(.system(size: notchCompact ? 11.5 : 12.5, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.primaryText)
                            Spacer()
                            
                            Button(action: {
                                module.rescan()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 8.5))
                                        .rotationEffect(.degrees(module.isScanning ? 360 : 0))
                                        .animation(reduceMotion || !module.isScanning ? nil : .linear(duration: 0.8).repeatForever(autoreverses: false), value: module.isScanning)
                                    Text(module.isScanning ? "Scanning" : "Refresh")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundColor(DesignSystem.secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(DesignSystem.surfaceFill))
                            }
                            .buttonStyle(.plain)
                            .disabled(module.isScanning)
                            .accessibilityLabel("Refresh and Rescan Nearby Devices")
                            
                            Button(action: {
                                uiState.showingManualIPSheet.toggle()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "network")
                                        .font(.system(size: 8.5))
                                    Text("Direct IP")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundColor(DesignSystem.secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(DesignSystem.surfaceFill))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Connect to Direct IP")
                        }
                        
                        Text(module.statusMessage)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(module.isDropTargeted ? module.themeColor : DesignSystem.secondaryText)
                            .lineLimit(1)
                    }
                    
                    // Incoming Transfer Card (if peer offered session)
                    if let incoming = module.incomingSession {
                        incomingRequestCard(incoming: incoming)
                    }
                    
                    // In-Flight Transfer Progress Card
                    if module.isSending || module.isReceiving {
                        activeTransferProgressCard
                    }
                    
                    // Drop Stage Area
                    dropStageBox
                    
                    // Organized 4-Option Send Bar: [Files] [Folder] [Message] [Clipboard]
                    sendOptionsBar
                    
                    // Inline Expandable Message Composer
                    if uiState.showingMessageComposer {
                        messageComposerCard
                    }
                    
                    // Selected Files List (if pending send)
                    if !module.selectedFiles.isEmpty && !module.isSending {
                        selectedFilesSummary
                    }
                    
                    // Nearby Discovered Peers List
                    nearbyPeersSection
                    
                    // Manual Direct IP Input Sheet (Inline)
                    if uiState.showingManualIPSheet {
                        manualIPInputCard
                    }
                    
                    // Bounded Transfer History Glances
                    if !module.recentTransfers.isEmpty {
                        recentTransfersSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(4)
        }
        .contentShape(Rectangle())
        // Global Drop Handler for Local Share View
        .onDrop(of: [.fileURL, .item, .data, .content], isTargeted: $module.isDropTargeted) { providers in
            URLCollector.extractURLs(from: providers) { urls in
                guard !urls.isEmpty else { return }
                module.startSending(files: urls)
                NotchShellCoordinator.shared.onFileDropFinished()
            }
            return !providers.isEmpty
        }
        .onAppear {
            module.start()
            module.rescan()
        }
    }
    
    // MARK: - Subviews
    
    private var dropStageBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(module.isDropTargeted ? module.themeColor.opacity(0.18) : DesignSystem.surfaceFill)
            
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    module.isDropTargeted ? module.themeColor : DesignSystem.subtleBorder,
                    style: StrokeStyle(lineWidth: module.isDropTargeted ? 1.5 : 1.0, dash: [5, 4])
                )
            
            VStack(spacing: notchTight ? 2 : 4) {
                Image(systemName: module.isDropTargeted ? "arrow.down.circle.fill" : "arrow.up.and.down.circle")
                    .font(.system(size: notchTight ? 14 : 17))
                    .foregroundColor(module.themeColor)
                    .scaleEffect(module.isDropTargeted ? 1.2 : 1.0)
                    .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: module.isDropTargeted)
                
                Text(module.isDropTargeted ? "Release to Send" : "Drag & Drop Files for Local Share")
                    .font(.system(size: notchTight ? 8.5 : 10, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.primaryText)
                
                if !notchTight {
                    Text("Compatible with LocalSend devices (Android, iOS, Windows, Linux)")
                        .font(.system(size: 8.5))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
            .padding(notchTight ? 4 : 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: notchTight ? 52 : (notchCompact ? 60 : 68))
        .contentShape(Rectangle())
        .onTapGesture {
            module.openFilePicker()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Local Share File Drop Zone")
        .accessibilityHint("Drag files here or click to browse files.")
    }
    
    // MARK: - Organized 4-Option Send Bar ([Files], [Folder], [Message], [Clipboard])
    
    private var sendOptionsBar: some View {
        HStack(spacing: 5) {
            actionOptionPill(
                title: "Files",
                icon: "doc.badge.plus",
                isActive: false
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    uiState.showingMessageComposer = false
                }
                module.openFilePicker()
            }
            .accessibilityLabel("Select files to send")
            
            actionOptionPill(
                title: "Folder",
                icon: "folder.badge.plus",
                isActive: false
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    uiState.showingMessageComposer = false
                }
                module.openFolderPicker()
            }
            .accessibilityLabel("Select folder to send")
            
            actionOptionPill(
                title: "Message",
                icon: "message",
                isActive: uiState.showingMessageComposer
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    uiState.showingMessageComposer.toggle()
                }
            }
            .accessibilityLabel("Compose text message to send")
            
            actionOptionPill(
                title: "Clipboard",
                icon: "doc.on.clipboard",
                isActive: false
            ) {
                module.pasteFromClipboard()
            }
            .keyboardShortcut("v", modifiers: .command)
            .accessibilityLabel("Paste from clipboard to send")
        }
    }
    
    private func actionOptionPill(
        title: String,
        icon: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isActive ? .black : DesignSystem.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? module.themeColor : DesignSystem.surfaceFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isActive ? module.themeColor : DesignSystem.cardBorder, lineWidth: 0.75)
            )
        }
        .buttonStyle(.spring)
    }
    
    // MARK: - Inline Message Composer
    
    private var messageComposerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(module.themeColor)
                Text("Compose Text Message")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.primaryText)
                
                Spacer()
                
                if !uiState.messageText.isEmpty {
                    Text("\(uiState.messageText.count) chars")
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        uiState.showingMessageComposer = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Message Composer")
            }
            
            ZStack(alignment: .topLeading) {
                if uiState.messageText.isEmpty {
                    Text("Type or paste a message to share with nearby devices...")
                        .font(.system(size: 9.5))
                        .foregroundColor(DesignSystem.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                }
                
                TextEditor(text: $uiState.messageText)
                    .font(.system(size: 9.5, design: .default))
                    .foregroundColor(DesignSystem.primaryText)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(height: 52)
                    .padding(4)
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(DesignSystem.surfaceFill))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8))
            
            HStack {
                Button("Clear") {
                    uiState.messageText = ""
                }
                .buttonStyle(.plain)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundColor(DesignSystem.secondaryText)
                .disabled(uiState.messageText.isEmpty)
                
                Spacer()
                
                Button(action: {
                    let text = uiState.messageText
                    module.stageTextMessage(text)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        uiState.messageText = ""
                        uiState.showingMessageComposer = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 8))
                        Text("Stage Message")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(module.themeColor))
                }
                .buttonStyle(.spring)
                .disabled(uiState.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Stage text message to send to peers")
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(DesignSystem.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(module.themeColor.opacity(0.35), lineWidth: 0.8))
    }
    
    private func incomingRequestCard(incoming: LocalShareSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.down.left.circle.fill")
                    .foregroundColor(module.themeColor)
                Text("Incoming Transfer from \(incoming.peerInfo.alias)")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.primaryText)
                Spacer()
                Text("\(incoming.filesMetadata.count) file(s)")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            
            let totalBytes = incoming.filesMetadata.values.reduce(Int64(0)) { $0 + $1.size }
            Text("Total Size: \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))")
                .font(.system(size: 9))
                .foregroundColor(DesignSystem.tertiaryText)
            
            HStack(spacing: 8) {
                Button(action: {
                    module.acceptIncomingTransfer()
                }) {
                    Text("Accept")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(module.themeColor))
                }
                .buttonStyle(.spring)
                .accessibilityLabel("Accept Incoming Transfer")
                
                Button(action: {
                    module.declineIncomingTransfer()
                }) {
                    Text("Decline")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(DesignSystem.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(DesignSystem.surfaceFill))
                        .overlay(Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8))
                }
                .buttonStyle(.spring)
                .accessibilityLabel("Decline Incoming Transfer")
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(module.themeColor.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(module.themeColor.opacity(0.35), lineWidth: 1))
    }
    
    private var activeTransferProgressCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(module.isSending ? "Sending to \(module.activePeerAlias ?? "peer")..." : "Receiving from \(module.activePeerAlias ?? "peer")...")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.primaryText)
                Spacer()
                Text("\(Int(module.transferProgress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(module.themeColor)
            }
            
            // Progress Bar
            GeometryReader { pGeo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignSystem.surfaceFill)
                    Capsule()
                        .fill(module.themeColor)
                        .frame(width: max(4, pGeo.size.width * CGFloat(min(1.0, max(0.0, module.transferProgress)))))
                }
            }
            .frame(height: 5)
            
            HStack {
                Spacer()
                Button("Cancel") {
                    module.cancelActiveTransfer()
                }
                .buttonStyle(.spring)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color.red)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8))
    }
    
    private var selectedFilesSummary: some View {
        HStack {
            Text("\(module.selectedFiles.count) file(s) selected")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(DesignSystem.primaryText)
            
            Spacer()
            
            Button("Clear") {
                module.clearSelectedFiles()
            }
            .buttonStyle(.plain)
            .font(.system(size: 9))
            .foregroundColor(DesignSystem.secondaryText)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(DesignSystem.surfaceFill))
    }
    
    private var nearbyPeersSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Nearby Devices (\(module.discoveredPeers.count))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.primaryText)
                
                Button(action: {
                    module.rescan()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(DesignSystem.secondaryText)
                        .rotationEffect(.degrees(module.isScanning ? 360 : 0))
                        .animation(reduceMotion || !module.isScanning ? nil : .linear(duration: 0.8).repeatForever(autoreverses: false), value: module.isScanning)
                }
                .buttonStyle(.plain)
                .disabled(module.isScanning)
                .accessibilityLabel("Rescan Nearby Devices")
                
                Spacer()
                if module.discoveredPeers.isEmpty {
                    Text(module.isScanning ? "Scanning LAN..." : "Searching LAN...")
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
            
            if module.discoveredPeers.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.secondaryText.opacity(0.5))
                    Text("No devices found. Open LocalSend or Local Share on other devices.")
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.secondaryText)
                    
                    Spacer()
                    
                    Button("Refresh") {
                        module.rescan()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(module.themeColor)
                    .disabled(module.isScanning)
                }
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 4) {
                    ForEach(module.discoveredPeers) { peer in
                        peerRow(peer)
                    }
                }
            }
        }
    }
    
    private func peerRow(_ peer: LocalShareDiscoveredPeer) -> some View {
        Button(action: {
            if module.selectedFiles.isEmpty {
                module.openFilePicker(thenSendTo: peer)
            } else {
                module.sendFiles(to: peer)
            }
        }) {
            HStack(spacing: 8) {
                // Device Icon
                Image(systemName: iconForDeviceType(peer.deviceType))
                    .font(.system(size: 12))
                    .foregroundColor(module.themeColor)
                    .frame(width: 20)
                
                // Alias & Details
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(peer.alias)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.primaryText)
                            .lineLimit(1)
                        if LocalShareSettingsStore.shared.isFavorite(fingerprint: peer.fingerprint) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text("\(peer.host) • \(peer.deviceModel ?? peer.deviceType.rawValue)")
                        .font(.system(size: 8.5))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                Spacer()
                
                // Send action label
                Text(module.selectedFiles.isEmpty ? "Select..." : "Send")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(module.themeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(module.themeColor.opacity(0.15)))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(DesignSystem.cardFill))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DesignSystem.cardBorder, lineWidth: 0.7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.spring)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Send to \(peer.alias)")
        .accessibilityHint("Tap to send selected files to this device.")
    }
    
    private var manualIPInputCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Direct IP Connect")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(DesignSystem.primaryText)
            
            HStack {
                TextField("IP Address (e.g. 192.168.1.50)", text: $uiState.manualIPAddress)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 9.5, design: .monospaced))
                
                Button(action: connectManualIP) {
                    if uiState.isConnectingManualIP {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Connect")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                }
                .buttonStyle(.spring)
                .disabled(uiState.manualIPAddress.isEmpty || uiState.isConnectingManualIP)
            }
            
            if let err = uiState.manualIPError {
                Text(err)
                    .font(.system(size: 8.5))
                    .foregroundColor(.red)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(DesignSystem.surfaceFill))
    }
    
    private func connectManualIP() {
        let host = uiState.manualIPAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }
        let port = UInt16(uiState.manualPortText) ?? LocalShareConstants.defaultHttpPort
        uiState.isConnectingManualIP = true
        uiState.manualIPError = nil
        
        Task {
            do {
                _ = try await LocalShareDiscovery.shared.registerManualIP(host: host, port: port)
                uiState.isConnectingManualIP = false
                uiState.showingManualIPSheet = false
                uiState.manualIPAddress = ""
            } catch {
                uiState.isConnectingManualIP = false
                uiState.manualIPError = error.localizedDescription
            }
        }
    }
    
    private var recentTransfersSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Recent Transfers")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(module.recentTransfers) { item in
                        HStack(spacing: 4) {
                            Image(systemName: item.isOutgoing ? "arrow.up.right" : "arrow.down.left")
                                .font(.system(size: 7))
                                .foregroundColor(item.statusText == "Completed" ? .green : .red)
                            Text("\(item.peerAlias) (\(item.fileNames.count))")
                                .font(.system(size: 8.5, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(DesignSystem.primaryText.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(DesignSystem.surfaceFill))
                        .overlay(Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.6))
                    }
                }
            }
            .frame(height: 22)
        }
    }
    
    private func iconForDeviceType(_ type: LocalShareDeviceType) -> String {
        switch type {
        case .mobile: return "iphone"
        case .desktop: return "laptopcomputer"
        case .web: return "globe"
        case .headless: return "display"
        case .server: return "server.rack"
        }
    }
}

// MARK: - Animated Local Share Radar Rings
private struct LocalShareRadarAnimation: View {
    let isTargeted: Bool
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        TimelineView(.animation(minimumInterval: (isTargeted || isActive) ? (1.0 / 30.0) : 0.5, paused: reduceMotion || (!isTargeted && !isActive))) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
                let maxRadius = min(size.width, size.height) / 2.0 - 4.0
                
                // If reduce motion is enabled, render elegant static concentric rings
                if reduceMotion {
                    for rFraction in [0.35, 0.65, 0.95] {
                        let path = Path(ellipseIn: CGRect(
                            x: center.x - maxRadius * rFraction,
                            y: center.y - maxRadius * rFraction,
                            width: maxRadius * rFraction * 2,
                            height: maxRadius * rFraction * 2
                        ))
                        context.stroke(path, with: .color(Color(red: 0.20, green: 0.78, blue: 0.85).opacity(0.2)), lineWidth: 1.0)
                    }
                    return
                }
                
                let time = timeline.date.timeIntervalSinceReferenceDate
                let cycle = 2.4
                let ringCount = 3
                
                for i in 0..<ringCount {
                    let offset = Double(i) * (cycle / Double(ringCount))
                    let progress = (time + offset).truncatingRemainder(dividingBy: cycle) / cycle
                    let radius = maxRadius * CGFloat(progress)
                    let opacity = (1.0 - progress) * (isTargeted ? 0.7 : (isActive ? 0.45 : 0.15))
                    
                    let ringRect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    let path = Path(ellipseIn: ringRect)
                    let strokeColor = Color(red: 0.20, green: 0.78, blue: 0.85).opacity(opacity)
                    context.stroke(path, with: .color(strokeColor), lineWidth: isTargeted ? 1.8 : 1.2)
                }
            }
        }
    }
}
