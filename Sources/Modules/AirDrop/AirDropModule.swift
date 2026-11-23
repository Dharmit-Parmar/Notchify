import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Thread-Safe URL Collector for Multi-Provider Drops
public final class URLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var urls: [URL] = []

    public init() {}

    public func append(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }

        // FIX (#6): resolve to a canonical, absolute URL so the same file
        // dropped twice via different paths (relative, file:// vs path-only)
        // doesn't appear as two entries.
        let canonical: URL
        if url.isFileURL {
            let cleanPath = url.path.trimmingCharacters(in: .whitespacesAndNewlines)
            canonical = URL(fileURLWithPath: cleanPath).standardizedFileURL
        } else {
            canonical = url.standardized
        }

        if !urls.contains(canonical) {
            urls.append(canonical)
        }
    }

    /// FIX (#1): fileURL must be checked **first**. The old order tried
    /// `canLoadObject(ofClass: URL.self)` first, which returns `true` for file
    /// drops (public.file-url conforms to public.url) but whose `loadObject`
    /// internally requests `public.url` — a type the provider doesn't expose.
    /// The load silently returned nil, and the correct `fileURL` branch was
    /// never reached. That is why drops did nothing.
    public static func extractURLs(
        from providers: [NSItemProvider],
        completion: @escaping @MainActor @Sendable ([URL]) -> Void
    ) {
        guard !providers.isEmpty else {
            Task { @MainActor in completion([]) }
            return
        }

        let collector = URLCollector()
        let group = DispatchGroup()

        for provider in providers {
            // --- 1. File URLs (Finder, Photos, any file drag) ---
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    let resolved: URL? = {
                        if let url = item as? URL { return url }
                        if let data = item as? Data {
                            if let url = URL(dataRepresentation: data, relativeTo: nil) { return url }
                            if let str = String(data: data, encoding: .utf8),
                               let url = URL(string: str.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                return url
                            }
                        }
                        if let str = item as? String {
                            return URL(string: str.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        return nil
                    }()
                    if let url = resolved, url.isFileURL {
                        collector.append(url)
                    }
                }
                continue
            }

            // --- 2. Non-file URLs (web links, mailto: etc.) ---
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let url = item as? URL {
                        collector.append(url)
                    } else if let data = item as? Data,
                              let str = String(data: data, encoding: .utf8),
                              let url = URL(string: str.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        collector.append(url)
                    } else if let str = item as? String,
                              let url = URL(string: str.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        collector.append(url)
                    }
                }
                continue
            }

            // --- 3. Image data (Photos library, Safari image drag) ---
            // File-based images already took branch #1 above; this covers
            // providers that only expose raw bitmap data.
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
                || provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
                group.enter()
                let typeID = provider.hasItemConformingToTypeIdentifier(UTType.png.identifier)
                    ? UTType.png.identifier
                    : UTType.image.identifier
                provider.loadDataRepresentation(forTypeIdentifier: typeID) { data, _ in
                    defer { group.leave() }
                    guard let data, !data.isEmpty else { return }
                    if let tempURL = AirDropModule.createSecureTempFile(prefix: "Photo", ext: "png", data: data) {
                        collector.append(tempURL)
                        Task { @MainActor in AirDropModule.shared.registerTransientStagedFile(tempURL) }
                    }
                }
                continue
            }

            // --- 4. Plain text (URLs become links, other text becomes .txt) ---
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                || provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier)
                || provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                group.enter()
                let typeID: String
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    typeID = UTType.plainText.identifier
                } else if provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
                    typeID = UTType.utf8PlainText.identifier
                } else {
                    typeID = UTType.text.identifier
                }
                provider.loadItem(forTypeIdentifier: typeID, options: nil) { item, _ in
                    defer { group.leave() }
                    var textStr: String?
                    if let str = item as? String { textStr = str }
                    else if let data = item as? Data { textStr = String(data: data, encoding: .utf8) }
                    else if let url = item as? URL {
                        collector.append(url)
                        return
                    }

                    guard let text = textStr?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }

                    if let url = URL(string: text),
                       let scheme = url.scheme?.lowercased(),
                       scheme == "http" || scheme == "https" {
                        collector.append(url)
                    } else if let textData = text.data(using: .utf8),
                              let tempURL = AirDropModule.createSecureTempFile(prefix: "Dropped_Text", ext: "txt", data: textData) {
                        collector.append(tempURL)
                        Task { @MainActor in AirDropModule.shared.registerTransientStagedFile(tempURL) }
                    }
                }
                continue
            }
        }

        group.notify(queue: .main) {
            Task { @MainActor in
                completion(collector.urls)
            }
        }
    }
}

// MARK: - AirDrop Dedicated Sharing Delegate
public final class AirDropSharingDelegate: NSObject, NSSharingServiceDelegate, @unchecked Sendable {
    public static let shared = AirDropSharingDelegate()

    public func sharingService(
        _ sharingService: NSSharingService,
        sourceWindowForShareItems items: [Any],
        sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>
    ) -> NSWindow? {
        sharingContentScope.pointee = .item
        let resolve = { NotchShellCoordinator.shared.panel }
        if Thread.isMainThread { return resolve() }
        return DispatchQueue.main.sync(execute: resolve)
    }

    public func sharingService(
        _ sharingService: NSSharingService,
        sourceFrameOnScreenForShareItem item: Any
    ) -> NSRect {
        let compute = { () -> NSRect in
            guard let panel = NotchShellCoordinator.shared.panel else { return .zero }
            let frame = panel.frame
            let width: CGFloat = 80
            let height: CGFloat = 16
            let x = frame.midX - (width / 2)
            let y = frame.minY + 4
            return NSRect(x: x, y: y, width: width, height: height)
        }
        if Thread.isMainThread { return compute() }
        return DispatchQueue.main.sync(execute: compute)
    }

    public func sharingService(_ sharingService: NSSharingService, willShareItems items: [Any]) {
        DispatchQueue.main.async {
            AirDropModule.shared.isBeaming = true
            AirDropModule.shared.statusMessage = "Beaming \(items.count) item(s) via AirDrop..."
        }
    }

    public func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        DispatchQueue.main.async {
            let module = AirDropModule.shared
            module.cleanupStagedFiles()
            module.markSharingSheetClosed()
            module.isBeaming = false
            module.statusMessage = "Shared \(items.count) item(s) successfully"
            FeedbackManager.playSuccess()
            // FIX (#2): notify the coordinator that the drop flow has fully
            // finished, *after* the sheet has closed.
            NotchShellCoordinator.shared.onFileDropFinished()
        }
    }

    public func sharingService(
        _ sharingService: NSSharingService,
        didFailToShareItems items: [Any],
        error: Error
    ) {
        DispatchQueue.main.async {
            let module = AirDropModule.shared
            module.cleanupStagedFiles()
            module.markSharingSheetClosed()
            module.isBeaming = false
            let desc = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            module.statusMessage = desc.isEmpty ? "Cancelled" : desc
            // FIX (#2): same as above — drop flow ended, notify the coordinator.
            NotchShellCoordinator.shared.onFileDropFinished()
        }
    }
}

// MARK: - AirDrop System Sharing Picker Delegate
public final class AirDropPickerDelegate: NSObject, NSSharingServicePickerDelegate, @unchecked Sendable {
    public static let shared = AirDropPickerDelegate()

    public func sharingServicePicker(
        _ sharingServicePicker: NSSharingServicePicker,
        didChoose service: NSSharingService?
    ) {
        if let service {
            service.delegate = AirDropSharingDelegate.shared
        } else {
            DispatchQueue.main.async {
                let module = AirDropModule.shared
                module.cleanupStagedFiles()
                module.markSharingSheetClosed()
                module.isBeaming = false
                module.statusMessage = "Cancelled"
                // FIX (#2): picker was dismissed → drop flow finished.
                NotchShellCoordinator.shared.onFileDropFinished()
            }
        }
    }
}

@MainActor
public final class AirDropModule: NotchModule {
    public static let shared = AirDropModule()

    public let id = "airdrop"
    public let title = "AirDrop"
    public let iconName = "airdrop"
    @Published public var isEnabled: Bool = true

    @Published public var recentFiles: [URL] = []
    @Published public var previewURL: URL? = nil
    @Published public var showingPreviewAll: Bool = false
    @Published public var isDropTargeted: Bool = false
    @Published public var statusMessage: String = "Ready to beam to nearby Apple devices"
    @Published public var isBeaming: Bool = false

    // SEC-08: Staged transient files tracking and secure cleanup
    private var transientStagedFiles: [URL] = []

    public func registerTransientStagedFile(_ url: URL) {
        transientStagedFiles.append(url)
    }

    public func cleanupStagedFiles() {
        let files = transientStagedFiles
        transientStagedFiles.removeAll()
        guard !files.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    nonisolated public static func createSecureTempFile(prefix: String, ext: String, data: Data) -> URL? {
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AirDropStaging", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: stagingDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let fileName = "\(prefix)_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).\(ext)"
        let fileURL = stagingDir.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            return fileURL
        } catch {
            return nil
        }
    }

    private let sharingDelegate = AirDropSharingDelegate.shared
    public private(set) var isSharingSheetActive = false

    public init() {
        purgeOldStagedFiles()
    }

    private func purgeOldStagedFiles() {
        DispatchQueue.global(qos: .utility).async {
            let stagingDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("AirDropStaging", isDirectory: true)
            try? FileManager.default.removeItem(at: stagingDir)
        }
    }

    public func start() {}
    public func stop() {
        isDropTargeted = false
        isBeaming = false
        cleanupStagedFiles()
        if isSharingSheetActive {
            markSharingSheetClosed()
        }
    }

    public func markSharingSheetOpened() {
        guard !isSharingSheetActive else { return }
        isSharingSheetActive = true
        ProcessMemoryGovernor.shared.notifySystemPanelOpened()
        NotchShellCoordinator.shared.registerPopoverOpened()
        NotchShellCoordinator.shared.panel?.level = .floating
    }

    public func markSharingSheetClosed() {
        guard isSharingSheetActive else { return }
        isSharingSheetActive = false
        ProcessMemoryGovernor.shared.notifySystemPanelClosed()
        NotchShellCoordinator.shared.panel?.level = .popUpMenu
        NotchShellCoordinator.shared.registerPopoverClosed()
        // FIX (#5): always clear `isBeaming` here so a failed presentation
        // can't leave the radar animation looping forever.
        if isBeaming { isBeaming = false }
    }

    public func shareFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        // FIX (#6): if the app is sandboxed, dropped URLs need a security
        // scope to be stat-able. We start access for the lifetime of the
        // share; the system cleans up scopes when the app terminates, and
        // NSSharingService inherits the grant.
        var securityScopedURLs: [URL] = []
        for url in urls where url.isFileURL {
            if url.startAccessingSecurityScopedResource() {
                securityScopedURLs.append(url)
            }
        }
        _ = securityScopedURLs // keep reference alive through this method

        let validUrls = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !validUrls.isEmpty else {
            statusMessage = "Selected file(s) no longer exist"
            isBeaming = false
            return
        }

        FeedbackManager.playSend()
        isBeaming = true
        statusMessage = "Opening AirDrop sheet for \(validUrls.count) item(s)..."

        for url in validUrls where !recentFiles.contains(url) {
            recentFiles.insert(url, at: 0)
        }
        if recentFiles.count > 6 {
            recentFiles = Array(recentFiles.prefix(6))
        }

        NSApp.activate(ignoringOtherApps: true)
        NotchShellCoordinator.shared.panel?.makeKey()

        if let airDrop = NSSharingService(named: .sendViaAirDrop),
           airDrop.canPerform(withItems: validUrls) {
            airDrop.delegate = sharingDelegate
            markSharingSheetOpened()
            airDrop.perform(withItems: validUrls)
            statusMessage = "Select recipient in AirDrop sheet"
            FeedbackManager.playSuccess()
            return
        }

        // Fall back to the system Sharing Service Picker.
        showSharingPickerFallback(for: validUrls)
    }

    public func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general

        // 1. File URLs in clipboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let fileURLs = urls.filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }
            if !fileURLs.isEmpty {
                // FIX (#4): don't overwrite `shareFiles`' status message.
                shareFiles(fileURLs)
                return
            }
        }

        // 2. Image data in clipboard
        if let image = NSImage(pasteboard: pasteboard),
           let tiffData = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiffData),
           let pngData = rep.representation(using: .png, properties: [:]) {
            if let tempURL = Self.createSecureTempFile(prefix: "Pasted_Image", ext: "png", data: pngData) {
                registerTransientStagedFile(tempURL)
                shareFiles([tempURL])
                return
            }
        }

        // 3. Plain Text in clipboard
        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let textData = text.data(using: .utf8) {
            if let tempURL = Self.createSecureTempFile(prefix: "Shared_Text", ext: "txt", data: textData) {
                registerTransientStagedFile(tempURL)
                shareFiles([tempURL])
                return
            } else {
                statusMessage = "Failed to paste clipboard text"
                return
            }
        }

        statusMessage = "Clipboard is empty or unsupported"
    }

    public func removeRecentFile(_ url: URL) {
        if previewURL == url { previewURL = nil }
        recentFiles.removeAll { $0 == url }
    }

    public func showSharingPickerFallback(for urls: [URL]) {
        guard !urls.isEmpty else { return }
        DispatchQueue.main.async {
            self.markSharingSheetOpened()
            let picker = NSSharingServicePicker(items: urls)
            picker.delegate = AirDropPickerDelegate.shared
            if let targetView = NotchShellCoordinator.shared.panel?.contentView {
                let anchor = NSRect(
                    x: targetView.bounds.midX - 40,
                    y: max(0, targetView.bounds.maxY - 24),
                    width: 80,
                    height: 20
                )
                picker.show(relativeTo: anchor, of: targetView, preferredEdge: .maxY)
                self.statusMessage = "Select AirDrop in sharing menu"
                self.isBeaming = false
            }
        }
    }

    public func openFilePicker() {
        FeedbackManager.playClick()
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Files to AirDrop"
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = true
        openPanel.prompt = "AirDrop"

        markSharingSheetOpened()
        NSApp.activate(ignoringOtherApps: true)
        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK {
                self.shareFiles(openPanel.urls)
            } else {
                self.markSharingSheetClosed()
            }
        }
    }

    public func makeCompactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: "airdrop")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.accentColor)
                Text("AirDrop")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white)
            }
        )
    }

    public func makeExpandedView() -> AnyView {
        AnyView(AirDropExpandedView(module: self))
    }
}

// MARK: - AirDrop Expanded View with Animated Radar & Full Drop Stage
public struct AirDropExpandedView: View {
    @ObservedObject var module: AirDropModule
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchCompact) private var notchCompact
    @Environment(\.notchTight) private var notchTight

    public var body: some View {
        let radarSize: CGFloat = notchTight ? 85 : (notchCompact ? 110 : 140)
        let iconSize: CGFloat = notchTight ? 18 : (notchCompact ? 22 : 26)

        HStack(spacing: notchTight ? 10 : 16) {
            // Left Column: Animated AirDrop Radar Beacon
            ZStack {
                AirDropRadarAnimation(isTargeted: module.isDropTargeted, isBeaming: module.isBeaming)
                    .frame(width: radarSize, height: radarSize)

                VStack(spacing: notchTight ? 2 : 4) {
                    Image(systemName: "airdrop")
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundColor(module.isDropTargeted ? .white : DesignSystem.accentColor)
                        .scaleEffect(module.isDropTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: module.isDropTargeted)

                    Text("AirDrop")
                        .font(.system(size: notchTight ? 9.5 : 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(width: radarSize, height: radarSize)

            // Right Column
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: notchTight ? 5 : 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        if !notchTight {
                            Text("Wireless File Transfer")
                                .font(.system(size: notchCompact ? 11.5 : 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        Text(module.statusMessage)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(module.isDropTargeted ? DesignSystem.accentColor : DesignSystem.secondaryText)
                            .lineLimit(notchTight ? 1 : 2)
                    }

                    // Drop Stage Box
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(module.isDropTargeted ? DesignSystem.accentColor.opacity(0.18) : Color.white.opacity(0.04))

                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                module.isDropTargeted ? DesignSystem.accentColor : Color.white.opacity(0.12),
                                style: StrokeStyle(lineWidth: module.isDropTargeted ? 1.5 : 1.0, dash: [5, 4])
                            )

                        VStack(spacing: notchTight ? 2 : 5) {
                            Image(systemName: module.isDropTargeted ? "arrow.down.circle.fill" : "arrow.up.and.down.circle")
                                .font(.system(size: notchTight ? 14 : 18))
                                .foregroundColor(DesignSystem.accentColor)
                                .scaleEffect(module.isDropTargeted ? 1.2 : 1.0)

                            Text(module.isDropTargeted ? "Release to Beam" : "Drag & Drop Files Here")
                                .font(.system(size: notchTight ? 8.5 : 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)

                            if !notchTight {
                                Text("Photos, PDFs, videos, or folders")
                                    .font(.system(size: 8.5))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                        }
                        .padding(notchTight ? 4 : 8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: notchTight ? 54 : 68)
                    .contentShape(Rectangle())
                    .onTapGesture { module.openFilePicker() }

                    // Action Buttons Row
                    HStack(spacing: 8) {
                        Button(action: module.openFilePicker) {
                            HStack(spacing: 5) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 9.5, weight: .semibold))
                                Text("Browse Files...")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(DesignSystem.accentColor))
                        }
                        .buttonStyle(.spring)

                        Button(action: { module.pasteFromClipboard() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 9))
                                Text("Paste")
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(DesignSystem.primaryText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(DesignSystem.surfaceFill))
                            .overlay(Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8))
                        }
                        .buttonStyle(.spring)
                        .keyboardShortcut("v", modifiers: .command)
                        .accessibilityLabel("Paste from clipboard and AirDrop")

                        Spacer()
                    }

                    // Recent Files Row
                    if !module.recentFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Recent Beam History (\(module.recentFiles.count))")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(DesignSystem.secondaryText)

                                Spacer()

                                HStack(spacing: 6) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            module.showingPreviewAll.toggle()
                                            if module.showingPreviewAll { module.previewURL = nil }
                                        }
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: module.showingPreviewAll ? "eye.slash.fill" : "photo.on.rectangle.angled")
                                                .font(.system(size: 8))
                                            Text(module.showingPreviewAll ? "Hide Previews" : "Preview All")
                                                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundColor(module.showingPreviewAll ? .black : DesignSystem.accentColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2.5)
                                        .background(Capsule().fill(module.showingPreviewAll ? DesignSystem.accentColor : DesignSystem.accentColor.opacity(0.15)))
                                    }
                                    .buttonStyle(.spring)
                                    .accessibilityLabel("Toggle Preview All")

                                    Button("Clear") {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            module.showingPreviewAll = false
                                            module.previewURL = nil
                                            module.recentFiles.removeAll()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 8.5, weight: .medium))
                                    .foregroundColor(DesignSystem.tertiaryText)
                                }
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    ForEach(module.recentFiles, id: \.self) { file in
                                        HStack(spacing: 4) {
                                            Button(action: { module.shareFiles([file]) }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "arrow.counterclockwise")
                                                        .font(.system(size: 7))
                                                    Text(file.lastPathComponent)
                                                        .font(.system(size: 8.5, weight: .medium))
                                                        .lineLimit(1)
                                                }
                                                .foregroundColor(Color.white.opacity(0.85))
                                            }
                                            .buttonStyle(.plain)

                                            Button(action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                    module.previewURL = (module.previewURL == file ? nil : file)
                                                }
                                            }) {
                                                Image(systemName: module.previewURL == file ? "eye.fill" : "eye")
                                                    .font(.system(size: 7.5))
                                                    .foregroundColor(module.previewURL == file ? DesignSystem.accentColor : DesignSystem.secondaryText)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("Preview \(file.lastPathComponent)")

                                            Button(action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                    module.removeRecentFile(file)
                                                }
                                            }) {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 7, weight: .bold))
                                                    .foregroundColor(DesignSystem.secondaryText)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("Remove \(file.lastPathComponent)")
                                        }
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3.5)
                                        .background(Capsule().fill(module.previewURL == file ? DesignSystem.accentColor.opacity(0.18) : DesignSystem.structureColor))
                                        .overlay(Capsule().strokeBorder(module.previewURL == file ? DesignSystem.accentColor : Color.white.opacity(0.08), lineWidth: 0.7))
                                        .onDrag { NSItemProvider(object: file as NSURL) }
                                        .help("Click to AirDrop or preview \(file.lastPathComponent)")
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .frame(height: 28)
                        }
                    }

                    // Preview Carousel / Single Preview Stage
                    if module.showingPreviewAll && !module.recentFiles.isEmpty {
                        FilePreviewAllCarouselCard(
                            urls: module.recentFiles,
                            themeColor: DesignSystem.accentColor,
                            actionLabel: "AirDrop All",
                            onRemoveFile: { file in
                                module.removeRecentFile(file)
                                if module.recentFiles.isEmpty { module.showingPreviewAll = false }
                            },
                            onDismiss: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    module.showingPreviewAll = false
                                }
                            },
                            onAction: { module.shareFiles(module.recentFiles) }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                        ))
                    } else if let previewURL = module.previewURL, module.recentFiles.contains(previewURL) {
                        FilePreviewStageCard(
                            url: previewURL,
                            themeColor: DesignSystem.accentColor,
                            actionLabel: "AirDrop",
                            onDismiss: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    module.previewURL = nil
                                }
                            },
                            onAction: { module.shareFiles([previewURL]) }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                        ))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(4)
        .contentShape(Rectangle())
        // FIX (#3): narrow the UTI list to the actual transferable types.
        // `.item`, `.data`, and `.content` were overly broad catch-alls that
        // accepted any drop even when nothing was loadable, masking failures.
        .onDrop(
            of: [
                .fileURL, .url,
                .image, .png, .tiff,
                .text, .plainText, .utf8PlainText
            ],
            isTargeted: $module.isDropTargeted
        ) { providers in
            // FIX (#1): accept only if at least one provider has a type we can
            // actually resolve. Prevents "success" returns for unsupported
            // items.
            let isProcessable = providers.contains { p in
                p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                    || p.hasItemConformingToTypeIdentifier(UTType.url.identifier)
                    || p.hasItemConformingToTypeIdentifier(UTType.image.identifier)
                    || p.hasItemConformingToTypeIdentifier(UTType.png.identifier)
                    || p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                    || p.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier)
                    || p.hasItemConformingToTypeIdentifier(UTType.text.identifier)
            }
            guard isProcessable else { return false }

            URLCollector.extractURLs(from: providers) { urls in
                guard !urls.isEmpty else {
                    AirDropModule.shared.statusMessage = "Couldn't read dropped item"
                    return
                }
                AirDropModule.shared.shareFiles(urls)
                // FIX (#2): onFileDropFinished is no longer called here. The
                // share sheet owns the remainder of the flow and the delegate
                // fires onFileDropFinished when the sheet actually closes.
            }
            return true
        }
    }
}

// MARK: - Animated Concentric Radar Rings
private struct AirDropRadarAnimation: View {
    let isTargeted: Bool
    let isBeaming: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: (isTargeted || isBeaming) ? (1.0 / 30.0) : 0.25,
                paused: reduceMotion || (!isTargeted && !isBeaming)
            )
        ) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = min(size.width, size.height) / 2
                let ringCount = 3

                let time = timeline.date.timeIntervalSinceReferenceDate
                let speed = isTargeted ? 2.5 : (isBeaming ? 3.5 : 1.0)
                let normalizedTime = (time * speed).truncatingRemainder(dividingBy: 1.0)

                for i in 0..<ringCount {
                    let progress = (normalizedTime + Double(i) / Double(ringCount))
                        .truncatingRemainder(dividingBy: 1.0)
                    let currentRadius = CGFloat(progress) * maxRadius
                    let opacity = (1.0 - progress) * (isTargeted ? 0.85 : 0.35)

                    var path = Path()
                    path.addArc(center: center, radius: currentRadius, startAngle: .zero, endAngle: .degrees(360), clockwise: false)

                    context.stroke(
                        path,
                        with: .color(DesignSystem.accentColor.opacity(opacity)),
                        lineWidth: isTargeted ? 2.2 : 1.0
                    )
                }

                var boundaryPath = Path()
                boundaryPath.addArc(center: center, radius: maxRadius - 2, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
                context.stroke(
                    boundaryPath,
                    with: .color(isTargeted ? DesignSystem.accentColor.opacity(0.4) : Color.white.opacity(0.08)),
                    lineWidth: isTargeted ? 1.5 : 0.8
                )
            }
        }
    }
}