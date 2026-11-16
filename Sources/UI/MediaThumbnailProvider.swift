import SwiftUI
import AppKit
import QuickLookThumbnailing
@preconcurrency import PDFKit
import AVFoundation
import ImageIO

// MARK: - Media Preview Info Model
public struct MediaPreviewInfo: Identifiable, Sendable {
    public var id: String { url.absoluteString }
    public let url: URL
    public let fileName: String
    public let formattedSize: String
    public let category: MediaCategory
    public let detailBadge: String?
    public let textPreview: String?
    
    public enum MediaCategory: String, Sendable {
        case image
        case video
        case pdf
        case audio
        case document
        case folder
        case other
    }
    
    public init(
        url: URL,
        fileName: String,
        formattedSize: String,
        category: MediaCategory,
        detailBadge: String?,
        textPreview: String? = nil
    ) {
        self.url = url
        self.fileName = fileName
        self.formattedSize = formattedSize
        self.category = category
        self.detailBadge = detailBadge
        self.textPreview = textPreview
    }
}

// MARK: - On-Demand Media Thumbnail Provider
@MainActor
public final class MediaThumbnailProvider: ObservableObject {
    public static let shared = MediaThumbnailProvider()
    
    private let cache = NSCache<NSURL, NSImage>()
    
    public init() {
        cache.countLimit = 30
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB bound
    }
    
    public func clearCache() {
        cache.removeAllObjects()
    }
    
    public func previewInfo(for url: URL) -> MediaPreviewInfo {
        let name = url.lastPathComponent
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
        let size = Int64(values?.fileSize ?? 0)
        let formattedSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        let isDir = values?.isDirectory ?? false
        
        if isDir {
            return MediaPreviewInfo(
                url: url,
                fileName: name,
                formattedSize: formattedSize,
                category: .folder,
                detailBadge: "Folder"
            )
        }
        
        let ext = url.pathExtension.lowercased()
        
        if ext == "pdf" {
            var badge = "PDF"
            if let doc = PDFDocument(url: url) {
                let pages = doc.pageCount
                badge = "\(pages) pg\(pages == 1 ? "" : "s") • PDF"
            }
            return MediaPreviewInfo(
                url: url,
                fileName: name,
                formattedSize: formattedSize,
                category: .pdf,
                detailBadge: badge
            )
        }
        
        if ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) {
            return MediaPreviewInfo(
                url: url,
                fileName: name,
                formattedSize: formattedSize,
                category: .video,
                detailBadge: ext.uppercased() + " • Video"
            )
        }
        
        if ["png", "jpg", "jpeg", "heic", "webp", "gif", "tiff", "bmp"].contains(ext) {
            var badge = ext.uppercased()
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                let w = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
                let h = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
                if w > 0 && h > 0 {
                    badge = "\(w)×\(h) • \(ext.uppercased())"
                }
            }
            return MediaPreviewInfo(
                url: url,
                fileName: name,
                formattedSize: formattedSize,
                category: .image,
                detailBadge: badge
            )
        }
        
        if ["mp3", "m4a", "wav", "flac", "aac"].contains(ext) {
            return MediaPreviewInfo(
                url: url,
                fileName: name,
                formattedSize: formattedSize,
                category: .audio,
                detailBadge: "Audio"
            )
        }
        
        var textSnippet: String? = nil
        let isTextLike = ["txt", "md", "json", "log", "swift", "py", "sh", "xml", "csv"].contains(ext) ||
                         name.hasPrefix("Message_") || name.hasPrefix("Snippet_")
        if isTextLike, size <= 128 * 1024 {
            let access = url.startAccessingSecurityScopedResource()
            if let str = try? String(contentsOf: url, encoding: .utf8), !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                textSnippet = String(str.prefix(300))
            }
            if access { url.stopAccessingSecurityScopedResource() }
        }
        
        return MediaPreviewInfo(
            url: url,
            fileName: name,
            formattedSize: formattedSize,
            category: .document,
            detailBadge: ext.isEmpty ? "File" : ext.uppercased(),
            textPreview: textSnippet
        )
    }
    
    public func generateThumbnail(for url: URL, targetSize: CGSize = CGSize(width: 320, height: 220)) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        let ext = url.pathExtension.lowercased()
        
        // 1. PDF: Front / First Page Thumbnail
        if ext == "pdf" {
            if let image = await generatePDFThumbnail(url: url, size: targetSize) {
                cache.setObject(image, forKey: url as NSURL)
                return image
            }
        }
        
        // 2. Video: Cover Frame at 0.5s
        if ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) {
            if let image = await generateVideoThumbnail(url: url, size: targetSize) {
                cache.setObject(image, forKey: url as NSURL)
                return image
            }
        }
        
        // 3. Image: Downsampled Static Preview
        if ["png", "jpg", "jpeg", "heic", "webp", "gif", "tiff", "bmp"].contains(ext) {
            if let image = generateImageThumbnail(url: url, size: targetSize) {
                cache.setObject(image, forKey: url as NSURL)
                return image
            }
        }
        
        // 4. QuickLook System Fallback
        if let qlImage = await generateQLThumbnail(url: url, size: targetSize) {
            cache.setObject(qlImage, forKey: url as NSURL)
            return qlImage
        }
        
        // 5. System File Icon Fallback
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = targetSize
        return icon
    }
    
    private func generatePDFThumbnail(url: URL, size: CGSize) async -> NSImage? {
        await Task.detached(priority: .userInitiated) {
            guard let doc = PDFDocument(url: url),
                  let page = doc.page(at: 0) else { return nil }
            return page.thumbnail(of: size, for: .mediaBox)
        }.value
    }
    
    private func generateVideoThumbnail(url: URL, size: CGSize) async -> NSImage? {
        await Task.detached(priority: .userInitiated) {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = size
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            } catch {
                return nil
            }
        }.value
    }
    
    private func generateImageThumbnail(url: URL, size: CGSize) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return NSImage(contentsOf: url)
        }
        let maxPixel = max(size.width, size.height) * 2.0
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return NSImage(contentsOf: url)
        }
        return NSImage(cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
    }
    
    private func generateQLThumbnail(url: URL, size: CGSize) async -> NSImage? {
        final class ResumeState: @unchecked Sendable {
            private let lock = NSLock()
            private var resumed = false
            
            func tryResume(continuation: CheckedContinuation<NSImage?, Never>, value: NSImage?) {
                lock.lock()
                defer { lock.unlock() }
                if !resumed {
                    resumed = true
                    continuation.resume(returning: value)
                }
            }
        }
        
        return await withCheckedContinuation { continuation in
            let state = ResumeState()
            
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: size,
                scale: NSScreen.main?.backingScaleFactor ?? 2.0,
                representationTypes: .all
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                state.tryResume(continuation: continuation, value: thumbnail?.nsImage)
            }
            
            // Safety timeout after 2.5s to prevent hanging on unresponsive QuickLook services
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.5) {
                state.tryResume(continuation: continuation, value: nil)
            }
        }
    }
}

// MARK: - File Preview UI State
@MainActor
public final class FilePreviewUIState: ObservableObject {
    @Published public var thumbnail: NSImage?
    @Published public var isLoading = true
    @Published public var info: MediaPreviewInfo?
    
    public init() {}
}

// MARK: - Reusable File Preview Stage Card
public struct FilePreviewStageCard: View {
    public let url: URL
    public let themeColor: Color
    public let actionLabel: String
    public let onDismiss: () -> Void
    public let onAction: () -> Void
    
    @StateObject private var uiState = FilePreviewUIState()
    
    public init(
        url: URL,
        themeColor: Color = DesignSystem.accentColor,
        actionLabel: String = "Send",
        onDismiss: @escaping () -> Void,
        onAction: @escaping () -> Void
    ) {
        self.url = url
        self.themeColor = themeColor
        self.actionLabel = actionLabel
        self.onDismiss = onDismiss
        self.onAction = onAction
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Title & Close Button
            HStack {
                Image(systemName: iconForCategory(uiState.info?.category ?? .other))
                    .font(.system(size: 9.5))
                    .foregroundColor(themeColor)
                Text(url.lastPathComponent)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.primaryText)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close File Preview")
            }
            
            // Thumbnail Stage Area
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                    .frame(height: 100)
                
                if let thumb = uiState.thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 96)
                        .cornerRadius(6)
                        .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                } else if uiState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let previewText = uiState.info?.textPreview, !previewText.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(previewText)
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundColor(DesignSystem.primaryText)
                            .lineLimit(5)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        Spacer()
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.4)))
                } else {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                // Badges in Bottom Corners
                if let badge = uiState.info?.detailBadge {
                    VStack {
                        Spacer()
                        HStack {
                            Text(badge)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.black.opacity(0.75)))
                            
                            Spacer()
                            
                            if let formattedSize = uiState.info?.formattedSize {
                                Text(formattedSize)
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.black.opacity(0.75)))
                            }
                        }
                        .padding(5)
                    }
                }
            }
            .frame(height: 100)
            .contentShape(Rectangle())
            
            // Actions Row: Open Full & Action Button
            HStack(spacing: 8) {
                Button(action: {
                    guard FileManager.default.fileExists(atPath: url.path) else { return }
                    NSWorkspace.shared.open(url)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 8))
                        Text("Open")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(DesignSystem.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(DesignSystem.surfaceFill))
                    .overlay(Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.75))
                }
                .buttonStyle(.spring)
                .accessibilityLabel("Open file in default application")
                
                Spacer()
                
                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 8))
                        Text(actionLabel)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(themeColor))
                }
                .buttonStyle(.spring)
                .accessibilityLabel("Send \(url.lastPathComponent)")
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DesignSystem.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(themeColor.opacity(0.35), lineWidth: 0.8))
        .task(id: url) {
            uiState.info = MediaThumbnailProvider.shared.previewInfo(for: url)
            uiState.thumbnail = await MediaThumbnailProvider.shared.generateThumbnail(for: url)
            uiState.isLoading = false
        }
    }
    
    private func iconForCategory(_ category: MediaPreviewInfo.MediaCategory) -> String {
        switch category {
        case .image: return "photo"
        case .video: return "film"
        case .pdf: return "doc.text.fill"
        case .audio: return "waveform"
        case .folder: return "folder.fill"
        case .document, .other: return "doc"
        }
    }
}

// MARK: - Carousel Item View for Preview All
public struct FilePreviewCarouselItemView: View {
    public let url: URL
    public let themeColor: Color
    public let onRemove: () -> Void
    
    @StateObject private var uiState = FilePreviewUIState()
    
    public init(url: URL, themeColor: Color = DesignSystem.accentColor, onRemove: @escaping () -> Void) {
        self.url = url
        self.themeColor = themeColor
        self.onRemove = onRemove
    }
    
    public var body: some View {
        VStack(spacing: 5) {
            // Preview Thumbnail Box
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 110, height: 85)
                
                if let thumb = uiState.thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 104, maxHeight: 79)
                        .cornerRadius(5)
                        .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
                } else if uiState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let previewText = uiState.info?.textPreview, !previewText.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(previewText)
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(DesignSystem.primaryText)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        Spacer()
                    }
                    .padding(5)
                    .frame(width: 110, height: 85)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.4)))
                } else {
                    VStack(spacing: 3) {
                        Image(systemName: iconForCategory(uiState.info?.category ?? .other))
                            .font(.system(size: 20))
                            .foregroundColor(themeColor)
                        if !url.pathExtension.isEmpty {
                            Text(url.pathExtension.uppercased())
                                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.secondaryText)
                        }
                    }
                }
                
                // Top-right Remove Button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.85))
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .accessibilityLabel("Remove \(url.lastPathComponent)")
                    }
                    Spacer()
                }
                
                // Bottom Badges (Format / Size)
                VStack {
                    Spacer()
                    HStack {
                        if let badge = uiState.info?.detailBadge {
                            Text(badge)
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Color.black.opacity(0.75)))
                        }
                        
                        Spacer()
                        
                        if let size = uiState.info?.formattedSize {
                            Text(size)
                                .font(.system(size: 7, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Color.black.opacity(0.75)))
                        }
                    }
                    .padding(4)
                }
            }
            .frame(width: 110, height: 85)
            .contentShape(Rectangle())
            .onTapGesture {
                guard FileManager.default.fileExists(atPath: url.path) else { return }
                NSWorkspace.shared.open(url)
            }
            .help("Click to open in default app")
            
            // Name of File Below Preview
            Text(url.lastPathComponent)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundColor(DesignSystem.primaryText)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(width: 110)
        }
        .frame(width: 110)
        .task(id: url) {
            uiState.info = MediaThumbnailProvider.shared.previewInfo(for: url)
            uiState.thumbnail = await MediaThumbnailProvider.shared.generateThumbnail(for: url)
            uiState.isLoading = false
        }
    }
    
    private func iconForCategory(_ category: MediaPreviewInfo.MediaCategory) -> String {
        switch category {
        case .image: return "photo"
        case .video: return "film"
        case .pdf: return "doc.text.fill"
        case .audio: return "waveform"
        case .folder: return "folder.fill"
        case .document, .other: return "doc.fill"
        }
    }
}

// MARK: - Horizontal Preview All Carousel Card
public struct FilePreviewAllCarouselCard: View {
    public let urls: [URL]
    public let themeColor: Color
    public let actionLabel: String
    public let onRemoveFile: (URL) -> Void
    public let onDismiss: () -> Void
    public let onAction: () -> Void
    
    public init(
        urls: [URL],
        themeColor: Color = DesignSystem.accentColor,
        actionLabel: String = "Send All",
        onRemoveFile: @escaping (URL) -> Void,
        onDismiss: @escaping () -> Void,
        onAction: @escaping () -> Void
    ) {
        self.urls = urls
        self.themeColor = themeColor
        self.actionLabel = actionLabel
        self.onRemoveFile = onRemoveFile
        self.onDismiss = onDismiss
        self.onAction = onAction
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Title, Scroll Hint & Close Button
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(themeColor)
                    Text("File Previews (\(urls.count))")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.primaryText)
                }
                
                Spacer()
                
                Text("Scroll to browse")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText)
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close File Previews")
            }
            
            // Horizontal Scroll Bar of Previews with File Names Below
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(urls, id: \.self) { fileURL in
                        FilePreviewCarouselItemView(
                            url: fileURL,
                            themeColor: themeColor,
                            onRemove: { onRemoveFile(fileURL) }
                        )
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 6)
            }
            .frame(height: 124)
            
            // Bottom Action Row
            HStack {
                Text("\(urls.count) item(s) staged")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(DesignSystem.secondaryText)
                
                Spacer()
                
                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 8))
                        Text(actionLabel)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(themeColor))
                }
                .buttonStyle(.spring)
                .accessibilityLabel(actionLabel)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DesignSystem.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(themeColor.opacity(0.35), lineWidth: 0.8))
    }
}
