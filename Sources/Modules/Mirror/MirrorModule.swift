import SwiftUI
import AVFoundation
import AppKit

public final class CameraSessionManager: @unchecked Sendable {
    public let captureSession = AVCaptureSession()
    private var isConfigured = false
    private let queue = DispatchQueue(label: "com.notch.camera.queue")
    
    public init() {}
    
    public func start(completion: @escaping @MainActor @Sendable (Bool, String?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.isConfigured {
                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = .vga640x480
                
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
                   self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.captureSession.commitConfiguration()
                    self.isConfigured = true
                } else {
                    self.captureSession.commitConfiguration()
                    DispatchQueue.main.async {
                        completion(false, "No camera found or camera in use by another application.")
                    }
                    return
                }
            }
            
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            
            let running = self.captureSession.isRunning
            DispatchQueue.main.async {
                completion(running, running ? nil : "Could not start camera.")
            }
        }
    }
    
    public func stop(completion: @escaping @MainActor @Sendable () -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

@MainActor
public final class MirrorModule: NotchModule {
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

public struct CameraLivePreview: NSViewRepresentable {
    public let session: AVCaptureSession
    
    public func makeNSView(context: Context) -> CameraHostingNSView {
        let view = CameraHostingNSView()
        view.setSession(session)
        return view
    }
    
    public func updateNSView(_ nsView: CameraHostingNSView, context: Context) {
        nsView.setSession(session)
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
