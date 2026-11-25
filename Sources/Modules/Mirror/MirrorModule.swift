import SwiftUI
@preconcurrency import AVFoundation
import AppKit

public final class CameraSessionManager: @unchecked Sendable {
    private let stateLock = NSLock()
    private var _captureSession: AVCaptureSession?
    public var captureSession: AVCaptureSession? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _captureSession
    }
    private var isConfigured = false
    private let queue = DispatchQueue(label: "com.notch.camera.queue")
    
    public init() {}
    
    public func start(completion: @escaping @MainActor @Sendable (Bool, String?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.stateLock.lock()
            let session = self._captureSession ?? AVCaptureSession()
            self._captureSession = session
            self.stateLock.unlock()
            
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
                
                guard let dev = device else {
                    session.commitConfiguration()
                    DispatchQueue.main.async {
                        completion(false, "No camera device found.")
                    }
                    return
                }
                
                do {
                    let input = try AVCaptureDeviceInput(device: dev)
                    if session.canAddInput(input) {
                        session.addInput(input)
                        session.commitConfiguration()
                        self.isConfigured = true
                    } else {
                        session.commitConfiguration()
                        DispatchQueue.main.async {
                            completion(false, "Cannot add camera input to session.")
                        }
                        return
                    }
                } catch {
                    session.commitConfiguration()
                    DispatchQueue.main.async {
                        completion(false, error.localizedDescription)
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
    
    public func stop(completion: @escaping @MainActor @Sendable () -> Void = {}) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.stateLock.lock()
            let session = self._captureSession
            self._captureSession = nil
            self.stateLock.unlock()
            if let session, session.isRunning {
                session.stopRunning()
            }
            self.isConfigured = false
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    public func stopSync() {
        queue.sync { [weak self] in
            guard let self = self else { return }
            self.stateLock.lock()
            let session = self._captureSession
            self._captureSession = nil
            self.stateLock.unlock()
            if let session, session.isRunning {
                session.stopRunning()
            }
            self.isConfigured = false
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
    @Published public var isUserPaused: Bool = false
    @Published public var hasPermission: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public private(set) var session: AVCaptureSession?
    
    public let manager = CameraSessionManager()
    private var isActive = false
    var viewers = 0
    
    public init() {
        checkPermission()
    }
    
    public func resumeIfViewed() {
        if viewers > 0 { start() }
    }
    
    public func acquire() {
        viewers += 1
        errorMessage = nil
        start()
    }
    
    public func release() {
        viewers = max(0, viewers - 1)
        if viewers == 0 {
            isUserPaused = false
            stop(force: true)
        }
    }
    
    public func start() {
        guard !isActive, !isUserPaused else { return }
        isActive = true
        checkPermissionAndStart()
    }
    
    public func stop() {
        stop(force: false)
    }
    
    public func stop(force: Bool) {
        if !force && viewers > 0 { return }
        guard isActive || isRunning else { return }
        isActive = false
        manager.stop { [weak self] in
            self?.session = nil
            self?.isRunning = false
        }
    }
    
    public func togglePause() {
        if isRunning {
            isUserPaused = true
            stop()
        } else {
            isUserPaused = false
            start()
        }
    }
    
    private func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        hasPermission = (status == .authorized)
    }
    
    private func checkPermissionAndStart() {
        errorMessage = nil
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
            manager.start { [weak self] running, error in
                guard let self, self.isActive else { return }
                self.session = self.manager.captureSession
                self.isRunning = running
                self.errorMessage = error
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    guard self.isActive else { return }
                    self.hasPermission = granted
                    if granted {
                        self.manager.start { [weak self] running, error in
                            guard let self, self.isActive else { return }
                            self.session = self.manager.captureSession
                            self.isRunning = running
                            self.errorMessage = error
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
    @Environment(\.notchCompact) private var notchCompact
    @Environment(\.notchTight) private var notchTight
    
    public var body: some View {
        let previewH: CGFloat = notchTight ? 80 : (notchCompact ? 105 : 140)
        
        VStack(alignment: .leading, spacing: notchTight ? 4 : 8) {
            HStack {
                Text("Camera Mirror")
                    .font(.system(size: notchTight ? 10.5 : 12, weight: .bold, design: .rounded))
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
                    .frame(height: previewH)
                
                CameraLivePreview(session: module.session)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(height: previewH)
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
            module.acquire()
        }
        .onDisappear {
            module.release()
        }
    }
}

// MARK: - 1-Space Compact Mirror Glance View
public struct MirrorCompactTileView: View {
    @ObservedObject var module: MirrorModule = MirrorModule.shared
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header: Camera icon + Text("Mirror") + Spacer() + status dot
            HStack(spacing: 5) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.98, green: 0.72, blue: 0.20))
                
                Text("Mirror")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                Spacer()
                
                Circle()
                    .fill(module.isRunning ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
            }
            
            // Center: 76×76 camera preview squircle (corner radius 12) with subtle 0.9pt border
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 76, height: 76)
                
                CameraLivePreview(session: module.session)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(width: 76, height: 76)
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
            
            // Bottom: Centered capsule button [ ● Pause ] / [ ● Resume ]
            Button(action: {
                module.togglePause()
            }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(module.isRunning ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                    Text(module.isRunning ? "Pause" : "Resume")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3.5)
                .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.9)
                )
        )
        .onAppear { module.acquire() }
        .onDisappear { module.release() }
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
        view.setSession(session)
        return view
    }
    
    public func updateNSView(_ nsView: CameraHostingNSView, context: Context) {
        nsView.setSession(session)
    }
}

public final class CameraHostingNSView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func setSession(_ session: AVCaptureSession?) {
        guard previewLayer.session !== session else { return }
        previewLayer.session = session
        if let c = previewLayer.connection, c.isVideoMirroringSupported {
            c.automaticallyAdjustsVideoMirroring = false
            c.isVideoMirrored = true
        }
    }

    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }
}
