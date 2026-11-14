import Foundation
import Network
import Security
import CryptoKit

// MARK: - LocalShare Multicast & Manual Discovery Service
public final class LocalShareDiscovery: @unchecked Sendable {
    public static let shared = LocalShareDiscovery()
    
    private let lock = NSLock()
    private var multicastGroup: NWConnectionGroup?
    private var isRunning: Bool = false
    private let queue = DispatchQueue(label: "com.notch.LocalShare.Discovery", qos: .utility)
    
    // Configuration
    public var localAlias: String = "MacBook"
    public var localPort: UInt16 = LocalShareConstants.defaultHttpPort
    public var isMulticastEnabled: Bool = true
    
    // Discovered Peers Registry: Fingerprint -> Peer
    private var peersMap: [String: LocalShareDiscoveredPeer] = [:]
    private var peerObservers: [UUID: @Sendable ([LocalShareDiscoveredPeer]) -> Void] = [:]
    public var onPeersUpdated: (@Sendable ([LocalShareDiscoveredPeer]) -> Void)?
    
    public init() {}
    
    public func addPeersObserver(_ observer: @escaping @Sendable ([LocalShareDiscoveredPeer]) -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        peerObservers[id] = observer
        lock.unlock()
        return id
    }
    
    public func removePeersObserver(id: UUID) {
        lock.lock()
        peerObservers.removeValue(forKey: id)
        lock.unlock()
    }
    
    // MARK: - Lifecycle Management
    
    public var activePeers: [LocalShareDiscoveredPeer] {
        lock.lock()
        defer { lock.unlock() }
        let cutoff = Date().addingTimeInterval(-60) // 60s timeout
        return peersMap.values.filter { $0.lastSeen > cutoff }.sorted { $0.alias < $1.alias }
    }
    
    public var isDiscoveryActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunning
    }
    
    /// Starts discovery. If enableMulticast is true, joins 224.0.0.167:53317 and sends initial announcement.
    public func start(
        alias: String = "MacBook",
        port: UInt16 = LocalShareConstants.defaultHttpPort,
        enableMulticast: Bool = true
    ) {
        lock.lock()
        guard !isRunning else {
            lock.unlock()
            return
        }
        self.isRunning = true
        self.localAlias = alias
        self.localPort = port
        self.isMulticastEnabled = enableMulticast
        lock.unlock()
        
        guard enableMulticast else { return }
        
        setupMulticastGroup()
        sendAnnouncement(isInitial: true)
    }
    
    /// Stops multicast discovery and cleans up sockets.
    public func stop() {
        lock.lock()
        let group = self.multicastGroup
        self.multicastGroup = nil
        self.isRunning = false
        lock.unlock()
        
        group?.cancel()
    }
    
    // MARK: - Multicast Group Setup
    
    private func setupMulticastGroup() {
        do {
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(LocalShareConstants.defaultMulticastGroup),
                port: NWEndpoint.Port(rawValue: LocalShareConstants.defaultMulticastPort) ?? 53317
            )
            let groupDescriptor = try NWMulticastGroup(for: [endpoint])
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true
            
            let group = NWConnectionGroup(with: groupDescriptor, using: params)
            group.setReceiveHandler(maximumMessageSize: 65536) { [weak self] message, content, isComplete in
                guard let self = self, let content = content, !content.isEmpty else { return }
                var remoteHost = "127.0.0.1"
                if let endpoint = message.remoteEndpoint, case .hostPort(let host, _) = endpoint {
                    remoteHost = "\(host)"
                }
                let cleanHost = LocalShareSecurity.normalizeIP(remoteHost)
                self.handleIncomingMulticastPacket(data: content, fromHost: cleanHost)
            }
            
            group.stateUpdateHandler = { state in
                // Handle state changes if needed
            }
            
            self.multicastGroup = group
            group.start(queue: queue)
        } catch {
            // Silently fail if multicast is blocked on the network interface
        }
    }
    
    // MARK: - Announcement Transmission
    
    public func sendAnnouncement(isInitial: Bool) {
        let info = LocalShareDeviceInfo(
            alias: LocalShareSecurity.sanitizeAlias(localAlias),
            fingerprint: LocalShareIdentityManager.shared.certificateFingerprint,
            port: Int(localPort),
            protocol: "https",
            announce: isInitial
        )
        
        guard let data = try? JSONEncoder().encode(info) else { return }
        multicastGroup?.send(content: data) { _ in }
    }
    
    // MARK: - Incoming Packet Processing
    
    private func handleIncomingMulticastPacket(data: Data, fromHost: String) {
        guard let info = try? JSONDecoder().decode(LocalShareDeviceInfo.self, from: data) else {
            return
        }
        
        let myFingerprint = LocalShareIdentityManager.shared.certificateFingerprint
        // 1. Self-announcement suppression: discard messages from own device
        guard info.fingerprint.caseInsensitiveCompare(myFingerprint) != .orderedSame else {
            return
        }
        
        let peerPort = UInt16(info.port ?? Int(LocalShareConstants.defaultHttpPort))
        let peer = LocalShareDiscoveredPeer(
            alias: LocalShareSecurity.sanitizeAlias(info.alias),
            deviceModel: info.deviceModel,
            deviceType: info.deviceType ?? .desktop,
            fingerprint: info.fingerprint,
            host: fromHost,
            port: peerPort,
            protocol: info.`protocol` ?? "https",
            download: info.download ?? false,
            lastSeen: Date()
        )
        
        registerDiscoveredPeer(peer)
        
        // 2. Loop prevention: Only reply if announce == true
        if info.announce == true {
            sendDirectRegisterReply(to: peer)
        }
    }
    
    public func registerDiscoveredPeer(_ peer: LocalShareDiscoveredPeer) {
        lock.lock()
        peersMap[peer.fingerprint] = peer
        let updatedList = peersMap.values.sorted { $0.alias < $1.alias }
        let observers = Array(peerObservers.values)
        let legacyHandler = onPeersUpdated
        lock.unlock()
        
        legacyHandler?(updatedList)
        for obs in observers {
            obs(updatedList)
        }
    }
    
    // MARK: - Direct Unicast Register Reply
    
    public func sendDirectRegisterReply(to peer: LocalShareDiscoveredPeer) {
        let cleanHost = LocalShareSecurity.formatHostForURL(peer.host)
        guard let url = URL(string: "\(peer.`protocol`)://\(cleanHost):\(peer.port)\(LocalShareEndpoints.register)") else {
            return
        }
        
        let myDto = LocalShareRegisterDto(
            alias: LocalShareSecurity.sanitizeAlias(localAlias),
            fingerprint: LocalShareIdentityManager.shared.certificateFingerprint,
            port: Int(localPort),
            protocol: "https"
        )
        
        guard let body = try? JSONEncoder().encode(myDto) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 5.0
        
        // Ephemeral background unicast registration task with permissive TLS delegate for self-signed certificates
        let delegate = LocalSharePermissiveTLSDelegate()
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request) { _, _, _ in
            session.finishTasksAndInvalidate()
        }
        task.resume()
    }
    
    // MARK: - Manual Direct IP Discovery Fallback
    
    /// Unicast discovery fallback for networks where multicast is blocked or for manual IP entry.
    public func registerManualIP(
        host: String,
        port: UInt16 = LocalShareConstants.defaultHttpPort
    ) async throws -> LocalShareDiscoveredPeer {
        let cleanHost = LocalShareSecurity.formatHostForURL(host)
        guard let url = URL(string: "https://\(cleanHost):\(port)\(LocalShareEndpoints.register)") else {
            throw LocalShareError.invalidURL
        }
        
        let myDto = LocalShareRegisterDto(
            alias: LocalShareSecurity.sanitizeAlias(localAlias),
            fingerprint: LocalShareIdentityManager.shared.certificateFingerprint,
            port: Int(localPort),
            protocol: "https"
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(myDto)
        request.timeoutInterval = 10.0
        
        // Use an ephemeral session with bootstrap delegate to inspect peer TLS certificate
        let delegate = LocalShareDiscoveryBootstrapDelegate()
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw LocalShareError.serverError("Manual registration returned non-200")
        }
        
        let peerDto = try JSONDecoder().decode(LocalShareRegisterDto.self, from: data)
        
        // Cross-verify TLS handshake certificate against claimed DTO fingerprint to prevent MITM spoofing
        if let presentedFp = delegate.capturedFingerprint, !presentedFp.isEmpty {
            guard presentedFp.caseInsensitiveCompare(peerDto.fingerprint) == .orderedSame else {
                throw LocalShareError.peerCertificateMismatch(expected: peerDto.fingerprint, found: presentedFp)
            }
        }
        
        let peer = LocalShareDiscoveredPeer(
            alias: LocalShareSecurity.sanitizeAlias(peerDto.alias),
            deviceModel: peerDto.deviceModel,
            deviceType: peerDto.deviceType ?? .desktop,
            fingerprint: peerDto.fingerprint,
            host: host,
            port: UInt16(peerDto.port ?? Int(port)),
            protocol: peerDto.`protocol` ?? "https",
            download: peerDto.download ?? false,
            lastSeen: Date()
        )
        
        registerDiscoveredPeer(peer)
        return peer
    }
    
    public func clearDiscoveredPeers() {
        lock.lock()
        defer { lock.unlock() }
        peersMap.removeAll()
    }
    
    /// Rescans for nearby LocalShare / LocalSend peers on the local subnet by broadcasting an initial announcement.
    public func rescan() {
        if !isDiscoveryActive {
            start(alias: localAlias, port: localPort, enableMulticast: true)
        }
        sendAnnouncement(isInitial: true)
    }
}

// MARK: - Trust-On-First-Use (TOFU) Discovery Bootstrap Delegate
/// Captures and verifies the peer leaf certificate during initial discovery/registration handshake.
/// NOTE: This performs a Trust-On-First-Use (TOFU) certificate exchange, NOT certificate pinning.
/// Certificate pinning is strictly enforced on subsequent connections by `LocalSharePeerPinningDelegate`.
public final class LocalShareDiscoveryBootstrapDelegate: NSObject, URLSessionDelegate, Sendable {
    private final class CertBox: @unchecked Sendable {
        private var data: Data?
        private let lock = NSLock()
        func set(_ d: Data) { lock.lock(); defer { lock.unlock() }; self.data = d }
        func get() -> Data? { lock.lock(); defer { lock.unlock() }; return self.data }
    }
    private let certBox = CertBox()
    
    public var capturedCertificateDER: Data? {
        certBox.get()
    }
    
    public var capturedFingerprint: String? {
        guard let der = certBox.get() else { return nil }
        let digest = SHA256.hash(data: der)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        var secError: CFError?
        _ = SecTrustEvaluateWithError(serverTrust, &secError)
        
        if let certChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
           let leaf = certChain.first {
            let der = SecCertificateCopyData(leaf) as Data
            certBox.set(der)
        }
        
        // Initial discovery bootstrap: accepts the self-signed certificate on initial exchange
        // in order to inspect and cross-verify identity against the registration DTO.
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

public typealias LocalSharePermissiveTLSDelegate = LocalShareDiscoveryBootstrapDelegate
