import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - AirDrop Dedicated Sharing Delegate
@MainActor
public final class AirDropSharingDelegate: NSObject, NSSharingServiceDelegate {
    public static let shared = AirDropSharingDelegate()
    
    public func sharingService(_ sharingService: NSSharingService, sourceWindowForShareItems items: [Any], sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>) -> NSWindow? {
        sharingContentScope.pointee = .full
        return NotchShellCoordinator.shared.panel
    }
    
    public func sharingService(_ sharingService: NSSharingService, sourceFrameOnScreenForShareItem item: Any) -> NSRect {
        return NotchShellCoordinator.shared.panel?.frame ?? .zero
    }
    
    public func sharingService(_ sharingService: NSSharingService, willShareItems items: [Any]) {
        DispatchQueue.main.async {
            AirDropModule.shared.isBeaming = true
            AirDropModule.shared.statusMessage = "Beaming \(items.count) item(s) via AirDrop..."
        }
    }
    
    public func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        DispatchQueue.main.async {
            AirDropModule.shared.isBeaming = false
            AirDropModule.shared.statusMessage = "Shared \(items.count) item(s) successfully"
            FeedbackManager.playSuccess()
        }
    }
    
    public func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        DispatchQueue.main.async {
            AirDropModule.shared.isBeaming = false
            AirDropModule.shared.statusMessage = "AirDrop transfer complete"
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
    @Published public var isDropTargeted: Bool = false
    @Published public var statusMessage: String = "Ready to beam to nearby Apple devices"
    @Published public var isBeaming: Bool = false
    
    private let sharingDelegate = AirDropSharingDelegate.shared
    
    public init() {}
    
    public func start() {}
    public func stop() {}
    
    public func shareFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        FeedbackManager.playSend()
        isBeaming = true
        statusMessage = "Opening AirDrop sheet for \(urls.count) item(s)..."
        
        for url in urls {
            if !recentFiles.contains(url) {
                recentFiles.insert(url, at: 0)
            }
        }
        if recentFiles.count > 6 {
            recentFiles = Array(recentFiles.prefix(6))
        }
        
        // Ensure application has focus to present system sharing sheets
        NSApp.activate(ignoringOtherApps: true)
        NotchShellCoordinator.shared.panel?.makeKey()
        
        if let airDrop = NSSharingService(named: .sendViaAirDrop), airDrop.canPerform(withItems: urls) {
            airDrop.delegate = sharingDelegate
            airDrop.perform(withItems: urls)
            statusMessage = "Select recipient in AirDrop sheet"
            FeedbackManager.playSuccess()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.isBeaming = false
            }
            return
        }
        
        // Guaranteed fallback to system Sharing Service Picker
        showSharingPickerFallback(for: urls)
    }
    
    public func showSharingPickerFallback(for urls: [URL]) {
        guard !urls.isEmpty else { return }
        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: urls)
            if let targetView = NotchShellCoordinator.shared.panel?.contentView {
                picker.show(relativeTo: targetView.bounds, of: targetView, preferredEdge: .minY)
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
        
        if openPanel.runModal() == .OK {
            shareFiles(openPanel.urls)
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
        AnyView(
            AirDropExpandedView(module: self)
        )
    }
}

// MARK: - AirDrop Expanded View with Animated Radar & Full Drop Stage
public struct AirDropExpandedView: View {
    @ObservedObject var module: AirDropModule
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var body: some View {
        HStack(spacing: 16) {
            // Left Column: Animated AirDrop Radar Beacon
            ZStack {
                AirDropRadarAnimation(isTargeted: module.isDropTargeted, isBeaming: module.isBeaming)
                    .frame(width: 140, height: 140)
                
                VStack(spacing: 4) {
                    Image(systemName: "airdrop")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(module.isDropTargeted ? .white : DesignSystem.accentColor)
                        .scaleEffect(module.isDropTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: module.isDropTargeted)
                    
                    Text("AirDrop")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 140, height: 140)
            
            // Right Column: Drop Stage, Status & Manual File Picker
            VStack(alignment: .leading, spacing: 8) {
                // Header & Status
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wireless File Transfer")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(module.statusMessage)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(module.isDropTargeted ? DesignSystem.accentColor : DesignSystem.secondaryText)
                        .lineLimit(2)
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
                    
                    VStack(spacing: 5) {
                        Image(systemName: module.isDropTargeted ? "arrow.down.circle.fill" : "arrow.up.and.down.circle")
                            .font(.system(size: 18))
                            .foregroundColor(DesignSystem.accentColor)
                            .scaleEffect(module.isDropTargeted ? 1.2 : 1.0)
                        
                        Text(module.isDropTargeted ? "Release to Beam Immediately" : "Drag & Drop Files Anywhere Here")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Photos, PDFs, videos, or folders")
                            .font(.system(size: 8.5))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                    .padding(8)
                }
                .frame(maxWidth: .infinity, maxHeight: 72)
                
                // Action Buttons & Recent History
                HStack(spacing: 8) {
                    Button(action: module.openFilePicker) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Browse Files...")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(DesignSystem.accentColor))
                    }
                    .buttonStyle(.spring)
                    
                    if !module.recentFiles.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(module.recentFiles, id: \.self) { file in
                                    Button(action: { module.shareFiles([file]) }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.counterclockwise")
                                                .font(.system(size: 7))
                                            Text(file.lastPathComponent)
                                                .font(.system(size: 8.5, weight: .medium))
                                                .lineLimit(1)
                                        }
                                        .foregroundColor(Color.white.opacity(0.8))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(DesignSystem.structureColor))
                                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7))
                                    }
                                    .buttonStyle(.spring)
                                    .help("Re-send \(file.lastPathComponent)")
                                }
                            }
                        }
                        .frame(height: 24)
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(4)
        .contentShape(Rectangle())
        // Active Drop Target for ENTIRE AirDrop Screen (Radar + Drop Box + Info)
        .onDrop(of: [.fileURL, .item, .data, .content], isTargeted: $module.isDropTargeted) { providers in
            var handled = false
            for p in providers {
                if p.canLoadObject(ofClass: URL.self) {
                    handled = true
                    _ = p.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        DispatchQueue.main.async {
                            module.shareFiles([url])
                        }
                    }
                } else if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    handled = true
                    p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                        guard let url else { return }
                        DispatchQueue.main.async {
                            module.shareFiles([url])
                        }
                    }
                }
            }
            return handled
        }
    }
}

// MARK: - Animated Concentric Radar Rings
private struct AirDropRadarAnimation: View {
    let isTargeted: Bool
    let isBeaming: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        TimelineView(.animation(minimumInterval: (isTargeted || isBeaming) ? (1.0 / 30.0) : 0.1, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = min(size.width, size.height) / 2
                let ringCount = 3
                
                let time = timeline.date.timeIntervalSinceReferenceDate
                let speed = isTargeted ? 2.5 : (isBeaming ? 3.5 : 1.0)
                let normalizedTime = (time * speed).truncatingRemainder(dividingBy: 1.0)
                
                for i in 0..<ringCount {
                    let progress = (normalizedTime + Double(i) / Double(ringCount)).truncatingRemainder(dividingBy: 1.0)
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
                
                // Static outer guide boundary
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
