import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import AppKit
@preconcurrency import PDFKit
import CoreImage

// A private drag type prevents an unrelated Finder drag from being mistaken
// for an internal reorder operation.
private enum ShelfDragPayload {
    static let itemID = UTType(exportedAs: "com.notchify.file-studio.shelf-item-id")

    static func provider(for id: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: itemID.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(id.uuidString.data(using: .utf8), nil)
            return nil
        }
        return provider
    }
}

private final class ShelfDropAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    private var failureCount = 0

    func append(_ url: URL) {
        lock.lock()
        urls.append(url)
        lock.unlock()
    }

    func recordFailure() {
        lock.lock()
        failureCount += 1
        lock.unlock()
    }

    func snapshot() -> (urls: [URL], failures: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (urls, failureCount)
    }
}

// MARK: - File Studio Tools

public enum FileStudioTool: String, CaseIterable, Identifiable, Sendable {
    case merge
    case compress
    case convert
    case enhance
    case airdrop

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .merge: "Merge PDFs"
        case .compress: "Compress PDF"
        case .convert: "Convert to PDF"
        case .enhance: "Enhance Scans"
        case .airdrop: "AirDrop Express"
        }
    }

    public var subtitle: String {
        switch self {
        case .merge: "Combine PDFs, images and supported documents"
        case .compress: "Reduce PDF size with lossy image compression"
        case .convert: "Convert images and supported documents into PDF"
        case .enhance: "Improve scan contrast and text clarity"
        case .airdrop: "Send staged files to a nearby Apple device"
        }
    }

    public var icon: String {
        switch self {
        case .merge: "doc.on.doc.fill"
        case .compress: "arrow.down.right.and.arrow.up.left"
        case .convert: "arrow.triangle.2.circlepath.doc.on.clipboard"
        case .enhance: "wand.and.stars"
        // The AirDrop symbol is resolved by AirDropMark with a fallback.
        case .airdrop: "dot.radiowaves.left.and.right"
        }
    }

    public var actionTitle: String {
        switch self {
        case .merge: "Merge into PDF"
        case .compress: "Compress PDF"
        case .convert: "Convert to PDF"
        case .enhance: "Enhance Scans"
        case .airdrop: "AirDrop Files"
        }
    }
}

// MARK: - Models

public struct ShelfItem: Identifiable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let size: String
    public let byteCount: Int64

    public init(url: URL, id: UUID = UUID()) {
        self.id = id
        self.url = url
        self.name = url.lastPathComponent

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let count = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        self.byteCount = count
        self.size = count > 0 ? ShelfModule.formattedByteCount(count) : "File"
    }

    public var ext: String { url.pathExtension.lowercased() }
    public var isPDF: Bool { ext == "pdf" }

    public var isImage: Bool {
        ["png", "jpg", "jpeg", "heic", "webp", "tiff", "tif", "bmp", "gif"].contains(ext)
    }

    public var isTextOrDoc: Bool {
        ["txt", "rtf", "md", "markdown", "csv", "json", "doc", "docx"].contains(ext)
    }

    public var isSupported: Bool { isPDF || isImage || isTextOrDoc }
}

public struct ResultantPDF: Identifiable, Sendable {
    public let id: UUID
    public var fileURL: URL
    public var fileName: String
    public var pageCount: Int
    public var byteCount: Int64
    public var formattedSize: String
    public var summary: String
    public var tool: FileStudioTool
    public var thumbnailData: Data?

    public init(
        fileURL: URL,
        fileName: String,
        pageCount: Int,
        byteCount: Int64,
        summary: String,
        tool: FileStudioTool,
        thumbnailData: Data?,
        id: UUID = UUID()
    ) {
        self.id = id
        self.fileURL = fileURL
        self.fileName = fileName
        self.pageCount = pageCount
        self.byteCount = byteCount
        self.formattedSize = ShelfModule.formattedByteCount(byteCount)
        self.summary = summary
        self.tool = tool
        self.thumbnailData = thumbnailData
    }
}

public enum LeftStageMode {
    case wheel
    case preview
}

// MARK: - File Studio Module

@MainActor
public final class ShelfModule: NotchModule {
    public static let shared = ShelfModule()

    public let id = "shelf"
    public let title = "File Studio"
    public let iconName = "doc.badge.gearshape.fill"

    @Published public var isEnabled = true
    @Published public var items: [ShelfItem] = []
    @Published public var statusMessage: String?
    @Published public var selectedTool: FileStudioTool = .merge
    @Published public var isProcessing = false
    @Published public var processingStage = ""
    @Published public var processingProgress = 0.0
    @Published public var wheelRotationAngle = 0.0

    @Published public var resultantDocument: ResultantPDF?
    @Published public var resultantFileName = "Merged_Document.pdf"
    @Published public var leftStageMode: LeftStageMode = .wheel

    @Published public var isAirDropHovered = false
    @Published public var isTrayHovered = false
    @Published public private(set) var draggingItemID: UUID?

    public private(set) var currentProcessingTask: Task<Void, Never>?

    public let thumbnailCache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.totalCostLimit = 10 * 1024 * 1024
        cache.countLimit = 30
        return cache
    }()

    private let tempCacheDirectory: URL
    private var workerTask: Task<ResultantPDF?, Never>?
    private var progressTask: Task<Void, Never>?
    private var activeOperationID: UUID?
    private var securityScopedURLs: [UUID: URL] = [:]
    private var deferredSecurityScopeURLs: [URL] = []
    private var deferredTempURLsToDelete: [URL] = []
    private var activeWorkerCount = 0

    // Retained for source compatibility. Internal formatting uses a fresh formatter
    // so detached workers never share this mutable formatter concurrently.
    nonisolated(unsafe) public static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useAll
        formatter.countStyle = .file
        return formatter
    }()

    nonisolated public static func formattedByteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useAll
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    public init() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchifyStudio", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )

        self.tempCacheDirectory = directory
        cleanStaleTempFiles()
    }

    public func start() {
        cleanStaleTempFiles()
    }

    public func stop() {
        cancelProcessing()
        thumbnailCache.removeAllObjects()
        // Keep security-scoped access while staged items remain in the singleton.
        // The scopes are released when individual items are removed or the tray is cleared.
        // Do not delete the cache here: a collapsed view can still own a result.
    }

    public func evictCaches() {
        thumbnailCache.removeAllObjects()
    }

    public func cleanStaleTempFiles(all: Bool = false) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempCacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey]
        ) else { return }

        let now = Date()
        for file in files {
            let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
            let modified = values?.contentModificationDate ?? .distantPast
            let isDirectory = values?.isDirectory ?? false
            let shouldRemove = all || now.timeIntervalSince(modified) > 60 * 60 * 24

            guard shouldRemove else { continue }
            // Protect both direct files and parent folders containing active files.
            var protectedPaths = Set(items.map { $0.url.standardizedFileURL.path })
            if let result = resultantDocument {
                protectedPaths.insert(result.fileURL.standardizedFileURL.path)
            }
            let filePath = file.standardizedFileURL.path
            let containsProtectedFile = protectedPaths.contains { path in
                path == filePath || path.hasPrefix(filePath + "/")
            }
            if containsProtectedFile {
                continue
            }
            if isDirectory {
                try? FileManager.default.removeItem(at: file)
            } else {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: File Import

    public func addItem(_ url: URL) {
        let normalizedURL = url.standardizedFileURL
        let startedSecurityScope = normalizedURL.startAccessingSecurityScopedResource()

        guard FileManager.default.fileExists(atPath: normalizedURL.path) else {
            if startedSecurityScope { normalizedURL.stopAccessingSecurityScopedResource() }
            statusMessage = "The selected file is no longer available."
            return
        }

        guard !items.contains(where: {
            $0.url.standardizedFileURL.path == normalizedURL.path
        }) else {
            if startedSecurityScope { normalizedURL.stopAccessingSecurityScopedResource() }
            statusMessage = "That file is already in the tray."
            return
        }

        // Read metadata only after starting any security-scoped access granted by Finder.
        let item = ShelfItem(url: normalizedURL)
        items.insert(item, at: 0)

        if startedSecurityScope {
            securityScopedURLs[item.id] = normalizedURL
        }

        FeedbackManager.playDrop()
        preselectTool(for: item)

        NotificationModule.shared.addNotification(
            NotificationItem(
                appName: "File Studio",
                appIconName: "folder.fill",
                title: "File Added to Tray",
                body: item.name,
                bundleId: ""
            )
        )
    }

    private func preselectTool(for item: ShelfItem) {
        if items.count > 1 {
            selectedTool = .merge
        } else if item.isPDF {
            selectedTool = .compress
        } else if item.isImage {
            selectedTool = .enhance
        } else if item.isTextOrDoc {
            selectedTool = .convert
        }
    }

    public func addFilesFromDrop(_ providers: [NSItemProvider], autoShare: Bool = false) -> Bool {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return false }

        let cacheDirectory = tempCacheDirectory
        let accumulator = ShelfDropAccumulator()
        let group = DispatchGroup()

        for provider in fileProviders {
            group.enter()
            _ = provider.loadFileRepresentation(
                forTypeIdentifier: UTType.fileURL.identifier
            ) { temporaryURL, error in
                defer { group.leave() }

                guard error == nil, let temporaryURL else {
                    accumulator.recordFailure()
                    return
                }

                // Apple deletes this temporary file when the callback returns.
                // Copy synchronously before leaving this callback.
                guard let ownedURL = Self.copyDroppedFileToCache(
                    temporaryURL,
                    cacheDirectory: cacheDirectory
                ) else {
                    accumulator.recordFailure()
                    return
                }

                accumulator.append(ownedURL)
            }
        }

        group.notify(queue: .main) { [weak self] in
            let result = accumulator.snapshot()
            Task { @MainActor [weak self] in
                guard let self else {
                    result.urls.forEach { try? FileManager.default.removeItem(at: $0) }
                    return
                }

                result.urls.forEach { self.addItem($0) }

                if result.failures > 0 {
                    self.statusMessage = result.urls.isEmpty
                        ? "The dropped file(s) could not be imported."
                        : "Imported \(result.urls.count) file(s); \(result.failures) could not be read."
                }

                if autoShare, !result.urls.isEmpty {
                    self.shareAirDropDirectly(urls: result.urls)
                }
            }
        }
        return true
    }

    nonisolated private static func copyDroppedFileToCache(
        _ sourceURL: URL,
        cacheDirectory: URL
    ) -> URL? {
        let name = sanitizedFileName(sourceURL.lastPathComponent, fallback: "Dropped_File")
        let destination = cacheDirectory.appendingPathComponent(
            "Drop_\(UUID().uuidString)_\(name)",
            isDirectory: false
        )

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: destination.path
            )
            return destination
        } catch {
            return nil
        }
    }

    nonisolated private static func sanitizedFileName(
        _ proposedName: String,
        fallback: String
    ) -> String {
        var name = (proposedName as NSString).lastPathComponent
        name = String(name.unicodeScalars.filter {
            $0.value >= 32 && $0.value != 127 && $0 != "/" && $0 != "\\"
        })
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasPrefix(".") { name.removeFirst() }
        return name.isEmpty ? fallback : name
    }

    public func chooseFilesFromFinder() {
        FeedbackManager.playClick()
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add to Tray"
        panel.title = "Select Files for File Studio"

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            let urls = panel.urls
            Task { @MainActor [weak self] in
                guard let self else { return }
                urls.forEach { self.addItem($0) }
            }
        }
    }

    public func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        releaseSecurityScope(for: id)
        FeedbackManager.playDelete()
        if items.isEmpty { statusMessage = nil }
    }

    public func clearAll() {
        let oldItems = items
        items.removeAll()
        for item in oldItems {
            // Security scopes are deferred until background workers release their inputs.
            releaseSecurityScope(for: item.id)
        }
        // Imported drop copies are left for the age-based cache sweeper. Deleting them
        // here could race a worker that is still reading a recently cancelled operation.
        statusMessage = nil
        draggingItemID = nil
        FeedbackManager.playDelete()
        // Keep resultantDocument and its file intact; Clear All means tray only.
    }

    private func releaseSecurityScope(for id: UUID) {
        guard let url = securityScopedURLs.removeValue(forKey: id) else { return }
        if activeWorkerCount > 0 {
            deferredSecurityScopeURLs.append(url)
        } else {
            url.stopAccessingSecurityScopedResource()
        }
    }

    private func releaseDeferredResourcesIfIdle() {
        guard activeWorkerCount == 0 else { return }

        let scopes = deferredSecurityScopeURLs
        deferredSecurityScopeURLs.removeAll()
        scopes.forEach { $0.stopAccessingSecurityScopedResource() }

        let files = deferredTempURLsToDelete
        deferredTempURLsToDelete.removeAll()
        files.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    // MARK: Reordering

    public func beginDraggingItem(_ id: UUID) {
        draggingItemID = id
    }

    public func finishDraggingItem() {
        draggingItemID = nil
    }

    public func moveItem(from sourceId: UUID, to targetId: UUID) {
        guard sourceId != targetId,
              let sourceIndex = items.firstIndex(where: { $0.id == sourceId }),
              let targetIndex = items.firstIndex(where: { $0.id == targetId }) else {
            return
        }

        withAnimation(.spring(
            response: DesignSystem.springResponse,
            dampingFraction: DesignSystem.springDamping
        )) {
            let moved = items.remove(at: sourceIndex)
            // The target shifts left by one when the source was before it.
            let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
            items.insert(moved, at: min(adjustedTarget, items.count))
        }
        FeedbackManager.playHover()
    }

    public func moveItemOffset(id: UUID, direction: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + direction
        guard items.indices.contains(destination) else { return }

        withAnimation(.spring(
            response: DesignSystem.springResponse,
            dampingFraction: DesignSystem.springDamping
        )) {
            let moved = items.remove(at: index)
            items.insert(moved, at: destination)
        }
        FeedbackManager.playClick()
    }

    // MARK: Result Naming and Export

    private func normalizedPDFName(_ proposedName: String) -> String {
        var name = Self.sanitizedFileName(proposedName, fallback: "Resultant_Document")
        if name.lowercased().hasSuffix(".pdf") {
            name = String(name.dropLast(4))
        }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "Resultant_Document" }
        return name + ".pdf"
    }

    private func uniqueURL(in directory: URL, fileName: String) -> URL {
        let safeName = Self.sanitizedFileName(fileName, fallback: "Document.pdf")
        let ext = (safeName as NSString).pathExtension
        let base = (safeName as NSString).deletingPathExtension
        var candidate = directory.appendingPathComponent(safeName)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let nextName = ext.isEmpty
                ? "\(base)_\(counter)"
                : "\(base)_\(counter).\(ext)"
            candidate = directory.appendingPathComponent(nextName)
            counter += 1
        }
        return candidate
    }

    /// Creates a uniquely named copy for external drag-out or sharing.
    /// On copy failure, returns the original result URL rather than a missing path.
    public func exportURL(for doc: ResultantPDF) -> URL {
        let fileName = normalizedPDFName(resultantFileName.isEmpty ? doc.fileName : resultantFileName)
        let exportDirectory = tempCacheDirectory.appendingPathComponent("Exports", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: exportDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let destination = uniqueURL(in: exportDirectory, fileName: fileName)
            try FileManager.default.copyItem(at: doc.fileURL, to: destination)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: destination.path
            )
            return destination
        } catch {
            statusMessage = "Could not prepare the renamed export: \(error.localizedDescription)"
            return doc.fileURL
        }
    }

    private func outputURL(for proposedName: String) -> URL {
        uniqueURL(in: tempCacheDirectory, fileName: normalizedPDFName(proposedName))
    }

    private func publishResult(_ result: ResultantPDF, successMessage: String) {
        resultantDocument = result
        resultantFileName = result.fileName
        leftStageMode = .preview
        isProcessing = false
        processingProgress = 1
        processingStage = ""
        statusMessage = successMessage
        FeedbackManager.playSuccess()
    }

    // MARK: Processing Lifecycle

    public func cancelProcessing() {
        let wasProcessing = isProcessing
        activeOperationID = nil
        workerTask?.cancel()
        currentProcessingTask?.cancel()
        progressTask?.cancel()
        workerTask = nil
        currentProcessingTask = nil
        progressTask = nil
        isProcessing = false
        processingProgress = 0
        processingStage = ""
        if wasProcessing { statusMessage = "Operation cancelled." }
    }

    private func runWorker(
        stage: String,
        operation: @escaping @Sendable (@escaping @Sendable (Double) -> Void) -> ResultantPDF?,
        successMessage: @escaping @Sendable (ResultantPDF) -> String
    ) {
        cancelProcessing()
        let operationID = UUID()
        activeOperationID = operationID
        isProcessing = true
        processingProgress = 0
        processingStage = stage
        statusMessage = nil
        FeedbackManager.playProcess()

        let (stream, continuation) = AsyncStream.makeStream(of: Double.self)
        progressTask = Task { @MainActor [weak self] in
            for await progress in stream {
                guard let self, self.activeOperationID == operationID else { continue }
                self.processingProgress = min(1, max(0, progress))
            }
        }

        activeWorkerCount += 1
        let worker = Task.detached(priority: .userInitiated) {
            let result = operation { progress in
                continuation.yield(progress)
            }
            continuation.finish()
            return result
        }
        workerTask = worker

        currentProcessingTask = Task { @MainActor [weak self] in
            let result = await worker.value
            guard let self else { return }

            self.activeWorkerCount = max(0, self.activeWorkerCount - 1)
            self.releaseDeferredResourcesIfIdle()

            // A cancelled/replaced worker must not overwrite the newer operation's UI state.
            guard self.activeOperationID == operationID else { return }

            self.workerTask = nil
            self.currentProcessingTask = nil
            self.progressTask = nil
            self.activeOperationID = nil

            guard !worker.isCancelled, let result else {
                self.isProcessing = false
                self.processingProgress = 0
                self.processingStage = ""
                self.statusMessage = worker.isCancelled ? "Operation cancelled." : "The operation failed. Check the input file and try again."
                return
            }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                self.publishResult(result, successMessage: successMessage(result))
            }
        }
    }

    // MARK: Merge

    public func mergeDocuments() {
        guard !items.isEmpty else {
            statusMessage = "Add at least one supported file to merge."
            return
        }

        var preparedSources: [ShelfItem] = []
        for item in items {
            if item.isPDF || item.isImage {
                preparedSources.append(item)
            } else if item.isTextOrDoc {
                guard let document = createPDFFromTextOrDoc(url: item.url) else {
                    statusMessage = "Could not convert \(item.name) for merging."
                    return
                }
                let tempURL = outputURL(for: "\(UUID().uuidString)_Converted.pdf")
                guard document.write(to: tempURL) else {
                    statusMessage = "Could not prepare \(item.name) for merging."
                    return
                }
                preparedSources.append(ShelfItem(url: tempURL))
            } else {
                statusMessage = "Unsupported file: \(item.name)"
                return
            }
        }

        let sources = preparedSources
        let destination = outputURL(for: "Merged_Document.pdf")
        runWorker(
            stage: "Merging documents…",
            operation: { progress in
                Self.performMerge(
                    items: sources,
                    outputURL: destination,
                    defaultName: "Merged_Document.pdf",
                    onProgress: progress
                )
            },
            successMessage: { result in
                "Merged \(sources.count) files into \(result.pageCount) pages."
            }
        )
    }

    // MARK: Compress

    public func compressPDF(targetURL: URL? = nil, customName: String? = nil) {
        let sourceURL: URL
        let baseName: String

        if let targetURL {
            sourceURL = targetURL
            baseName = (targetURL.lastPathComponent as NSString).deletingPathExtension
        } else if let result = resultantDocument {
            sourceURL = result.fileURL
            baseName = (result.fileName as NSString).deletingPathExtension
        } else if let target = items.first(where: \.isPDF) {
            sourceURL = target.url
            baseName = (target.name as NSString).deletingPathExtension
        } else {
            statusMessage = "Add a PDF to compress."
            return
        }

        let outputName = normalizedPDFName(customName ?? "\(baseName)_Compressed.pdf")
        let destination = outputURL(for: outputName)
        runWorker(
            stage: "Compressing PDF pages…",
            operation: { progress in
                Self.performCompression(
                    sourceURL: sourceURL,
                    outputURL: destination,
                    outputName: outputName,
                    onProgress: progress
                )
            },
            successMessage: { result in result.summary }
        )
    }

    // MARK: Convert

    public func convertToPDF() {
        guard let target = items.first(where: { $0.isImage || $0.isTextOrDoc }) else {
            statusMessage = "Add an image or supported document to convert."
            return
        }

        let baseName = (target.name as NSString).deletingPathExtension
        let outputName = normalizedPDFName("\(baseName).pdf")
        let destination = outputURL(for: outputName)
        let sourceURL = target.url

        if target.isImage {
            runWorker(
                stage: "Converting image to PDF…",
                operation: { progress in
                    let result = Self.performImageConversion(
                        imageURL: sourceURL,
                        outputURL: destination,
                        outputName: outputName,
                        targetName: target.name
                    )
                    progress(result == nil ? 0 : 1)
                    return result
                },
                successMessage: { $0.summary }
            )
        } else {
            guard let textDocument = createPDFFromTextOrDoc(url: sourceURL) else {
                statusMessage = "Could not read \(target.name) as a supported document."
                return
            }
            // NSTextView/PDFDocument conversion stays on the main actor. It is a
            // relatively small document operation; PDF image processing uses workers.
            guard textDocument.write(to: destination) else {
                statusMessage = "Could not write the converted PDF."
                return
            }
            let result = ResultantPDF(
                fileURL: destination,
                fileName: outputName,
                pageCount: textDocument.pageCount,
                byteCount: Self.fileSize(at: destination),
                summary: "Converted \(target.name) into a \(textDocument.pageCount)-page PDF.",
                tool: .convert,
                thumbnailData: Self.renderPageThumbnailStatic(page: textDocument.page(at: 0))
            )
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                publishResult(result, successMessage: result.summary)
            }
        }
    }

    // MARK: Enhance

    public func enhanceDocument() {
        let sourceURL: URL
        let baseName: String
        let isPDF: Bool

        if let result = resultantDocument {
            sourceURL = result.fileURL
            baseName = (result.fileName as NSString).deletingPathExtension
            isPDF = true
        } else if let target = items.first(where: { $0.isPDF || $0.isImage }) {
            sourceURL = target.url
            baseName = (target.name as NSString).deletingPathExtension
            isPDF = target.isPDF
        } else {
            statusMessage = "Add a PDF or image to enhance."
            return
        }

        let outputName = normalizedPDFName("\(baseName)_Enhanced.pdf")
        let destination = outputURL(for: outputName)
        runWorker(
            stage: "Enhancing contrast and clarity…",
            operation: { progress in
                Self.performEnhance(
                    sourceURL: sourceURL,
                    isPdf: isPDF,
                    baseName: baseName,
                    outputURL: destination,
                    onProgress: progress
                )
            },
            successMessage: { $0.summary }
        )
    }

    // MARK: Save / Share / Chain

    public func saveResultantToDisk() {
        guard let result = resultantDocument else { return }
        FeedbackManager.playClick()

        let panel = NSSavePanel()
        panel.title = "Save Processed Document"
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = normalizedPDFName(resultantFileName.isEmpty ? result.fileName : resultantFileName)

        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            let parent = destination.deletingLastPathComponent()
            let temporary = parent.appendingPathComponent(".notchify-\(UUID().uuidString).tmp")
            defer { try? FileManager.default.removeItem(at: temporary) }

            try FileManager.default.copyItem(at: result.fileURL, to: temporary)
            let attributes = try FileManager.default.attributesOfItem(atPath: temporary.path)
            guard ((attributes[.size] as? NSNumber)?.int64Value ?? 0) > 0 else {
                throw CocoaError(.fileWriteUnknown)
            }

            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(
                    destination,
                    withItemAt: temporary,
                    backupItemName: nil,
                    options: .usingNewMetadataOnly
                )
            } else {
                try FileManager.default.moveItem(at: temporary, to: destination)
            }

            statusMessage = "Saved \(destination.lastPathComponent)."
            FeedbackManager.playSuccess()
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    public func shareResultantViaAirDrop() {
        guard let result = resultantDocument else { return }
        shareAirDropDirectly(urls: [exportURL(for: result)])
    }

    public func addResultantToTray() {
        guard let result = resultantDocument else { return }
        let url = exportURL(for: result)
        addItem(url)
        statusMessage = "Added \(url.lastPathComponent) to the tray."
    }

    public func clearPreview() {
        guard !isProcessing else {
            statusMessage = "Cancel the current operation before clearing its source preview."
            return
        }
        guard let document = resultantDocument else { return }
        let fileURL = document.fileURL.standardizedFileURL
        let activeTrayPaths = Set(items.map { $0.url.standardizedFileURL.path })
        let cachePath = tempCacheDirectory.standardizedFileURL.path
        let filePath = fileURL.path
        let isInsideCache = filePath.hasPrefix(cachePath + "/")

        resultantDocument = nil
        resultantFileName = "Merged_Document.pdf"
        leftStageMode = .wheel
        statusMessage = nil

        if isInsideCache && !activeTrayPaths.contains(filePath) {
            if activeWorkerCount > 0 {
                deferredTempURLsToDelete.append(fileURL)
            } else {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        FeedbackManager.playClick()
    }

    // MARK: AirDrop Bridge

    public func shareAirDrop(for item: ShelfItem) {
        shareAirDropDirectly(urls: [item.url])
    }

    public func shareAllAirDrop() {
        let urls = items.map(\.url)
        guard !urls.isEmpty else {
            statusMessage = "No files in the tray to AirDrop."
            return
        }
        shareAirDropDirectly(urls: urls)
    }

    public func shareAirDropDirectly(urls: [URL]) {
        let validURLs = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !validURLs.isEmpty else {
            statusMessage = "No accessible files are available to AirDrop."
            return
        }
        // Actual AirDrop presentation/transfer behavior belongs to AirDropModule.
        AirDropModule.shared.shareFiles(validURLs)
        statusMessage = "Opening AirDrop for \(validURLs.count) file(s)…"
    }

    // MARK: Compact / Expanded Module Views

    public func makeCompactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                AirDropMark(size: 10)
                    .foregroundStyle(DesignSystem.accentColor)
                Text("\(items.count) files")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color.primary)
            }
        )
    }

    public func makeExpandedView() -> AnyView {
        AnyView(ShelfModuleExpandedView(module: self))
    }

    // MARK: Static File / PDF Helpers

    nonisolated public static func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    nonisolated public static func renderPageThumbnailStatic(page: PDFPage?) -> Data? {
        guard let page else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let targetWidth: CGFloat = 180
        let scale = targetWidth / bounds.width
        let size = NSSize(width: targetWidth, height: max(80, bounds.height * scale))
        let thumbnail = page.thumbnail(of: size, for: .mediaBox)
        var rect = CGRect(origin: .zero, size: size)

        if let cgImage = thumbnail.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            let representation = NSBitmapImageRep(cgImage: cgImage)
            return representation.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.82]
            )
        }
        if let tiff = thumbnail.tiffRepresentation,
           let representation = NSBitmapImageRep(data: tiff) {
            return representation.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.82]
            )
        }
        return nil
    }

    nonisolated public static func performMerge(
        items: [ShelfItem],
        outputURL: URL,
        defaultName: String,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) -> ResultantPDF? {
        guard !items.isEmpty else { return nil }
        let document = PDFDocument()
        let total = items.count

        for (index, item) in items.enumerated() {
            if Task.isCancelled { return nil }

            if item.isPDF {
                guard let source = PDFDocument(url: item.url), source.pageCount > 0 else {
                    return nil
                }
                for pageIndex in 0..<source.pageCount {
                    if Task.isCancelled { return nil }
                    guard let page = source.page(at: pageIndex) else { continue }
                    document.insert(page, at: document.pageCount)
                }
            } else if item.isImage {
                guard let image = NSImage(contentsOf: item.url),
                      let page = PDFPage(image: image) else { return nil }
                document.insert(page, at: document.pageCount)
            } else {
                // Text/document inputs must be converted before entering this worker.
                return nil
            }
            onProgress?(Double(index + 1) / Double(max(1, total)))
        }

        guard !Task.isCancelled, document.pageCount > 0 else { return nil }
        try? FileManager.default.removeItem(at: outputURL)
        guard document.write(to: outputURL) else { return nil }

        return ResultantPDF(
            fileURL: outputURL,
            fileName: defaultName,
            pageCount: document.pageCount,
            byteCount: fileSize(at: outputURL),
            summary: "Merged \(items.count) files into \(document.pageCount) pages.",
            tool: .merge,
            thumbnailData: renderPageThumbnailStatic(page: document.page(at: 0))
        )
    }

    nonisolated public static func performCompression(
        sourceURL: URL,
        outputURL: URL,
        outputName: String,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) -> ResultantPDF? {
        guard let input = PDFDocument(url: sourceURL), input.pageCount > 0 else { return nil }
        let compressed = PDFDocument()
        let total = input.pageCount

        for index in 0..<total {
            if Task.isCancelled { return nil }
            guard let page = input.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 1.15
            let size = NSSize(
                width: max(80, bounds.width * scale),
                height: max(80, bounds.height * scale)
            )

            let image = NSImage(size: size, flipped: false) { rect in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                context.setFillColor(NSColor.white.cgColor)
                context.fill(rect)
                context.saveGState()
                context.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: context)
                context.restoreGState()
                return true
            }

            if let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let jpeg = bitmap.representation(
                    using: .jpeg,
                    properties: [.compressionFactor: 0.58]
               ),
               let rasterImage = NSImage(data: jpeg),
               let rasterPage = PDFPage(image: rasterImage) {
                compressed.insert(rasterPage, at: compressed.pageCount)
            } else {
                compressed.insert(page, at: compressed.pageCount)
            }
            onProgress?(Double(index + 1) / Double(max(1, total)))
        }

        guard !Task.isCancelled, compressed.pageCount > 0, compressed.pageCount == input.pageCount else { return nil }
        try? FileManager.default.removeItem(at: outputURL)
        guard compressed.write(to: outputURL) else { return nil }

        let originalBytes = fileSize(at: sourceURL)
        var outputBytes = fileSize(at: outputURL)
        var resultThumbnail = renderPageThumbnailStatic(page: compressed.page(at: 0))
        if originalBytes > 0, outputBytes >= originalBytes {
            // Do not report a larger rasterized PDF as a successful compression.
            try? FileManager.default.removeItem(at: outputURL)
            do {
                try FileManager.default.copyItem(at: sourceURL, to: outputURL)
            } catch {
                return nil
            }
            outputBytes = fileSize(at: outputURL)
            resultThumbnail = renderPageThumbnailStatic(page: input.page(at: 0))
        }

        let reduction = originalBytes > 0
            ? max(0, Int((1 - Double(outputBytes) / Double(originalBytes)) * 100))
            : 0
        let summary = reduction > 0
            ? "Reduced file size by approximately \(reduction)%. This operation rasterizes pages and may remove selectable text or vector detail."
            : "No size reduction was achieved; the original PDF was retained."

        return ResultantPDF(
            fileURL: outputURL,
            fileName: outputName,
            pageCount: compressed.pageCount,
            byteCount: outputBytes,
            summary: summary,
            tool: .compress,
            thumbnailData: resultThumbnail
        )
    }

    nonisolated public static func performImageConversion(
        imageURL: URL,
        outputURL: URL,
        outputName: String,
        targetName: String
    ) -> ResultantPDF? {
        guard let image = NSImage(contentsOf: imageURL),
              let page = PDFPage(image: image) else { return nil }
        let document = PDFDocument()
        document.insert(page, at: 0)

        try? FileManager.default.removeItem(at: outputURL)
        guard document.write(to: outputURL), !Task.isCancelled else { return nil }

        return ResultantPDF(
            fileURL: outputURL,
            fileName: outputName,
            pageCount: 1,
            byteCount: fileSize(at: outputURL),
            summary: "Converted \(targetName) into a one-page PDF.",
            tool: .convert,
            thumbnailData: renderPageThumbnailStatic(page: document.page(at: 0))
        )
    }

    nonisolated public static func performEnhance(
        sourceURL: URL,
        isPdf: Bool,
        baseName: String,
        outputURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) -> ResultantPDF? {
        let output = PDFDocument()
        let context = CIContext(options: nil)

        if isPdf {
            guard let input = PDFDocument(url: sourceURL), input.pageCount > 0 else { return nil }
            let total = input.pageCount
            for index in 0..<total {
                if Task.isCancelled { return nil }
                guard let page = input.page(at: index) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                let image = NSImage(size: bounds.size, flipped: false) { rect in
                    guard let graphics = NSGraphicsContext.current?.cgContext else { return false }
                    graphics.setFillColor(NSColor.white.cgColor)
                    graphics.fill(rect)
                    page.draw(with: .mediaBox, to: graphics)
                    return true
                }
                if let enhanced = enhanceImageStatic(image, ciContext: context),
                   let enhancedPage = PDFPage(image: enhanced) {
                    output.insert(enhancedPage, at: output.pageCount)
                } else {
                    output.insert(page, at: output.pageCount)
                }
                onProgress?(Double(index + 1) / Double(max(1, total)))
            }
        } else {
            guard let image = NSImage(contentsOf: sourceURL),
                  let enhanced = enhanceImageStatic(image, ciContext: context),
                  let page = PDFPage(image: enhanced) else { return nil }
            output.insert(page, at: 0)
            onProgress?(1)
        }

        guard !Task.isCancelled, output.pageCount > 0 else { return nil }
        try? FileManager.default.removeItem(at: outputURL)
        guard output.write(to: outputURL) else { return nil }
        let outputName = "\(baseName)_Enhanced.pdf"

        return ResultantPDF(
            fileURL: outputURL,
            fileName: outputName,
            pageCount: output.pageCount,
            byteCount: fileSize(at: outputURL),
            summary: "Enhanced contrast and sharpness. Review the result for artifacts before sharing.",
            tool: .enhance,
            thumbnailData: renderPageThumbnailStatic(page: output.page(at: 0))
        )
    }

    nonisolated public static func enhanceImageStatic(
        _ image: NSImage,
        ciContext: CIContext
    ) -> NSImage? {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        let input: CIImage
        if let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            input = CIImage(cgImage: cgImage)
        } else if let tiff = image.tiffRepresentation,
                  let converted = CIImage(data: tiff) {
            input = converted
        } else {
            return nil
        }

        guard let colorFilter = CIFilter(name: "CIColorControls") else { return nil }
        colorFilter.setValue(input, forKey: kCIInputImageKey)
        colorFilter.setValue(1.35, forKey: kCIInputContrastKey)
        colorFilter.setValue(0.04, forKey: kCIInputBrightnessKey)
        colorFilter.setValue(0.08, forKey: kCIInputSaturationKey)

        guard let colorOutput = colorFilter.outputImage,
              let sharpenFilter = CIFilter(name: "CISharpenLuminance") else { return nil }
        sharpenFilter.setValue(colorOutput, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.75, forKey: kCIInputSharpnessKey)

        guard let finalImage = sharpenFilter.outputImage,
              let cgImage = ciContext.createCGImage(finalImage, from: finalImage.extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: image.size)
    }

    // Called on the main actor because NSTextView and document conversion use AppKit UI types.
    private func createPDFFromTextOrDoc(url: URL) -> PDFDocument? {
        let attributed: NSAttributedString
        if let imported = try? NSAttributedString(
            url: url,
            options: [:],
            documentAttributes: nil
        ) {
            attributed = imported
        } else if let text = try? String(contentsOf: url, encoding: .utf8) {
            attributed = NSAttributedString(
                string: text,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular),
                    .foregroundColor: NSColor.black
                ]
            )
        } else {
            return nil
        }

        let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
        let textRect = pageRect.insetBy(dx: 48, dy: 48)
        let textView = NSTextView(frame: textRect)
        textView.textStorage?.setAttributedString(attributed)
        let data = textView.dataWithPDF(inside: textRect)
        return PDFDocument(data: data)
    }
}

// MARK: - AirDrop Symbol with Runtime Fallback

private struct AirDropMark: View {
    var size: CGFloat = 12

    private var systemImage: NSImage? {
        let image = NSImage(
            systemSymbolName: "airdrop",
            accessibilityDescription: "AirDrop"
        )
        image?.isTemplate = true
        return image
    }

    var body: some View {
        Group {
            if let systemImage {
                Image(nsImage: systemImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("AirDrop")
    }
}

// MARK: - Expanded File Studio View

public struct ShelfModuleExpandedView: View {
    @ObservedObject var module: ShelfModule
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchCompact) private var notchCompact
    @Environment(\.notchTight) private var notchTight
    @StateObject private var titleDropState = LocalUIState()

    public var body: some View {
        VStack(spacing: notchTight ? 5 : (notchCompact ? 7 : 10)) {
            headerBar

            let wheelSize: CGFloat = notchTight ? 95 : (notchCompact ? 115 : 140)
            let leftColumnWidth: CGFloat = notchTight ? 105 : (notchCompact ? 125 : 154)

            HStack(alignment: .top, spacing: notchTight ? 8 : (notchCompact ? 10 : 14)) {
                leftStage(wheelSize: wheelSize, leftColumnWidth: leftColumnWidth)

                VStack(alignment: .leading, spacing: notchTight ? 5 : 8) {
                    activeToolCard
                    stagedFilesTray
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "doc.badge.gearshape.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignSystem.accentColor)

                if !notchTight {
                    Text("File Studio")
                        .font(.system(size: notchCompact ? 11.5 : 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DesignSystem.secondaryText.opacity(0.7))
                }

                Text(module.selectedTool.title)
                    .font(.system(size: notchTight ? 10 : 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.accentColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if !notchCompact {
                    Text("(\(module.items.count) in tray)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignSystem.secondaryText)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(
                Capsule().fill(titleDropState.isTargeted ? DesignSystem.accentColor.opacity(0.18) : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(
                    titleDropState.isTargeted ? DesignSystem.accentColor : Color.clear,
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
            )
            // Files dropped on the File Studio title are added to the staging tray.
            .onDrop(of: [UTType.fileURL], isTargeted: $titleDropState.isTargeted) { providers in
                module.addFilesFromDrop(providers)
            }
            .accessibilityHint("Drop files here to add them to the File Studio tray")

            Spacer(minLength: 2)

            if module.resultantDocument != nil {
                HStack(spacing: 3) {
                    stageModeButton(title: "Tools", symbol: "circle.circle", mode: .wheel)
                    stageModeButton(title: "Preview", symbol: "doc.text.image.fill", mode: .preview)
                    Button(action: module.clearPreview) {
                        Label("Clear", systemImage: "xmark")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .foregroundStyle(DesignSystem.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .disabled(module.isProcessing)
                    .help("Clear preview and return to the tools wheel")
                }
                .padding(2)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
            }

            Button(action: module.chooseFilesFromFinder) {
                Label("Add Files", systemImage: "plus.circle.fill")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignSystem.accentColor.opacity(0.15)))
                    .overlay(Capsule().strokeBorder(DesignSystem.accentColor.opacity(0.35), lineWidth: 0.8))
            }
            .buttonStyle(.spring)
            .help("Add files from Finder")

            if !module.items.isEmpty {
                Button(action: module.clearAll) {
                    Label("Clear", systemImage: "trash")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(DesignSystem.secondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.spring)
                .help("Clear the staging tray; the result preview is kept")
            }
        }
        .padding(.horizontal, 2)
    }

    private func stageModeButton(
        title: String,
        symbol: String,
        mode: LeftStageMode
    ) -> some View {
        let selected = module.leftStageMode == mode
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.82)) {
                module.leftStageMode = mode
            }
            FeedbackManager.playClick()
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 9, weight: selected ? .bold : .medium, design: .rounded))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(selected ? DesignSystem.accentColor.opacity(0.22) : Color.clear))
                .foregroundStyle(selected ? DesignSystem.accentColor : DesignSystem.secondaryText)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func leftStage(wheelSize: CGFloat, leftColumnWidth: CGFloat) -> some View {
        ZStack {
            if module.leftStageMode == .preview, let document = module.resultantDocument {
                ResultantPDFPreviewCard(module: module, doc: document)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                VStack(spacing: notchTight ? 3 : 6) {
                    InteractiveStudioWheel(module: module)
                        .frame(width: wheelSize, height: wheelSize)
                    if !notchTight {
                        Text("Dial or tap to select")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(DesignSystem.secondaryText)
                    }
                }
                .frame(width: wheelSize)
                .transition(.opacity)
            }
        }
        .frame(width: leftColumnWidth)
    }

    private var activeToolCard: some View {
        VStack(alignment: .leading, spacing: notchTight ? 3 : 5) {
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(module.selectedTool.title)
                        .font(.system(size: notchTight ? 11.5 : 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    if !notchTight {
                        Text(module.selectedTool.subtitle)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DesignSystem.secondaryText)
                            .lineLimit(notchCompact ? 1 : 2)
                    }
                }
                Spacer(minLength: 3)
                AirDropDropTargetCapsule(module: module)
            }

            HStack(spacing: 6) {
                Button(action: executeActiveTool) {
                    HStack(spacing: 5) {
                        if module.isProcessing {
                            ProgressView().controlSize(.small)
                        } else if module.selectedTool == .airdrop {
                            AirDropMark(size: 10)
                        } else {
                            Image(systemName: module.selectedTool.icon)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        Text(module.isProcessing ? module.processingStage : module.selectedTool.actionTitle)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(DesignSystem.accentColor))
                }
                .buttonStyle(.spring)
                .disabled(module.isProcessing || !canRunActiveTool)
                .opacity(canRunActiveTool ? 1 : 0.45)

                Button(action: module.shareAllAirDrop) {
                    HStack(spacing: 4) {
                        AirDropMark(size: 10)
                        Text("AirDrop")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                    .overlay(Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8))
                }
                .buttonStyle(.spring)
                .disabled(module.items.isEmpty || module.isProcessing)
                .opacity(module.items.isEmpty ? 0.4 : 1)
                .help("Send all staged files using AirDrop")

                if module.isProcessing {
                    Button(action: module.cancelProcessing) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel operation")
                }
            }

            if module.isProcessing {
                ProgressView(value: module.processingProgress)
                    .tint(DesignSystem.accentColor)
            }

            if let status = module.statusMessage, !status.isEmpty {
                Text(status)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(DesignSystem.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.structureColor.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
        )
    }

    private var canRunActiveTool: Bool {
        switch module.selectedTool {
        case .merge:
            return !module.items.isEmpty && module.items.allSatisfy(\.isSupported)
        case .compress:
            return module.resultantDocument != nil || module.items.contains(where: \.isPDF)
        case .convert:
            return module.items.contains(where: { $0.isImage || $0.isTextOrDoc })
        case .enhance:
            return module.resultantDocument != nil || module.items.contains(where: { $0.isPDF || $0.isImage })
        case .airdrop:
            return !module.items.isEmpty
        }
    }

    private func executeActiveTool() {
        guard !module.isProcessing else { return }
        FeedbackManager.playClick()
        switch module.selectedTool {
        case .merge: module.mergeDocuments()
        case .compress: module.compressPDF()
        case .convert: module.convertToPDF()
        case .enhance: module.enhanceDocument()
        case .airdrop: module.shareAllAirDrop()
        }
    }

    // Always accepts file URLs, even when there are already staged files.
    private var stagedFilesTray: some View {
        Group {
            if module.items.isEmpty {
                emptyTray
            } else {
                populatedTray
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $module.isTrayHovered) { providers in
            module.addFilesFromDrop(providers)
        }
    }

    private var emptyTray: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(DesignSystem.accentColor.opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Drop PDFs, images or documents here")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)
                Text("You can also drop files on the File Studio title")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(DesignSystem.secondaryText)
            }
            Spacer(minLength: 2)

            Button(action: module.chooseFilesFromFinder) {
                Label("Browse", systemImage: "folder.badge.plus")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(DesignSystem.structureColor))
                    .overlay(Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8))
            }
            .buttonStyle(.spring)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(module.isTrayHovered ? DesignSystem.accentColor.opacity(0.13) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    module.isTrayHovered ? DesignSystem.accentColor : DesignSystem.cardBorder,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        )
    }

    private var populatedTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(module.items.enumerated()), id: \.element.id) { index, item in
                    StagedFileChip(
                        module: module,
                        item: item,
                        index: index,
                        total: module.items.count
                    )
                }

                Button(action: module.chooseFilesFromFinder) {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(DesignSystem.secondaryText)
                        .padding(.horizontal, 9)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DesignSystem.cardBorder, style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])))
                }
                .buttonStyle(.spring)
                .help("Add more files")
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 1)
        }
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(module.isTrayHovered ? DesignSystem.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(module.isTrayHovered ? DesignSystem.accentColor : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Result Preview Card

public struct ResultantPDFPreviewCard: View {
    @ObservedObject var module: ShelfModule
    let doc: ResultantPDF
    @StateObject private var uiState = LocalUIState()

    public init(module: ShelfModule, doc: ResultantPDF) {
        self.module = module
        self.doc = doc
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottom) {
                    if let data = doc.thumbnailData, let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 86)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: Color.black.opacity(0.35), radius: 5, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.07))
                            .frame(width: 140, height: 86)
                            .overlay {
                                Image(systemName: "doc.richtext.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(DesignSystem.accentColor)
                            }
                    }

                    HStack(spacing: 4) {
                        Text("\(doc.pageCount) pages")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(DesignSystem.accentColor))
                        Text(doc.formattedSize)
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.72)))
                    }
                    .padding(4)
                }

                Button(action: module.clearPreview) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 19, height: 19)
                        .background(Circle().fill(Color.black.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .disabled(module.isProcessing)
                .padding(4)
                .help("Clear preview")
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(uiState.isHovered ? DesignSystem.accentColor : DesignSystem.cardBorder, lineWidth: 1)
            )
            .scaleEffect(uiState.isHovered ? 1.02 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.82), value: uiState.isHovered)
            .onHover { uiState.isHovered = $0 }
            .onDrag {
                FeedbackManager.playHover()
                let url = module.exportURL(for: doc)
                return NSItemProvider(contentsOf: url) ?? NSItemProvider()
            }
            .help("Drag this PDF to Finder or another app")

            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.system(size: 8))
                    .foregroundStyle(DesignSystem.secondaryText)
                TextField("Document name", text: $module.resultantFileName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .onSubmit {
                        module.resultantFileName = module.resultantFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))

            HStack(spacing: 4) {
                Button(action: module.saveResultantToDisk) {
                    Label("Save…", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(DesignSystem.accentColor))
                }
                .buttonStyle(.spring)
                .help("Save the renamed PDF to your Mac")

                Button(action: module.shareResultantViaAirDrop) {
                    HStack(spacing: 3) {
                        AirDropMark(size: 9)
                        Text("AirDrop")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.09)))
                }
                .buttonStyle(.spring)
                .help("AirDrop the renamed PDF")

                Button(action: module.addResultantToTray) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(DesignSystem.secondaryText)
                        .padding(5)
                        .background(Circle().fill(Color.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .help("Add result to the staging tray")

                Button(action: module.clearPreview) {
                    Image(systemName: "trash")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(DesignSystem.secondaryText)
                        .padding(5)
                        .background(Circle().fill(Color.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .help("Clear preview")
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignSystem.structureColor.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
        )
    }
}

// MARK: - Staged File Chip

public struct StagedFileChip: View {
    @ObservedObject var module: ShelfModule
    let item: ShelfItem
    let index: Int
    let total: Int
    @StateObject private var uiState = LocalUIState()

    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: fileIcon)
                .font(.system(size: 9.5))
                .foregroundStyle(DesignSystem.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 80, alignment: .leading)
                Text(item.size)
                    .font(.system(size: 7.5))
                    .foregroundStyle(DesignSystem.secondaryText)
            }

            if uiState.isHovered && total > 1 {
                HStack(spacing: 2) {
                    if index > 0 {
                        Button { module.moveItemOffset(id: item.id, direction: -1) } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(DesignSystem.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .help("Move left")
                    }
                    if index < total - 1 {
                        Button { module.moveItemOffset(id: item.id, direction: 1) } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(DesignSystem.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .help("Move right")
                    }
                }
            }

            Button(action: { module.shareAirDrop(for: item) }) {
                AirDropMark(size: 9)
                    .foregroundStyle(DesignSystem.secondaryText)
            }
            .buttonStyle(.spring)
            .help("AirDrop \(item.name)")

            Button(action: { module.removeItem(id: item.id) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 8.5))
                    .foregroundStyle(DesignSystem.secondaryText.opacity(0.8))
            }
            .buttonStyle(.spring)
            .help("Remove \(item.name)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(DesignSystem.structureColor))
        .overlay(
            Capsule().strokeBorder(
                uiState.isHovered ? DesignSystem.accentColor.opacity(0.55) : DesignSystem.cardBorder,
                lineWidth: 0.8
            )
        )
        .onHover { uiState.isHovered = $0 }
        .onDrag {
            module.beginDraggingItem(item.id)
            FeedbackManager.playHover()
            return ShelfDragPayload.provider(for: item.id)
        }
        // Distinct internal UTI prevents stale drag state from intercepting Finder file drops.
        .onDrop(
            of: [ShelfDragPayload.itemID, UTType.fileURL],
            delegate: StagedFileDropDelegate(item: item, module: module)
        )
        .onDisappear { module.finishDraggingItem() }
    }

    private var fileIcon: String {
        if item.isPDF { return "doc.richtext.fill" }
        if item.isImage { return "photo.fill" }
        if item.isTextOrDoc { return "doc.text.fill" }
        return "doc.fill"
    }
}

// MARK: - Drop Delegate (Reorder + External File Import)

public struct StagedFileDropDelegate: DropDelegate {
    let item: ShelfItem
    let module: ShelfModule

    public init(item: ShelfItem, module: ShelfModule) {
        self.item = item
        self.module = module
    }

    private func isInternalReorder(_ info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [ShelfDragPayload.itemID])
    }

    public func validateDrop(info: DropInfo) -> Bool {
        isInternalReorder(info) || info.hasItemsConforming(to: [UTType.fileURL])
    }

    public func dropEntered(info: DropInfo) {
        guard isInternalReorder(info),
              let sourceID = module.draggingItemID,
              sourceID != item.id else { return }
        module.moveItem(from: sourceID, to: item.id)
    }

    public func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: isInternalReorder(info) ? .move : .copy)
    }

    public func performDrop(info: DropInfo) -> Bool {
        if isInternalReorder(info) {
            module.finishDraggingItem()
            return true
        }

        let providers = info.itemProviders(for: [UTType.fileURL])
        let accepted = module.addFilesFromDrop(providers)
        module.finishDraggingItem()
        return accepted
    }

    public func dropExited(info: DropInfo) {
        // The active internal drag remains active while traversing adjacent chips.
    }
}

// MARK: - AirDrop Drop Target

private struct AirDropDropTargetCapsule: View {
    @ObservedObject var module: ShelfModule

    var body: some View {
        HStack(spacing: 5) {
            AirDropMark(size: 11)
                .foregroundStyle(module.isAirDropHovered ? Color.black : DesignSystem.accentColor)
            Text(module.isAirDropHovered ? "Release to AirDrop" : "Drop to AirDrop")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(module.isAirDropHovered ? Color.black : Color.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(module.isAirDropHovered ? DesignSystem.accentColor : Color.primary.opacity(0.07))
        )
        .overlay(
            Capsule().strokeBorder(
                module.isAirDropHovered ? DesignSystem.accentColor : DesignSystem.cardBorder,
                lineWidth: 1
            )
        )
        .scaleEffect(module.isAirDropHovered ? 1.04 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: module.isAirDropHovered)
        .onDrop(of: [UTType.fileURL], isTargeted: $module.isAirDropHovered) { providers in
            module.addFilesFromDrop(providers, autoShare: true)
        }
        .help("Drop files here to add them and open AirDrop")
        .accessibilityLabel("Drop files here to add them and AirDrop")
    }
}

// MARK: - Interactive Studio Wheel

@MainActor
final class WheelDragState: ObservableObject {
    @Published var startAngle: Double? = nil
    @Published var startRotation: Double = 0.0
}

public struct InteractiveStudioWheel: View {
    @ObservedObject var module: ShelfModule
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tools = FileStudioTool.allCases
    @StateObject private var dragState = WheelDragState()

    public var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            // The old fixed 46-point radius made the 95-point compact wheel larger
            // than its frame, clipping hit targets and making outer options hard to tap.
            let radius = side * 0.31
            let nodeSize = max(23, min(34, side * 0.245))
            let hubSize = max(34, min(44, side * 0.32))

            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                DesignSystem.accentColor.opacity(0.35),
                                Color.primary.opacity(0.08),
                                DesignSystem.accentColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: radius * 2 + nodeSize * 0.6, height: radius * 2 + nodeSize * 0.6)
                    .position(center)

                ForEach(0..<12, id: \.self) { tick in
                    let angle = Double(tick) * (2 * .pi / 12)
                    Circle()
                        .fill(Color.primary.opacity(tick.isMultiple(of: 3) ? 0.28 : 0.12))
                        .frame(width: tick.isMultiple(of: 3) ? 3 : 1.5, height: tick.isMultiple(of: 3) ? 3 : 1.5)
                        .position(
                            x: center.x + (radius + nodeSize * 0.32) * CGFloat(cos(angle)),
                            y: center.y + (radius + nodeSize * 0.32) * CGFloat(sin(angle))
                        )
                }

                ForEach(Array(tools.enumerated()), id: \.element.rawValue) { index, tool in
                    let selected = module.selectedTool == tool
                    let baseAngle = Double(index) * (2 * .pi / Double(tools.count)) - (.pi / 2)
                    let angle = baseAngle + module.wheelRotationAngle
                    let x = center.x + radius * CGFloat(cos(angle))
                    let y = center.y + radius * CGFloat(sin(angle))

                    Button {
                        FeedbackManager.playClick()
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                            module.selectedTool = tool
                            module.wheelRotationAngle = -Double(index) * (2 * .pi / Double(tools.count))
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(selected ? DesignSystem.accentColor : DesignSystem.structureColor)
                                .frame(width: selected ? nodeSize : nodeSize * 0.84, height: selected ? nodeSize : nodeSize * 0.84)
                            if tool == .airdrop {
                                AirDropMark(size: selected ? 13 : 11)
                                    .foregroundStyle(selected ? Color.black : Color.primary)
                            } else {
                                Image(systemName: tool.icon)
                                    .font(.system(size: selected ? 12 : 10, weight: selected ? .bold : .medium))
                                    .foregroundStyle(selected ? Color.black : Color.primary)
                            }
                        }
                        .overlay(
                            Circle().strokeBorder(
                                selected ? DesignSystem.accentColor.opacity(0.9) : DesignSystem.cardBorder,
                                lineWidth: selected ? 1.4 : 0.8
                            )
                        )
                        .scaleEffect(selected ? 1.08 : 1)
                        .shadow(color: selected ? DesignSystem.accentColor.opacity(0.35) : .clear, radius: 5)
                        .frame(width: nodeSize + 4, height: nodeSize + 4)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(x: x, y: y)
                    .help(tool.title)
                    .accessibilityLabel(tool.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }

                Circle()
                    .fill(DesignSystem.cardFill)
                    .frame(width: hubSize, height: hubSize)
                    .overlay(Circle().strokeBorder(DesignSystem.accentColor.opacity(0.4), lineWidth: 1))
                    .overlay {
                        if module.selectedTool == .airdrop {
                            AirDropMark(size: 16)
                                .foregroundStyle(DesignSystem.accentColor)
                        } else {
                            Image(systemName: module.selectedTool.icon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(DesignSystem.accentColor)
                        }
                    }
                    .position(center)
                    .onTapGesture { cycleTool() }
                    .accessibilityElement()
                    .accessibilityLabel("Selected tool: \(module.selectedTool.title). Double-click to change tool.")
            }
            // Simultaneous recognition allows the tool buttons to keep receiving taps.
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        let dx = value.startLocation.x - center.x
                        let dy = value.startLocation.y - center.y
                        let currentDX = value.location.x - center.x
                        let currentDY = value.location.y - center.y
                        let startAngle = atan2(dy, dx)
                        let currentAngle = atan2(currentDY, currentDX)

                        if dragState.startAngle == nil {
                            dragState.startAngle = startAngle
                            dragState.startRotation = module.wheelRotationAngle
                        }

                        guard let dragStartAngle = dragState.startAngle else { return }
                        var delta = currentAngle - dragStartAngle
                        if delta > .pi { delta -= 2 * .pi }
                        if delta < -.pi { delta += 2 * .pi }
                        module.wheelRotationAngle = dragState.startRotation + delta
                    }
                    .onEnded { _ in
                        let step = (2 * .pi) / Double(tools.count)
                        let normalized = module.wheelRotationAngle.truncatingRemainder(dividingBy: 2 * .pi)
                        let rawIndex = Int(round(-normalized / step))
                        let selectedIndex = (rawIndex % tools.count + tools.count) % tools.count

                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                            module.selectedTool = tools[selectedIndex]
                            module.wheelRotationAngle = -Double(selectedIndex) * step
                        }
                        dragState.startAngle = nil
                        FeedbackManager.playHover()
                    }
            )
        }
        .clipped()
    }

    private func cycleTool() {
        guard let index = tools.firstIndex(of: module.selectedTool) else { return }
        let next = (index + 1) % tools.count
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
            module.selectedTool = tools[next]
            module.wheelRotationAngle = -Double(next) * (2 * .pi / Double(tools.count))
        }
        FeedbackManager.playClick()
    }
}
