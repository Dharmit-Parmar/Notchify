import SwiftUI
import UniformTypeIdentifiers
import AppKit
import PDFKit
import CoreImage

public enum FileStudioTool: String, CaseIterable, Identifiable, Sendable {
    case merge = "merge"
    case compress = "compress"
    case convert = "convert"
    case enhance = "enhance"
    case airdrop = "airdrop"

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
        case .merge: "Stitch PDFs, images & docs into a single clean PDF"
        case .compress: "Reduce PDF file size while preserving crisp clarity"
        case .convert: "Turn images, markdown, txt and docs into crisp PDF"
        case .enhance: "Auto-level contrast, sharpen text & clean scan tints"
        case .airdrop: "Wirelessly beam directly to iPhone, iPad or Mac"
        }
    }

    public var icon: String {
        switch self {
        case .merge: "doc.on.doc.fill"
        case .compress: "arrow.down.right.and.arrow.up.left"
        case .convert: "arrow.triangle.2.circlepath.doc.on.clipboard"
        case .enhance: "wand.and.stars"
        case .airdrop: "airdrop"
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

public struct ShelfItem: Identifiable, Sendable {
    public let id = UUID()
    public let url: URL
    public let name: String
    public let size: String
    public let byteCount: Int64
    
    public init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attrs[.size] as? Int64 {
            self.byteCount = fileSize
            self.size = ShelfModule.byteFormatter.string(fromByteCount: fileSize)
        } else {
            self.byteCount = 0
            self.size = "File"
        }
    }

    public var ext: String {
        url.pathExtension.lowercased()
    }

    public var isPDF: Bool {
        ext == "pdf"
    }

    public var isImage: Bool {
        ["png", "jpg", "jpeg", "heic", "webp", "tiff", "tif", "bmp"].contains(ext)
    }

    public var isTextOrDoc: Bool {
        ["txt", "rtf", "md", "markdown", "csv", "json", "doc", "docx"].contains(ext)
    }
}

// Resultant Document Representation (Live Preview, In-Memory/Temp Cache, Drag-Out & Rename)
public struct ResultantPDF: Identifiable, Sendable {
    public let id = UUID()
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
        thumbnailData: Data?
    ) {
        self.fileURL = fileURL
        self.fileName = fileName
        self.pageCount = pageCount
        self.byteCount = byteCount
        self.summary = summary
        self.tool = tool
        self.thumbnailData = thumbnailData
        self.formattedSize = ShelfModule.byteFormatter.string(fromByteCount: byteCount)
    }
}

public enum LeftStageMode {
    case wheel
    case preview
}

@MainActor
public final class ShelfModule: NotchModule {
    public static let shared = ShelfModule()
    
    nonisolated(unsafe) public static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter
    }()
    
    public let id = "shelf"
    public let title = "File Studio"
    public let iconName = "doc.badge.gearshape.fill"
    @Published public var isEnabled: Bool = true
    
    @Published public var items: [ShelfItem] = []
    @Published public var statusMessage: String?
    @Published public var selectedTool: FileStudioTool = .merge
    @Published public var isProcessing: Bool = false
    @Published public var processingStage: String = ""
    @Published public var wheelRotationAngle: Double = 0.0
    
    // Resultant PDF Live Preview State
    @Published public var resultantDocument: ResultantPDF?
    @Published public var resultantFileName: String = "Merged_Document.pdf"
    @Published public var leftStageMode: LeftStageMode = .wheel
    
    // Direct drop hover states
    @Published public var isAirDropHovered: Bool = false
    @Published public var isTrayHovered: Bool = false
    
    private let tempCacheDirectory: URL
    
    public init() {
        let baseTemp = FileManager.default.temporaryDirectory.appendingPathComponent("NotchifyStudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseTemp, withIntermediateDirectories: true)
        self.tempCacheDirectory = baseTemp
        cleanStaleTempFiles()
    }
    
    public func start() {}
    public func stop() {}

    public func cleanStaleTempFiles(all: Bool = false) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: tempCacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let now = Date()
        for file in files {
            if all {
                try? FileManager.default.removeItem(at: file)
            } else if let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
               now.timeIntervalSince(date) > 900 {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    public func addItem(_ url: URL) {
        guard !items.contains(where: { $0.url == url }) else { return }
        let item = ShelfItem(url: url)
        items.insert(item, at: 0)
        FeedbackManager.playDrop()
        
        // Context-aware auto tool preselection
        if items.count > 1 {
            selectedTool = .merge
        } else if item.isPDF {
            selectedTool = .compress
        } else if item.isImage {
            selectedTool = .enhance
        }
    }

    public func removeItem(id: UUID) {
        items.removeAll(where: { $0.id == id })
        FeedbackManager.playDelete()
        if items.isEmpty {
            statusMessage = nil
        }
    }
    
    public func clearAll() {
        items.removeAll()
        statusMessage = nil
        FeedbackManager.playDelete()
        cleanStaleTempFiles(all: true)
    }
    
    // Manual File Selection via Finder (NSOpenPanel)
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
            if response == .OK {
                DispatchQueue.main.async {
                    for url in panel.urls {
                        self?.addItem(url)
                    }
                    FeedbackManager.playDrop()
                }
            }
        }
    }
    
    // Multi-PDF Drag Reordering
    public func moveItem(from sourceId: UUID, to targetId: UUID) {
        guard sourceId != targetId,
              let srcIdx = items.firstIndex(where: { $0.id == sourceId }),
              let dstIdx = items.firstIndex(where: { $0.id == targetId }) else { return }
        
        withAnimation(.spring(response: DesignSystem.springResponse, dampingFraction: DesignSystem.springDamping)) {
            let moved = items.remove(at: srcIdx)
            items.insert(moved, at: dstIdx)
            FeedbackManager.playHover()
        }
    }

    public func moveItemOffset(id: UUID, direction: Int) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let newIdx = idx + direction
        guard newIdx >= 0 && newIdx < items.count else { return }
        withAnimation(.spring(response: DesignSystem.springResponse, dampingFraction: DesignSystem.springDamping)) {
            let item = items.remove(at: idx)
            items.insert(item, at: newIdx)
            FeedbackManager.playClick()
        }
    }

    // Export URL generation with user-renamed file name
    public func exportURL(for doc: ResultantPDF) -> URL {
        var cleanName = doc.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.isEmpty { cleanName = "Resultant_Document.pdf" }
        if !cleanName.lowercased().hasSuffix(".pdf") { cleanName += ".pdf" }
        
        let targetURL = tempCacheDirectory.appendingPathComponent(cleanName)
        if targetURL != doc.fileURL {
            try? FileManager.default.removeItem(at: targetURL)
            try? FileManager.default.copyItem(at: doc.fileURL, to: targetURL)
            return targetURL
        }
        return doc.fileURL
    }
    
    // MARK: - 1. Merge & Combine
    public func mergeDocuments() {
        guard !items.isEmpty else {
            statusMessage = "Please add at least 2 files to merge."
            return
        }
        
        isProcessing = true
        processingStage = "Merging documents..."
        FeedbackManager.playProcess()
        
        let masterDoc = PDFDocument()
        let sources = items // Merges in tray order!
        
        for item in sources {
            let url = item.url
            if item.isPDF {
                if let doc = PDFDocument(url: url), doc.pageCount > 0 {
                    for pageIdx in 0..<doc.pageCount {
                        if let page = doc.page(at: pageIdx) {
                            masterDoc.insert(page, at: masterDoc.pageCount)
                        }
                    }
                }
            } else if item.isImage {
                if let img = NSImage(contentsOf: url), let page = PDFPage(image: img) {
                    masterDoc.insert(page, at: masterDoc.pageCount)
                }
            } else if item.isTextOrDoc {
                if let textDoc = createPDFFromTextOrDoc(url: url) {
                    for pageIdx in 0..<textDoc.pageCount {
                        if let page = textDoc.page(at: pageIdx) {
                            masterDoc.insert(page, at: masterDoc.pageCount)
                        }
                    }
                }
            }
        }
        
        isProcessing = false
        
        guard masterDoc.pageCount > 0 else {
            statusMessage = "Could not convert or merge the selected files."
            return
        }
        
        let defaultName = "Merged_Document.pdf"
        let outputURL = tempCacheDirectory.appendingPathComponent(defaultName)
        try? FileManager.default.removeItem(at: outputURL)
        
        guard masterDoc.write(to: outputURL) else {
            statusMessage = "Failed to write merged PDF to cache."
            return
        }
        
        let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let byteCount = (attrs?[.size] as? Int64) ?? 0
        let thumbnail = renderPageThumbnail(page: masterDoc.page(at: 0))
        
        let result = ResultantPDF(
            fileURL: outputURL,
            fileName: defaultName,
            pageCount: masterDoc.pageCount,
            byteCount: byteCount,
            summary: "Merged \(sources.count) files into \(masterDoc.pageCount) pages",
            tool: .merge,
            thumbnailData: thumbnail
        )
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.resultantDocument = result
            self.leftStageMode = .preview
        }
        
        statusMessage = "Merged \(sources.count) files (\(masterDoc.pageCount) pgs) ready!"
        FeedbackManager.playSuccess()
    }
    
    // MARK: - 2. Compress PDF
    public func compressPDF(targetURL: URL? = nil, customName: String? = nil) {
        let sourceURL: URL
        let defaultBaseName: String
        
        if let targetURL = targetURL {
            sourceURL = targetURL
            defaultBaseName = (targetURL.lastPathComponent as NSString).deletingPathExtension
        } else if let result = resultantDocument {
            sourceURL = result.fileURL
            defaultBaseName = (result.fileName as NSString).deletingPathExtension
        } else if let target = items.first(where: { $0.isPDF }) ?? items.first {
            sourceURL = target.url
            defaultBaseName = (target.name as NSString).deletingPathExtension
        } else {
            statusMessage = "Please drop a PDF to compress."
            return
        }
        
        isProcessing = true
        processingStage = "Compressing PDF streams..."
        FeedbackManager.playProcess()
        
        let originalAttrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let originalBytes = (originalAttrs?[.size] as? Int64) ?? 0
        
        guard let inputDoc = PDFDocument(url: sourceURL), inputDoc.pageCount > 0 else {
            isProcessing = false
            statusMessage = "Unable to read file as PDF."
            return
        }
        
        let compressedDoc = PDFDocument()
        for index in 0..<inputDoc.pageCount {
            autoreleasepool {
                guard let page = inputDoc.page(at: index) else { return }
                let box = page.bounds(for: .mediaBox)
                
                // Balanced downsampling (scale 1.25 for crisp text at 50% storage)
                let scale: CGFloat = 1.25
                let targetSize = NSSize(width: max(80, box.width * scale), height: max(80, box.height * scale))
                let image = NSImage(size: targetSize, flipped: false) { rect in
                    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
                    ctx.setFillColor(NSColor.white.cgColor)
                    ctx.fill(rect)
                    ctx.saveGState()
                    ctx.scaleBy(x: scale, y: scale)
                    page.draw(with: .mediaBox, to: ctx)
                    ctx.restoreGState()
                    return true
                }
                
                if let tiff = image.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.52]),
                   let compressedImg = NSImage(data: jpegData),
                   let compressedPage = PDFPage(image: compressedImg) {
                    compressedDoc.insert(compressedPage, at: compressedDoc.pageCount)
                } else {
                    compressedDoc.insert(page, at: compressedDoc.pageCount)
                }
            }
        }
        
        isProcessing = false
        
        let outputName = "\(defaultBaseName)_Compressed.pdf"
        let outputURL = tempCacheDirectory.appendingPathComponent(outputName)
        try? FileManager.default.removeItem(at: outputURL)
        
        // Write compressed
        guard compressedDoc.write(to: outputURL) else {
            statusMessage = "Failed to write compressed PDF."
            return
        }
        
        let newAttrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let newBytes = (newAttrs?[.size] as? Int64) ?? 0
        
        // If compressed was somehow larger (e.g. tiny 4KB text PDF), fallback to copy
        let finalURL: URL
        let finalBytes: Int64
        if originalBytes > 0 && newBytes >= originalBytes {
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.copyItem(at: sourceURL, to: outputURL)
            finalURL = outputURL
            finalBytes = originalBytes
        } else {
            finalURL = outputURL
            finalBytes = newBytes
        }
        
        let oldStr = ShelfModule.byteFormatter.string(fromByteCount: originalBytes)
        let newStr = ShelfModule.byteFormatter.string(fromByteCount: finalBytes)
        let reduction = originalBytes > finalBytes ? Int((Double(originalBytes - finalBytes) / Double(max(1, originalBytes))) * 100) : 0
        
        let thumbnail = renderPageThumbnail(page: compressedDoc.page(at: 0))
        let result = ResultantPDF(
            fileURL: finalURL,
            fileName: outputName,
            pageCount: inputDoc.pageCount,
            byteCount: finalBytes,
            summary: reduction > 0 ? "Compressed: -\(reduction)% (\(oldStr) → \(newStr))" : "Stream optimized: \(newStr)",
            tool: .compress,
            thumbnailData: thumbnail
        )
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.resultantDocument = result
            self.leftStageMode = .preview
        }
        
        statusMessage = result.summary
        FeedbackManager.playSuccess()
    }
    
    // MARK: - 3. Convert to PDF
    public func convertToPDF() {
        guard let target = items.first else {
            statusMessage = "Please drop an image or document to convert."
            return
        }
        
        isProcessing = true
        processingStage = "Converting to PDF..."
        FeedbackManager.playProcess()
        
        let url = target.url
        let outputDoc = PDFDocument()
        
        if target.isImage {
            if let img = NSImage(contentsOf: url), let page = PDFPage(image: img) {
                outputDoc.insert(page, at: 0)
            }
        } else if target.isTextOrDoc {
            if let textDoc = createPDFFromTextOrDoc(url: url) {
                for i in 0..<textDoc.pageCount {
                    if let page = textDoc.page(at: i) {
                        outputDoc.insert(page, at: outputDoc.pageCount)
                    }
                }
            }
        } else if target.isPDF {
            isProcessing = false
            statusMessage = "\(target.name) is already a PDF."
            return
        }
        
        isProcessing = false
        
        guard outputDoc.pageCount > 0 else {
            statusMessage = "Could not convert \(target.name) to PDF."
            return
        }
        
        let base = (target.name as NSString).deletingPathExtension
        let outputName = "\(base).pdf"
        let outputURL = tempCacheDirectory.appendingPathComponent(outputName)
        try? FileManager.default.removeItem(at: outputURL)
        
        guard outputDoc.write(to: outputURL) else {
            statusMessage = "Failed to write converted PDF."
            return
        }
        
        let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let byteCount = (attrs?[.size] as? Int64) ?? 0
        let thumbnail = renderPageThumbnail(page: outputDoc.page(at: 0))
        
        let result = ResultantPDF(
            fileURL: outputURL,
            fileName: outputName,
            pageCount: outputDoc.pageCount,
            byteCount: byteCount,
            summary: "Converted \(target.name) into PDF (\(outputDoc.pageCount) pgs)",
            tool: .convert,
            thumbnailData: thumbnail
        )
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.resultantDocument = result
            self.leftStageMode = .preview
        }
        
        statusMessage = "Converted \(target.name) successfully!"
        FeedbackManager.playSuccess()
    }
    
    // MARK: - 4. Enhance Scans
    public func enhanceDocument() {
        let sourceURL: URL
        let baseName: String
        
        if let result = resultantDocument {
            sourceURL = result.fileURL
            baseName = (result.fileName as NSString).deletingPathExtension
        } else if let target = items.first {
            sourceURL = target.url
            baseName = (target.name as NSString).deletingPathExtension
        } else {
            statusMessage = "Please drop a document or scan to enhance."
            return
        }
        
        isProcessing = true
        processingStage = "Enhancing clarity & contrast..."
        FeedbackManager.playProcess()
        
        let enhancedDoc = PDFDocument()
        let ciContext = CIContext(options: nil)
        
        let isPdf = sourceURL.pathExtension.lowercased() == "pdf"
        if isPdf {
            if let inputDoc = PDFDocument(url: sourceURL) {
                for i in 0..<inputDoc.pageCount {
                    autoreleasepool {
                        guard let page = inputDoc.page(at: i) else { return }
                        let box = page.bounds(for: .mediaBox)
                        let image = NSImage(size: box.size, flipped: false) { rect in
                            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
                            ctx.setFillColor(NSColor.white.cgColor)
                            ctx.fill(rect)
                            page.draw(with: .mediaBox, to: ctx)
                            return true
                        }
                        
                        if let enhanced = enhanceImage(image, ciContext: ciContext),
                           let enhancedPage = PDFPage(image: enhanced) {
                            enhancedDoc.insert(enhancedPage, at: enhancedDoc.pageCount)
                        } else {
                            enhancedDoc.insert(page, at: enhancedDoc.pageCount)
                        }
                    }
                }
            }
        } else {
            if let img = NSImage(contentsOf: sourceURL),
               let enhanced = enhanceImage(img, ciContext: ciContext),
               let page = PDFPage(image: enhanced) {
                enhancedDoc.insert(page, at: 0)
            }
        }
        
        isProcessing = false
        
        guard enhancedDoc.pageCount > 0 else {
            statusMessage = "Could not enhance document."
            return
        }
        
        let outputName = "\(baseName)_Enhanced.pdf"
        let outputURL = tempCacheDirectory.appendingPathComponent(outputName)
        try? FileManager.default.removeItem(at: outputURL)
        
        guard enhancedDoc.write(to: outputURL) else {
            statusMessage = "Failed to write enhanced PDF."
            return
        }
        
        let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let byteCount = (attrs?[.size] as? Int64) ?? 0
        let thumbnail = renderPageThumbnail(page: enhancedDoc.page(at: 0))
        
        let result = ResultantPDF(
            fileURL: outputURL,
            fileName: outputName,
            pageCount: enhancedDoc.pageCount,
            byteCount: byteCount,
            summary: "Enhanced contrast, sharpening & noise suppression",
            tool: .enhance,
            thumbnailData: thumbnail
        )
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.resultantDocument = result
            self.leftStageMode = .preview
        }
        
        statusMessage = "Enhanced document clarity & contrast!"
        FeedbackManager.playSuccess()
    }
    
    // Save Resultant PDF to Custom Location via NSSavePanel
    public func saveResultantToDisk() {
        guard let result = resultantDocument else { return }
        FeedbackManager.playClick()
        
        let panel = NSSavePanel()
        panel.title = "Save Processed Document"
        var safeName = result.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !safeName.lowercased().hasSuffix(".pdf") { safeName += ".pdf" }
        panel.nameFieldStringValue = safeName
        panel.allowedContentTypes = [.pdf]
        
        if panel.runModal() == .OK, let destination = panel.url {
            try? FileManager.default.removeItem(at: destination)
            if (try? FileManager.default.copyItem(at: result.fileURL, to: destination)) != nil {
                addItem(destination)
                statusMessage = "Saved to \(destination.lastPathComponent)!"
                FeedbackManager.playSuccess()
            } else {
                statusMessage = "Failed to save file to chosen location."
            }
        }
    }

    // Share Resultant PDF via AirDrop
    public func shareResultantViaAirDrop() {
        guard let result = resultantDocument else { return }
        let export = exportURL(for: result)
        shareAirDropDirectly(urls: [export])
    }
    
    // Chain Resultant: Add result back to tray to perform further actions
    public func addResultantToTray() {
        guard let result = resultantDocument else { return }
        let export = exportURL(for: result)
        addItem(export)
        statusMessage = "Added \(export.lastPathComponent) to staging tray"
        FeedbackManager.playDrop()
    }

    // Clear Preview and return to normal Tools Wheel mode
    public func clearPreview() {
        if let doc = resultantDocument, doc.fileURL.path.contains("NotchifyStudio") {
            try? FileManager.default.removeItem(at: doc.fileURL)
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.resultantDocument = nil
            self.leftStageMode = .wheel
            self.statusMessage = nil
        }
        FeedbackManager.playClick()
    }

    private func renderPageThumbnail(page: PDFPage?) -> Data? {
        guard let page = page else { return nil }
        let box = page.bounds(for: .mediaBox)
        let targetWidth: CGFloat = 160.0
        let scale = targetWidth / max(1, box.width)
        let targetHeight = max(80, box.height * scale)
        let targetSize = NSSize(width: targetWidth, height: targetHeight)
        
        let thumb = page.thumbnail(of: targetSize, for: .mediaBox)
        var proposedRect = CGRect(origin: .zero, size: targetSize)
        if let cg = thumb.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cg)
            return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        }
        if let tiff = thumb.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        }
        return nil
    }

    private func enhanceImage(_ image: NSImage, ciContext: CIContext) -> NSImage? {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        let ciImage: CIImage
        if let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            ciImage = CIImage(cgImage: cgImage)
        } else if let tiffData = image.tiffRepresentation, let ci = CIImage(data: tiffData) {
            ciImage = ci
        } else {
            return nil
        }
        
        let colorFilter = CIFilter(name: "CIColorControls")
        colorFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        colorFilter?.setValue(1.40, forKey: kCIInputContrastKey)
        colorFilter?.setValue(0.05, forKey: kCIInputBrightnessKey)
        colorFilter?.setValue(0.08, forKey: kCIInputSaturationKey)
        
        guard let filtered = colorFilter?.outputImage else { return image }
        
        let sharpenFilter = CIFilter(name: "CISharpenLuminance")
        sharpenFilter?.setValue(filtered, forKey: kCIInputImageKey)
        sharpenFilter?.setValue(0.85, forKey: kCIInputSharpnessKey)
        
        guard let finalCI = sharpenFilter?.outputImage,
              let cgImage = ciContext.createCGImage(finalCI, from: finalCI.extent) else { return image }
        
        return NSImage(cgImage: cgImage, size: image.size)
    }
    
    private func createPDFFromTextOrDoc(url: URL) -> PDFDocument? {
        if let attrString = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
            let textRect = pageRect.insetBy(dx: 48, dy: 48)
            let textView = NSTextView(frame: textRect)
            textView.textStorage?.setAttributedString(attrString)
            let pdfData = textView.dataWithPDF(inside: textRect)
            return PDFDocument(data: pdfData)
        } else if let plainText = try? String(contentsOf: url, encoding: .utf8) {
            let attrString = NSAttributedString(
                string: plainText,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.black
                ]
            )
            let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
            let textRect = pageRect.insetBy(dx: 48, dy: 48)
            let textView = NSTextView(frame: textRect)
            textView.textStorage?.setAttributedString(attrString)
            let pdfData = textView.dataWithPDF(inside: textRect)
            return PDFDocument(data: pdfData)
        }
        return nil
    }

    // MARK: - 5. AirDrop Express
    public func shareAirDrop(for item: ShelfItem) {
        shareAirDropDirectly(urls: [item.url])
    }
    
    public func shareAllAirDrop() {
        let urls = items.map(\.url)
        guard !urls.isEmpty else {
            statusMessage = "No files in tray to AirDrop."
            return
        }
        shareAirDropDirectly(urls: urls)
    }

    public func shareAirDropDirectly(urls: [URL]) {
        guard !urls.isEmpty else { return }
        AirDropModule.shared.shareFiles(urls)
        statusMessage = "AirDropping \(urls.count) file(s)..."
    }

    public func makeCompactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: "airdrop")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.accentColor)
                Text("\(items.count) files")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white)
            }
        )
    }
    
    public func makeExpandedView() -> AnyView {
        AnyView(
            ShelfModuleExpandedView(module: self)
        )
    }
}

// MARK: - Expanded View with Interactive Wheel, Resultant Preview Stage & Draggable Staging
public struct ShelfModuleExpandedView: View {
    @ObservedObject var module: ShelfModule
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var body: some View {
        VStack(spacing: 10) {
            // Header Bar with Breadcrumb and Clear All
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.badge.gearshape.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignSystem.accentColor)
                    
                    Text("File Studio")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                    
                    Text(module.selectedTool.title)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.accentColor)
                    
                    Text("(\(module.items.count) in tray)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                Spacer()
                
                // Left Column View Mode Toggle (Wheel Dial vs Result Preview)
                if module.resultantDocument != nil {
                    HStack(spacing: 3) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                module.leftStageMode = .wheel
                            }
                            FeedbackManager.playClick()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "circle.circle")
                                    .font(.system(size: 9))
                                Text("Tools")
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                Capsule()
                                    .fill(module.leftStageMode == .wheel ? DesignSystem.structureColor : Color.clear)
                            )
                            .foregroundColor(module.leftStageMode == .wheel ? .white : DesignSystem.secondaryText)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                module.leftStageMode = .preview
                            }
                            FeedbackManager.playClick()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text.image.fill")
                                    .font(.system(size: 9))
                                Text("Preview")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                Capsule()
                                    .fill(module.leftStageMode == .preview ? DesignSystem.accentColor : Color.clear)
                            )
                            .foregroundColor(module.leftStageMode == .preview ? .black : DesignSystem.secondaryText)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            module.clearPreview()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                Text("Clear")
                                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3.5)
                            .foregroundColor(Color.white.opacity(0.65))
                        }
                        .buttonStyle(.plain)
                        .help("Clear preview and reset to tools wheel")
                    }
                    .padding(2)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .padding(.trailing, 4)
                }
                
                // Manual Upload Button (Select files from Finder)
                Button(action: module.chooseFilesFromFinder) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Add Files")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(DesignSystem.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignSystem.accentColor.opacity(0.15)))
                    .overlay(Capsule().strokeBorder(DesignSystem.accentColor.opacity(0.35), lineWidth: 0.8))
                }
                .buttonStyle(.spring)
                .help("Select files manually from Finder (PDFs, images, documents)")

                if !module.items.isEmpty {
                    Button(action: module.clearAll) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                            Text("Clear")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(Color.white.opacity(0.65))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.spring)
                }
            }
            .padding(.horizontal, 2)
            
            // Main Two-Column Stage
            HStack(alignment: .top, spacing: 14) {
                // Left Column: Interactive Jog Wheel OR Resultant PDF Preview Card
                ZStack {
                    if module.leftStageMode == .preview, let doc = module.resultantDocument {
                        ResultantPDFPreviewCard(module: module, doc: doc)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .opacity
                            ))
                    } else {
                        VStack(spacing: 6) {
                            InteractiveStudioWheel(module: module)
                                .frame(width: 140, height: 140)
                            
                            Text("Dial / tap to select")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundColor(DesignSystem.secondaryText)
                        }
                        .frame(width: 140)
                        .transition(.opacity)
                    }
                }
                .frame(width: 154)
                
                // Right Column: Active Tool Action Card & File Tray
                VStack(alignment: .leading, spacing: 8) {
                    // Tool Details & Primary Action Trigger
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(module.selectedTool.title)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text(module.selectedTool.subtitle)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(DesignSystem.secondaryText)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            // Dedicated Direct AirDrop Capsule Drop Target
                            AirDropDropTargetCapsule(module: module)
                        }
                        
                        // Action Trigger Button & Secondary Quick Actions
                        HStack(spacing: 8) {
                            Button(action: executeActiveTool) {
                                HStack(spacing: 6) {
                                    if module.isProcessing {
                                        ProgressView()
                                            .controlSize(.small)
                                            .colorInvert()
                                    } else {
                                        Image(systemName: module.selectedTool.icon)
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    
                                    Text(module.isProcessing ? module.processingStage : module.selectedTool.actionTitle)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.accentColor)
                                )
                                .shadow(color: DesignSystem.accentColor.opacity(0.3), radius: 6, x: 0, y: 2)
                            }
                            .buttonStyle(.spring)
                            .disabled(module.isProcessing || !canRunActiveTool)
                            .opacity(canRunActiveTool ? 1.0 : 0.45)
                            
                            // Explicit AirDrop Action with Logo
                            Button {
                                module.shareAllAirDrop()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "airdrop")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("AirDrop")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                            }
                            .buttonStyle(.spring)
                            .disabled(module.items.isEmpty)
                            .opacity(module.items.isEmpty ? 0.4 : 1.0)
                            .help("Beam all staged files via AirDrop")
                            
                            if let status = module.statusMessage {
                                Text(status)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundColor(DesignSystem.accentColor)
                                    .lineLimit(1)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.top, 2)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DesignSystem.structureColor.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                    )
                    
                    // Staged Files Tray / Reorderable General Drop Target
                    stagedFilesTray
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var canRunActiveTool: Bool {
        switch module.selectedTool {
        case .merge:
            return module.items.count > 1 || (module.items.count == 1 && module.items[0].isPDF)
        case .compress:
            return module.items.contains(where: { $0.isPDF }) || module.resultantDocument != nil
        case .convert:
            return module.items.contains(where: { $0.isImage || $0.isTextOrDoc })
        case .enhance:
            return module.items.contains(where: { $0.isPDF || $0.isImage }) || module.resultantDocument != nil
        case .airdrop:
            return !module.items.isEmpty
        }
    }
    
    private func executeActiveTool() {
        FeedbackManager.playClick()
        switch module.selectedTool {
        case .merge:
            module.mergeDocuments()
        case .compress:
            module.compressPDF()
        case .convert:
            module.convertToPDF()
        case .enhance:
            module.enhanceDocument()
        case .airdrop:
            module.shareAllAirDrop()
        }
    }
    
    // Reorderable Staged Files Horizontal Tray
    private var stagedFilesTray: some View {
        Group {
            if module.items.isEmpty {
                // Empty State Drop Box
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.accentColor.opacity(0.15))
                            .frame(width: 26, height: 26)
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Drop PDFs, images, or docs here")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Drag files or choose manually from Finder")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                    Spacer()
                    
                    Button(action: module.chooseFilesFromFinder) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 9))
                            Text("Browse")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(Capsule().fill(DesignSystem.structureColor))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8))
                    }
                    .buttonStyle(.spring)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(module.isTrayHovered ? DesignSystem.accentColor.opacity(0.12) : Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            module.isTrayHovered ? DesignSystem.accentColor : Color.white.opacity(0.1),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                )
                .onDrop(of: [.fileURL, .item, .data, .content], isTargeted: $module.isTrayHovered) { providers in
                    let valid = providers.filter { $0.canLoadObject(ofClass: URL.self) }
                    guard !valid.isEmpty else { return false }
                    for p in valid {
                        _ = p.loadObject(ofClass: URL.self) { url, _ in
                            guard let url else { return }
                            DispatchQueue.main.async { module.addItem(url) }
                        }
                    }
                    return true
                }
            } else {
                // Horizontally Scrollable Staged Files with Drag-to-Reorder
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(module.items.enumerated()), id: \.element.id) { index, item in
                            StagedFileChip(module: module, item: item, index: index, total: module.items.count)
                        }
                        
                        // Add More Files Button
                        Button(action: module.chooseFilesFromFinder) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 8.5, weight: .bold))
                                Text("Add")
                                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(Color.white.opacity(0.75))
                            .padding(.horizontal, 8)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                            )
                        }
                        .buttonStyle(.spring)
                        .help("Add more files from Finder")
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 42)
            }
        }
    }
}

// MARK: - Resultant PDF Live Preview Card (Left Side Stage)
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
            // Document Page 1 Thumbnail with Drag-Out Ability & Top-Right Clear Button
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottom) {
                    if let thumbData = doc.thumbnailData, let nsImage = NSImage(data: thumbData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 86)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 140, height: 86)
                            .overlay(
                                Image(systemName: "doc.richtext.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(DesignSystem.accentColor)
                            )
                    }
                    
                    // Page count & Size Badges
                    HStack(spacing: 4) {
                        Text("\(doc.pageCount) pgs")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(DesignSystem.accentColor))
                        
                        Text(doc.formattedSize)
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.7)))
                    }
                    .padding(4)
                }
                
                // Clear Preview Floating Button in Thumbnail Top-Right
                Button(action: module.clearPreview) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.75))
                            .frame(width: 18, height: 18)
                        Image(systemName: "xmark")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.9))
                    }
                }
                .buttonStyle(.spring)
                .padding(4)
                .help("Clear preview and return to normal tools wheel")
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(uiState.isHovered ? DesignSystem.accentColor : Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(uiState.isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: uiState.isHovered)
            .onHover { uiState.isHovered = $0 }
            // CRITICAL: Draggable out! Drag straight to Finder, Slack, browser, etc.
            .onDrag {
                FeedbackManager.playHover()
                let finalURL = module.exportURL(for: doc)
                return NSItemProvider(contentsOf: finalURL) ?? NSItemProvider()
            }
            .help("Drag preview directly to Finder, Mail, browser or AirDrop!")
            
            // Inline Rename Text Box before downloading
            HStack(spacing: 3) {
                Image(systemName: "pencil")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.4))
                
                TextField("Document Name", text: $module.resultantFileName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
            
            // Action Buttons: Save As, AirDrop & Clear Preview
            HStack(spacing: 4) {
                // Download / Save As Button
                Button {
                    module.saveResultantToDisk()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 7.5))
                        Text("Save...")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignSystem.accentColor))
                }
                .buttonStyle(.spring)
                .help("Save to any folder on your Mac")
                
                // AirDrop Logo Action Button
                Button {
                    module.shareResultantViaAirDrop()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "airdrop")
                            .font(.system(size: 7.5))
                        Text("AirDrop")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.spring)
                .help("AirDrop directly to iPhone, iPad or Mac")
                
                // Explicit Clear Preview Button
                Button {
                    module.clearPreview()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "trash")
                            .font(.system(size: 7.5))
                        Text("Clear")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Color.white.opacity(0.75))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.spring)
                .help("Clear preview and reset to tools wheel")
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignSystem.structureColor.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
        )
    }
}

// MARK: - Reorderable Staged File Chip
public struct StagedFileChip: View {
    @ObservedObject var module: ShelfModule
    let item: ShelfItem
    let index: Int
    let total: Int
    @StateObject private var uiState = LocalUIState()
    
    public var body: some View {
        HStack(spacing: 5) {
            // Drag handle / File Icon
            Image(systemName: fileIcon(for: item))
                .font(.system(size: 9.5))
                .foregroundColor(DesignSystem.accentColor)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 80, alignment: .leading)
                
                Text(item.size)
                    .font(.system(size: 7.5))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            
            // Reordering arrow triggers on hover
            if uiState.isHovered && total > 1 {
                HStack(spacing: 2) {
                    if index > 0 {
                        Button {
                            module.moveItemOffset(id: item.id, direction: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if index < total - 1 {
                        Button {
                            module.moveItemOffset(id: item.id, direction: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Direct AirDrop single file
            Button(action: { module.shareAirDrop(for: item) }) {
                Image(systemName: "airdrop")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.75))
            }
            .buttonStyle(.spring)
            .help("AirDrop \(item.name)")
            
            // Remove file
            Button(action: { module.removeItem(id: item.id) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 8.5))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .buttonStyle(.spring)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(DesignSystem.structureColor)
        )
        .overlay(
            Capsule()
                .strokeBorder(uiState.isHovered ? DesignSystem.accentColor.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 0.8)
        )
        .onHover { uiState.isHovered = $0 }
        // Drag to reorder
        .onDrag {
            FeedbackManager.playHover()
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: StagedFileDropDelegate(item: item, module: module))
    }
    
    private func fileIcon(for item: ShelfItem) -> String {
        if item.isPDF { return "doc.richtext.fill" }
        if item.isImage { return "photo.fill" }
        if item.isTextOrDoc { return "doc.text.fill" }
        return "doc.fill"
    }
}

// Drag & Drop Delegate for Staged File Reordering
public struct StagedFileDropDelegate: DropDelegate {
    let item: ShelfItem
    let module: ShelfModule
    
    public init(item: ShelfItem, module: ShelfModule) {
        self.item = item
        self.module = module
    }
    
    public func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    public func dropEntered(info: DropInfo) {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return }
        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (val, error) in
            var foundIdStr: String? = nil
            if let data = val as? Data {
                foundIdStr = String(data: data, encoding: .utf8)
            } else if let str = val as? String {
                foundIdStr = str
            }
            if let idStr = foundIdStr, let sourceUUID = UUID(uuidString: idStr), sourceUUID != self.item.id {
                DispatchQueue.main.async {
                    self.module.moveItem(from: sourceUUID, to: self.item.id)
                }
            }
        }
    }
}

// MARK: - Direct AirDrop Drop Target Capsule
private struct AirDropDropTargetCapsule: View {
    @ObservedObject var module: ShelfModule
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "airdrop")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(module.isAirDropHovered ? .black : DesignSystem.accentColor)
            
            Text(module.isAirDropHovered ? "Release to AirDrop" : "Drop to AirDrop")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(module.isAirDropHovered ? .black : .white.opacity(0.85))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(module.isAirDropHovered ? DesignSystem.accentColor : Color.white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .strokeBorder(module.isAirDropHovered ? Color.white : DesignSystem.accentColor.opacity(0.5), lineWidth: 1)
        )
        .scaleEffect(module.isAirDropHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: module.isAirDropHovered)
        .onDrop(of: [.fileURL, .item, .data, .content], isTargeted: $module.isAirDropHovered) { providers in
            var handled = false
            for p in providers {
                if p.canLoadObject(ofClass: URL.self) {
                    handled = true
                    _ = p.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        DispatchQueue.main.async {
                            module.addItem(url)
                            module.shareAirDropDirectly(urls: [url])
                        }
                    }
                } else if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    handled = true
                    p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                        guard let url else { return }
                        DispatchQueue.main.async {
                            module.addItem(url)
                            module.shareAirDropDirectly(urls: [url])
                        }
                    }
                }
            }
            return handled
        }
    }
}

// MARK: - Interactive Radial Studio Wheel Component
public struct InteractiveStudioWheel: View {
    @ObservedObject var module: ShelfModule
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let tools = FileStudioTool.allCases
    private let dialRadius: CGFloat = 46.0
    
    public var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            
            ZStack {
                // Outer Subtle Concentric Guide Ring with Ticks
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                DesignSystem.accentColor.opacity(0.35),
                                Color.white.opacity(0.08),
                                DesignSystem.accentColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: dialRadius * 2 + 32, height: dialRadius * 2 + 32)
                    .position(center)
                
                // Outer Subtle Dial Ticks (Every 30 degrees)
                ForEach(0..<12, id: \.self) { tick in
                    let angle = Double(tick) * (2 * .pi / 12)
                    Circle()
                        .fill(Color.white.opacity(tick % 3 == 0 ? 0.35 : 0.15))
                        .frame(width: tick % 3 == 0 ? 3 : 1.5, height: tick % 3 == 0 ? 3 : 1.5)
                        .position(
                            x: center.x + (dialRadius + 16) * CGFloat(cos(angle)),
                            y: center.y + (dialRadius + 16) * CGFloat(sin(angle))
                        )
                }
                
                // Tool Nodes Positioned Around Circumference
                ForEach(Array(tools.enumerated()), id: \.element.rawValue) { idx, tool in
                    let isSelected = module.selectedTool == tool
                    let baseAngle = Double(idx) * (2 * .pi / Double(tools.count)) - (.pi / 2)
                    let currentAngle = baseAngle + module.wheelRotationAngle
                    let x = center.x + dialRadius * CGFloat(cos(currentAngle))
                    let y = center.y + dialRadius * CGFloat(sin(currentAngle))
                    
                    Button {
                        FeedbackManager.playHover()
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                            module.selectedTool = tool
                            // Smoothly align chosen tool to top
                            let targetRot = -Double(idx) * (2 * .pi / Double(tools.count))
                            module.wheelRotationAngle = targetRot
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isSelected ? DesignSystem.accentColor : DesignSystem.structureColor)
                                .frame(width: isSelected ? 34 : 28, height: isSelected ? 34 : 28)
                            
                            Image(systemName: tool.icon)
                                .font(.system(size: isSelected ? 12 : 10, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .black : Color.white.opacity(0.85))
                        }
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isSelected ? Color.white.opacity(0.8) : Color.white.opacity(0.12),
                                    lineWidth: isSelected ? 1.5 : 0.8
                                )
                        )
                        .scaleEffect(isSelected ? 1.12 : 1.0)
                        .shadow(color: isSelected ? DesignSystem.accentColor.opacity(0.4) : Color.clear, radius: 6, x: 0, y: 0)
                    }
                    .buttonStyle(.spring(scale: 0.94))
                    .position(x: x, y: y)
                    .help(tool.title)
                }
                
                // Center Hub: Shows Active Tool Icon + Subtle Pulse
                ZStack {
                    Circle()
                        .fill(DesignSystem.cardFill)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .strokeBorder(DesignSystem.accentColor.opacity(0.4), lineWidth: 1)
                        )
                    
                    Image(systemName: module.selectedTool.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DesignSystem.accentColor)
                        .contentTransition(.symbolEffect(.replace))
                }
                .position(center)
                .onTapGesture {
                    FeedbackManager.playClick()
                    // Cycle to next tool on center tap
                    if let curIdx = tools.firstIndex(of: module.selectedTool) {
                        let nextIdx = (curIdx + 1) % tools.count
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                            module.selectedTool = tools[nextIdx]
                            module.wheelRotationAngle = -Double(nextIdx) * (2 * .pi / Double(tools.count))
                        }
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let angle = atan2(dy, dx)
                        module.wheelRotationAngle = angle
                    }
                    .onEnded { _ in
                        // Snap to nearest tool
                        let count = Double(tools.count)
                        let step = (2 * .pi) / count
                        let normalized = module.wheelRotationAngle.truncatingRemainder(dividingBy: 2 * .pi)
                        let nearestIdx = Int(round(-normalized / step)) % tools.count
                        let cleanIdx = nearestIdx < 0 ? (nearestIdx + tools.count) : nearestIdx
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                            module.selectedTool = tools[cleanIdx]
                            module.wheelRotationAngle = -Double(cleanIdx) * step
                        }
                        FeedbackManager.playHover()
                    }
            )
        }
    }
}
