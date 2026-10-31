import SwiftUI
import UniformTypeIdentifiers
import AppKit
import PDFKit
import CoreImage

public enum FileStudioTool: String, CaseIterable, Identifiable {
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
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            self.size = formatter.string(fromByteCount: fileSize)
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

@MainActor
public final class ShelfModule: NotchModule {
    public static let shared = ShelfModule()
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
    
    // Direct drop hover states
    @Published public var isAirDropHovered: Bool = false
    @Published public var isTrayHovered: Bool = false
    
    public init() {}
    
    public func start() {}
    public func stop() {}
    
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
        let sources = items
        
        for item in sources.reversed() {
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
        
        let panel = NSSavePanel()
        panel.title = "Save Merged PDF"
        panel.nameFieldStringValue = "Merged_Document.pdf"
        panel.allowedContentTypes = [.pdf]
        
        if panel.runModal() == .OK, let destination = panel.url {
            if masterDoc.write(to: destination) {
                addItem(destination)
                statusMessage = "Merged \(sources.count) files into \(masterDoc.pageCount) pages!"
                FeedbackManager.playSuccess()
            } else {
                statusMessage = "Failed to write merged PDF to disk."
            }
        }
    }
    
    // MARK: - 2. Compress PDF
    public func compressPDF() {
        guard let target = items.first(where: { $0.isPDF }) ?? items.first else {
            statusMessage = "Please drop a PDF to compress."
            return
        }
        
        isProcessing = true
        processingStage = "Compressing PDF streams..."
        FeedbackManager.playProcess()
        
        let url = target.url
        let originalBytes = target.byteCount
        
        guard let inputDoc = PDFDocument(url: url), inputDoc.pageCount > 0 else {
            isProcessing = false
            statusMessage = "Unable to read \(target.name) as PDF."
            return
        }
        
        let compressedDoc = PDFDocument()
        for index in 0..<inputDoc.pageCount {
            autoreleasepool {
                guard let page = inputDoc.page(at: index) else { return }
                let box = page.bounds(for: .mediaBox)
                
                // Render page at balanced 150 DPI into JPEG compressed representation
                let scale: CGFloat = 1.6
                let targetSize = NSSize(width: max(100, box.width * scale), height: max(100, box.height * scale))
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
                   let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.65]),
                   let compressedImg = NSImage(data: jpegData),
                   let compressedPage = PDFPage(image: compressedImg) {
                    compressedDoc.insert(compressedPage, at: compressedDoc.pageCount)
                } else {
                    compressedDoc.insert(page, at: compressedDoc.pageCount)
                }
            }
        }
        
        isProcessing = false
        
        let panel = NSSavePanel()
        panel.title = "Save Compressed PDF"
        let base = (target.name as NSString).deletingPathExtension
        panel.nameFieldStringValue = "\(base)_Compressed.pdf"
        panel.allowedContentTypes = [.pdf]
        
        if panel.runModal() == .OK, let destination = panel.url {
            if compressedDoc.write(to: destination) {
                let newAttrs = try? FileManager.default.attributesOfItem(atPath: destination.path)
                let newBytes = (newAttrs?[.size] as? Int64) ?? 0
                
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useAll]
                formatter.countStyle = .file
                let oldStr = formatter.string(fromByteCount: originalBytes)
                let newStr = formatter.string(fromByteCount: newBytes)
                
                let reduction = originalBytes > newBytes ? Int((Double(originalBytes - newBytes) / Double(max(1, originalBytes))) * 100) : 0
                
                addItem(destination)
                statusMessage = "Compressed: \(oldStr) → \(newStr) (-\(reduction)%)"
                FeedbackManager.playSuccess()
            } else {
                statusMessage = "Failed to save compressed PDF."
            }
        }
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
        
        let panel = NSSavePanel()
        let base = (target.name as NSString).deletingPathExtension
        panel.nameFieldStringValue = "\(base).pdf"
        panel.allowedContentTypes = [.pdf]
        
        if panel.runModal() == .OK, let destination = panel.url {
            if outputDoc.write(to: destination) {
                addItem(destination)
                statusMessage = "Converted \(target.name) to PDF!"
                FeedbackManager.playSuccess()
            } else {
                statusMessage = "Failed to write converted PDF."
            }
        }
    }
    
    // MARK: - 4. Enhance Scans
    public func enhanceDocument() {
        guard let target = items.first else {
            statusMessage = "Please drop a document or image to enhance."
            return
        }
        
        isProcessing = true
        processingStage = "Enhancing clarity & contrast..."
        FeedbackManager.playProcess()
        
        let url = target.url
        let enhancedDoc = PDFDocument()
        let ciContext = CIContext(options: nil)
        
        if target.isPDF {
            if let inputDoc = PDFDocument(url: url) {
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
        } else if target.isImage {
            if let img = NSImage(contentsOf: url),
               let enhanced = enhanceImage(img, ciContext: ciContext),
               let page = PDFPage(image: enhanced) {
                enhancedDoc.insert(page, at: 0)
            }
        }
        
        isProcessing = false
        
        guard enhancedDoc.pageCount > 0 else {
            statusMessage = "Could not enhance \(target.name)."
            return
        }
        
        let panel = NSSavePanel()
        let base = (target.name as NSString).deletingPathExtension
        panel.nameFieldStringValue = "\(base)_Enhanced.pdf"
        panel.allowedContentTypes = [.pdf]
        
        if panel.runModal() == .OK, let destination = panel.url {
            if enhancedDoc.write(to: destination) {
                addItem(destination)
                statusMessage = "Enhanced document clarity & contrast!"
                FeedbackManager.playSuccess()
            } else {
                statusMessage = "Failed to write enhanced PDF."
            }
        }
    }
    
    private func enhanceImage(_ image: NSImage, ciContext: CIContext) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return nil }
        
        let colorFilter = CIFilter(name: "CIColorControls")
        colorFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        colorFilter?.setValue(1.35, forKey: kCIInputContrastKey)
        colorFilter?.setValue(0.04, forKey: kCIInputBrightnessKey)
        colorFilter?.setValue(0.12, forKey: kCIInputSaturationKey)
        
        guard let filtered = colorFilter?.outputImage else { return image }
        
        let sharpenFilter = CIFilter(name: "CISharpenLuminance")
        sharpenFilter?.setValue(filtered, forKey: kCIInputImageKey)
        sharpenFilter?.setValue(0.80, forKey: kCIInputSharpnessKey)
        
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
        FeedbackManager.playSend()
        
        if let airDropService = NSSharingService(named: .sendViaAirDrop),
           airDropService.canPerform(withItems: urls) {
            airDropService.perform(withItems: urls)
            statusMessage = "AirDropping \(urls.count) file(s)..."
            return
        }
        
        let picker = NSSharingServicePicker(items: urls)
        if let targetView = NotchShellCoordinator.shared.panel?.contentView {
            picker.show(relativeTo: targetView.bounds, of: targetView, preferredEdge: .minY)
            statusMessage = "AirDrop picker opened for \(urls.count) file(s)."
        }
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

// MARK: - Expanded View with Interactive Wheel and Breathable Apple Layout
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
                // Left Column: Interactive Jog Wheel Selector
                VStack(spacing: 6) {
                    InteractiveStudioWheel(module: module)
                        .frame(width: 140, height: 140)
                    
                    Text("Dial / tap to select")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                .frame(width: 140)
                
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
                        
                        // Action Trigger Button
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
                    
                    // Staged Files Tray / General Drop Target
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
            return module.items.contains(where: { $0.isPDF })
        case .convert:
            return module.items.contains(where: { $0.isImage || $0.isTextOrDoc })
        case .enhance:
            return module.items.contains(where: { $0.isPDF || $0.isImage })
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
    
    // Staged Files Horizontal Tray
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
                        Text("Files stage instantly for merging, compression or conversion")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                    Spacer()
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
                .onDrop(of: [.fileURL], isTargeted: $module.isTrayHovered) { providers in
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
                // Horizontally Scrollable Staged Files
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(module.items) { item in
                            HStack(spacing: 6) {
                                Image(systemName: fileIcon(for: item))
                                    .font(.system(size: 10))
                                    .foregroundColor(DesignSystem.accentColor)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name)
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .frame(maxWidth: 90, alignment: .leading)
                                    
                                    Text(item.size)
                                        .font(.system(size: 8))
                                        .foregroundColor(DesignSystem.secondaryText)
                                }
                                
                                // Direct AirDrop single file
                                Button(action: { module.shareAirDrop(for: item) }) {
                                    Image(systemName: "airdrop")
                                        .font(.system(size: 8))
                                        .foregroundColor(Color.white.opacity(0.7))
                                }
                                .buttonStyle(.spring)
                                .help("AirDrop \(item.name)")
                                
                                // Remove file
                                Button(action: { module.removeItem(id: item.id) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(Color.white.opacity(0.35))
                                }
                                .buttonStyle(.spring)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.structureColor)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 38)
            }
        }
    }
    
    private func fileIcon(for item: ShelfItem) -> String {
        if item.isPDF { return "doc.richtext.fill" }
        if item.isImage { return "photo.fill" }
        if item.isTextOrDoc { return "doc.text.fill" }
        return "doc.fill"
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
        .onDrop(of: [.fileURL], isTargeted: $module.isAirDropHovered) { providers in
            let valid = providers.filter { $0.canLoadObject(ofClass: URL.self) }
            guard !valid.isEmpty else { return false }
            for p in valid {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async {
                        module.addItem(url)
                        module.shareAirDropDirectly(urls: [url])
                    }
                }
            }
            return true
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
