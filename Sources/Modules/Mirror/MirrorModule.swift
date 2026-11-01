import SwiftUI
import AVFoundation
import AppKit

public final class CameraSessionManager: @unchecked Sendable {
    public private(set) var captureSession: AVCaptureSession?
    private var isConfigured = false
    private let queue = DispatchQueue(label: "com.notch.camera.queue")
    
    public init() {}
    
    public func start(completion: @escaping @MainActor @Sendable (Bool, String?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let session = self.captureSession ?? AVCaptureSession()
            self.captureSession = session
            
            if !self.isConfigured {
                session.beginConfiguration()
                session.sessionPreset = .vga640x480
                
                // Prioritize default system video device (e.g. MacBook Air Camera)
                let device = AVCaptureDevice.default(for: .video) ?? {
                    let discovery = AVCaptureDevice.DiscoverySession(
                        deviceTypes: [.builtInWideAngleCamera, .external],
                        mediaType: .video,
                        position: .unspecified
                    )
                    return discovery.devices.first(where: { $0.position == .front }) ?? discovery.devices.first
                }()
                
                if let dev = device,
                   let input = try? AVCaptureDeviceInput(device: dev),
                   session.canAddInput(input) {
                    session.addInput(input)
                    session.commitConfiguration()
                    self.isConfigured = true
                } else {
                    session.commitConfiguration()
                    DispatchQueue.main.async {
                        completion(false, "No camera found or camera in use by another application.")
                    }
                    return
                }
            }
            
            if !session.isRunning {
                session.startRunning()
            }
            
            let running = session.isRunning
            DispatchQueue.main.async {
                completion(running, running ? nil : "Could not start camera.")
            }
        }
    }
    
    public func stop(completion: @escaping @MainActor @Sendable () -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let session = self.captureSession {
                if session.isRunning {
                    session.stopRunning()
                }
                session.beginConfiguration()
                for input in session.inputs {
                    session.removeInput(input)
                }
                session.commitConfiguration()
            }
            self.captureSession = nil
            self.isConfigured = false
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

@MainActor
public final class MirrorModule: NotchModule {
    public static let shared = MirrorModule()
    
    public let id = "mirror"
    public let title = "Mirror"
    public let iconName = "camera.fill"
    @Published public var isEnabled: Bool = true
    
    @Published public var isRunning: Bool = false
    @Published public var hasPermission: Bool = false
    @Published public var errorMessage: String? = nil
    
    public let manager = CameraSessionManager()
    private var isActive = false
    
    public init() {
        checkPermission()
    }
    
    public func start() {
        guard !isActive else { return }
        isActive = true
        checkPermissionAndStart()
    }
    
    public func stop() {
        guard isActive else { return }
        isActive = false
        manager.stop { [weak self] in
            self?.isRunning = false
        }
    }
    
    private func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        hasPermission = (status == .authorized)
    }
    
    private func checkPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
            manager.start { [weak self] running, error in
                self?.isRunning = running
                self?.errorMessage = error
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    guard self.isActive else { return }
                    self.hasPermission = granted
                    if granted {
                        self.manager.start { [weak self] running, error in
                            self?.isRunning = running
                            self?.errorMessage = error
                        }
                    } else {
                        self.errorMessage = "Camera access declined. Enable in System Settings > Privacy & Security > Camera."
                    }
                }
            }
        case .denied, .restricted:
            hasPermission = false
            errorMessage = "Camera access denied. Please allow Notch in System Settings > Privacy & Security > Camera."
        @unknown default:
            break
        }
    }
    
    public func makeCompactView() -> AnyView {
        let running = isRunning
        return AnyView(
            HStack(spacing: 5) {
                Circle()
                    .fill(running ? Color.green : Color.white.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text("Mirror")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
        )
    }
    
    public func makeExpandedView() -> AnyView {
        AnyView(
            MirrorContainerView(module: self)
        )
    }
}

public struct MirrorContainerView: View {
    @ObservedObject var module: MirrorModule
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Camera Mirror")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                if module.isRunning {
                    HStack(spacing: 5) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("Live Preview")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.green)
                    }
                } else {
                    Text(module.errorMessage ?? "Connecting...")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 140)
                
                CameraLivePreview(session: module.manager.captureSession)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(height: 140)
                    .opacity(module.isRunning ? 1 : 0)
                
                if !module.isRunning {
                    VStack(spacing: 8) {
                        if let error = module.errorMessage {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.yellow)
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        } else {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Connecting camera...")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.secondaryText)
                        }
                    }
                }
            }
        }
        .onAppear {
            module.start()
        }
        .onDisappear {
            module.stop()
        }
    }
}

// MARK: - 1-Space Compact Mirror Glance View
public struct MirrorCompactTileView: View {
    @ObservedObject var module: MirrorModule = MirrorModule.shared
    
    public var body: some View {
        HStack(spacing: 12) {
            // Live Squircle Preview
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 80, height: 80)
                
                CameraLivePreview(session: module.manager.captureSession)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(width: 80, height: 80)
                    .opacity(module.isRunning ? 1 : 0)
                
                if !module.isRunning {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.9)
            )
            
            // Mirror Controls & Status
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(module.isRunning ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(module.isRunning ? "MIRROR ACTIVE" : "MIRROR PAUSED")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(module.isRunning ? .green : DesignSystem.secondaryText)
                }
                
                Text("Quick Glance")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Look sharp before meetings")
                    .font(.system(size: 9.5))
                    .foregroundColor(DesignSystem.secondaryText)
                    .lineLimit(1)
                
                Button(action: {
                    if module.isRunning {
                        module.stop()
                    } else {
                        module.start()
                    }
                }) {
                    Text(module.isRunning ? "Pause" : "Resume")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
        )
        .onAppear { module.start() }
        .onDisappear { module.stop() }
    }
}

// MARK: - Adaptive Mirror Widget Container
public struct MirrorAdaptiveWidgetView: View {
    public var span: Int
    @ObservedObject var module: MirrorModule = MirrorModule.shared
    
    public init(span: Int = 2) {
        self.span = span
    }
    
    public var body: some View {
        Group {
            if span == 1 {
                MirrorCompactTileView(module: module)
            } else {
                MirrorContainerView(module: module)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                            .fill(DesignSystem.cardGradient)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                            .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
                    )
            }
        }
    }
}

public struct CameraLivePreview: NSViewRepresentable {
    public let session: AVCaptureSession?
    
    public func makeNSView(context: Context) -> CameraHostingNSView {
        let view = CameraHostingNSView()
        if let s = session {
            view.setSession(s)
        }
        return view
    }
    
    public func updateNSView(_ nsView: CameraHostingNSView, context: Context) {
        if let s = session {
            nsView.setSession(s)
        }
    }
}

public final class CameraHostingNSView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        layer.connection?.automaticallyAdjustsVideoMirroring = false
        layer.connection?.isVideoMirrored = true
        self.previewLayer = layer
        self.layer?.addSublayer(layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setSession(_ session: AVCaptureSession) {
        if previewLayer?.session !== session {
            previewLayer?.session = session
        }
    }
    
    public override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}
