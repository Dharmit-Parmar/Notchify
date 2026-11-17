import Foundation
import Network
import CryptoKit

// MARK: - Server Bind Interface
public enum LocalShareServerBind: Sendable {
    case localNetwork
    case loopbackOnly
}

// MARK: - LocalShare Server State
public enum LocalShareServerState: Sendable, Equatable {
    case stopped
    case starting
    case running(port: UInt16)
    case failed(String)
}

// MARK: - HTTP Request Representation
private struct LocalShareHTTPRequest {
    let method: String
    let path: String
    let queryParams: [String: String]
    let headers: [String: String]
    let body: Data
    let remoteIP: String
}

// MARK: - HTTPS LocalShare Server (NWListener-based)
public final class LocalShareServer: @unchecked Sendable {
    public static let shared = LocalShareServer()
    
    private let lock = NSLock()
    private var listener: NWListener?
    private var state: LocalShareServerState = .stopped
    private let queue = DispatchQueue(label: "com.notch.LocalShare.Server", qos: .userInitiated)
    
    // Server Configuration (Synchronized for SEC-05 thread safety)
    private var _serverAlias: String = "MacBook"
    public var serverAlias: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _serverAlias
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _serverAlias = newValue
        }
    }
    
    private var _requiredPin: String? = nil
    public var requiredPin: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _requiredPin
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _requiredPin = newValue
        }
    }
    
    private var _autoAcceptFavorites: Bool = false
    public var autoAcceptFavorites: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _autoAcceptFavorites
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _autoAcceptFavorites = newValue
        }
    }
    
    private var _favoriteFingerprints: Set<String> = []
    public var favoriteFingerprints: Set<String> {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _favoriteFingerprints
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _favoriteFingerprints = newValue
        }
    }
    
    // Explicit Test Harness Mode Gate (Disables auto-accepting loopback in production)
    private var _isTestHarnessAutoAcceptEnabled: Bool = false
    public var isTestHarnessAutoAcceptEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isTestHarnessAutoAcceptEnabled
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isTestHarnessAutoAcceptEnabled = newValue
        }
    }
    
    // Shared files available for reverse-download via browser / download API
    private var _sharedFiles: [URL] = []
    public var sharedDownloadFiles: [URL] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _sharedFiles
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _sharedFiles = newValue
        }
    }
    
    // Explicit Peer Trust State Map
    private let trustLock = NSLock()
    private var _trustedPeers: [String: LocalShareTrustedPeer] = [:]
    public var trustedPeers: [String: LocalShareTrustedPeer] {
        get {
            trustLock.lock()
            defer { trustLock.unlock() }
            return _trustedPeers
        }
        set {
            trustLock.lock()
            _trustedPeers = newValue
            trustLock.unlock()
        }
    }
    
    public func trustStatus(for fingerprint: String, alias: String?) -> LocalSharePeerTrustState {
        trustLock.lock()
        defer { trustLock.unlock() }
        
        if let record = _trustedPeers.values.first(where: { $0.fingerprint.caseInsensitiveCompare(fingerprint) == .orderedSame }) {
            return record.trustState
        }
        
        if let alias = alias, !alias.isEmpty {
            if let prior = _trustedPeers.values.first(where: { $0.alias.caseInsensitiveCompare(alias) == .orderedSame && $0.trustState == .trusted }) {
                if prior.fingerprint.caseInsensitiveCompare(fingerprint) != .orderedSame {
                    return .certificateChanged
                }
            }
        }
        
        return .unverifiedFirstContact
    }
    
    // Explicit Acceptance Gate Hook: (Session, Completion(Bool))
    public var onIncomingSessionOffered: (@Sendable (LocalShareSession, @escaping @Sendable (Bool) -> Void) -> Void)?
    
    // Server State Update Callback
    private var stateObservers: [UUID: @Sendable (LocalShareServerState) -> Void] = [:]
    public var onStateChanged: (@Sendable (LocalShareServerState) -> Void)?
    
    public func addStateObserver(_ observer: @escaping @Sendable (LocalShareServerState) -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        stateObservers[id] = observer
        lock.unlock()
        return id
    }
    
    public func removeStateObserver(id: UUID) {
        lock.lock()
        stateObservers.removeValue(forKey: id)
        lock.unlock()
    }
    
    private let rateLimiter = LocalShareRateLimiter(maxRequests: 60, windowDuration: 1.0)
    private var activeConnectionCount: Int = 0
    private var activeConnectionsByIP: [String: Int] = [:]
    private var activeConnections: [ObjectIdentifier: NWConnection] = [:]
    
    private func registerActiveConnection(_ connection: NWConnection) {
        lock.lock()
        defer { lock.unlock() }
        let id = ObjectIdentifier(connection)
        activeConnections[id] = connection
    }
    
    private func removeActiveConnection(_ connection: NWConnection) {
        lock.lock()
        defer { lock.unlock() }
        let id = ObjectIdentifier(connection)
        activeConnections.removeValue(forKey: id)
    }
    
    // Anti-Brute-Force PIN State Machine
    private struct FailedPinState {
        var failCount: Int = 0
        var lockoutUntil: Date? = nil
        var lastAttempt: Date = Date()
    }
    private var failedPinAttemptsByIP: [String: FailedPinState] = [:]
    
    public var currentActiveConnections: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeConnectionCount
    }
    
    private func incrementConnectionCount(for clientIP: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if activeConnectionCount >= LocalShareSecurity.maxSimultaneousConnections {
            return false
        }
        let normIP = LocalShareSecurity.normalizeIP(clientIP)
        let isLoopback = normIP == "127.0.0.1" || normIP == "::1" || normIP.isEmpty
        let ipLimit = isLoopback ? LocalShareSecurity.maxConnectionsPerLoopback : LocalShareSecurity.maxConnectionsPerIP
        let currentForIP = activeConnectionsByIP[normIP] ?? 0
        if currentForIP >= ipLimit {
            return false
        }
        activeConnectionCount += 1
        activeConnectionsByIP[normIP] = currentForIP + 1
        return true
    }
    
    private func decrementConnectionCount(for clientIP: String) {
        lock.lock()
        defer { lock.unlock() }
        activeConnectionCount = max(0, activeConnectionCount - 1)
        let normIP = LocalShareSecurity.normalizeIP(clientIP)
        if let currentForIP = activeConnectionsByIP[normIP] {
            if currentForIP <= 1 {
                activeConnectionsByIP.removeValue(forKey: normIP)
            } else {
                activeConnectionsByIP[normIP] = currentForIP - 1
            }
        }
    }
    
    private func checkPinLockout(clientIP: String) -> (isLockedOut: Bool, retryAfterSeconds: Int) {
        lock.lock()
        defer { lock.unlock() }
        let normIP = LocalShareSecurity.normalizeIP(clientIP)
        guard let state = failedPinAttemptsByIP[normIP], let lockoutUntil = state.lockoutUntil else {
            return (false, 0)
        }
        let now = Date()
        if now < lockoutUntil {
            let remaining = Int(ceil(lockoutUntil.timeIntervalSince(now)))
            return (true, max(1, remaining))
        } else {
            failedPinAttemptsByIP[normIP]?.lockoutUntil = nil
            return (false, 0)
        }
    }
    
    private func recordFailedPinAttempt(clientIP: String) -> (delaySeconds: Double, isLockedOutNow: Bool) {
        lock.lock()
        defer { lock.unlock() }
        let normIP = LocalShareSecurity.normalizeIP(clientIP)
        var state = failedPinAttemptsByIP[normIP] ?? FailedPinState()
        state.failCount += 1
        state.lastAttempt = Date()
        
        var delay: Double = 0.0
        var lockedOut = false
        if state.failCount >= 10 {
            state.lockoutUntil = Date().addingTimeInterval(LocalShareSecurity.extendedPinLockoutDurationSeconds)
            lockedOut = true
        } else if state.failCount >= LocalShareSecurity.maxFailedPinAttemptsBeforeLockout {
            state.lockoutUntil = Date().addingTimeInterval(LocalShareSecurity.pinLockoutDurationSeconds)
            lockedOut = true
        } else {
            delay = min(2.0, Double(state.failCount) * 0.15)
        }
        failedPinAttemptsByIP[normIP] = state
        return (delay, lockedOut)
    }
    
    private func recordSuccessfulPinAttempt(clientIP: String) {
        lock.lock()
        defer { lock.unlock() }
        let normIP = LocalShareSecurity.normalizeIP(clientIP)
        failedPinAttemptsByIP.removeValue(forKey: normIP)
    }
    
    public init() {}
    
    // MARK: - Lifecycle Management
    
    public var currentState: LocalShareServerState {
        lock.lock()
        defer { lock.unlock() }
        return state
    }
    
    public var boundPort: UInt16? {
        lock.lock()
        defer { lock.unlock() }
        if case .running(let port) = state {
            return port
        }
        return listener?.port?.rawValue
    }
    
    public var isRunning: Bool {
        if case .running = currentState { return true }
        return false
    }
    
    /// Starts the NWListener HTTPS or HTTP server.
    public func start(
        port: UInt16 = LocalShareConstants.defaultHttpPort,
        bindInterface: LocalShareServerBind = .localNetwork,
        enableTLS: Bool = true
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard listener == nil else { return }
        self.state = .starting
        
        let params: NWParameters
        if enableTLS {
            // 1. Configure TLS with our self-signed Keychain-backed identity
            let tlsOptions = NWProtocolTLS.Options()
            sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
            if let networkIdentity = LocalShareIdentityManager.shared.createNetworkIdentity() {
                sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, networkIdentity)
            } else {
                NSLog("[LocalShareServer] CRITICAL: Failed to create Network TLS identity!")
            }
            
            // 2. Configure TCP parameters
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 10
            
            params = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        } else {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            params = NWParameters(tls: nil, tcp: tcpOptions)
        }
        params.allowLocalEndpointReuse = true
        
        if bindInterface == .loopbackOnly {
            params.requiredInterfaceType = .loopback
        }
        
        // 3. Initialize NWListener on requested or ephemeral port
        let requestedPort = NWEndpoint.Port(rawValue: port) ?? .any
        let newListener = try NWListener(using: params, on: requestedPort)
        
        newListener.stateUpdateHandler = { [weak self] newState in
            self?.handleListenerStateUpdate(newState)
        }
        
        newListener.newConnectionHandler = { [weak self] newConnection in
            self?.handleIncomingConnection(newConnection)
        }
        
        self.listener = newListener
        newListener.start(queue: queue)
    }
    
    /// Stops the server, closes all sockets, and resets active sessions.
    public func stop() {
        lock.lock()
        let activeListener = self.listener
        self.listener = nil
        self.state = .stopped
        self.activeConnectionCount = 0
        self.activeConnectionsByIP.removeAll()
        let connsToCancel = Array(activeConnections.values)
        activeConnections.removeAll()
        let callback = onStateChanged
        let observers = Array(stateObservers.values)
        lock.unlock()
        
        activeListener?.cancel()
        for conn in connsToCancel {
            conn.cancel()
        }
        LocalShareSessionCoordinator.shared.reset()
        callback?(.stopped)
        for obs in observers {
            obs(.stopped)
        }
    }
    
    /// Safely restarts the server listener on the specified port.
    public func restart(port: UInt16) {
        stop()
        do {
            try start(port: port)
        } catch {
            NSLog("[LocalShareServer] Failed to restart server on port %d: %@", port, error.localizedDescription)
        }
    }
    
    private func handleListenerStateUpdate(_ newState: NWListener.State) {
        let reportedState: LocalShareServerState
        lock.lock()
        switch newState {
        case .ready:
            let actualPort = listener?.port?.rawValue ?? 0
            self.state = .running(port: actualPort)
            reportedState = self.state
            if actualPort > 0 {
                LocalShareDiscovery.shared.localPort = actualPort
            }
        case .failed(let error):
            self.state = .failed(error.localizedDescription)
            self.listener?.cancel()
            self.listener = nil
            reportedState = self.state
        case .cancelled:
            self.state = .stopped
            self.listener = nil
            reportedState = self.state
        default:
            lock.unlock()
            return
        }
        let callback = onStateChanged
        let observers = Array(stateObservers.values)
        lock.unlock()
        
        callback?(reportedState)
        for obs in observers {
            obs(reportedState)
        }
    }
    
    // MARK: - Thread-Safe Single-Execution Flag
private final class LocalShareAtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    func testAndSet() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if fired { return false }
        fired = true
        return true
    }
}

// MARK: - Connection & Request Handling
    
    private final class LocalShareTimeoutBox: @unchecked Sendable {
        private let lock = NSLock()
        private var item: DispatchWorkItem?
        
        init(_ item: DispatchWorkItem?) {
            self.item = item
        }
        
        func cancel() {
            lock.lock()
            defer { lock.unlock() }
            item?.cancel()
            item = nil
        }
    }
    
    // MARK: - HTTP Chunked Transfer Decoder
    private final class HTTPChunkDecoder: @unchecked Sendable {
        private enum State {
            case readingSize
            case readingData(remaining: Int)
            case readingCRLF
            case readingTrailers
            case finished
        }
        
        private var state: State = .readingSize
        private var buffer = Data()
        private(set) var isFinished: Bool = false
        
        func feed(_ rawData: Data) throws -> Data {
            buffer.append(rawData)
            var output = Data()
            
            while !buffer.isEmpty && !isFinished {
                switch state {
                case .readingSize:
                    guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
                        return output
                    }
                    var sizeLineData = buffer.subdata(in: buffer.startIndex..<newlineIndex)
                    if sizeLineData.last == 0x0D {
                        sizeLineData.removeLast()
                    }
                    buffer.removeSubrange(buffer.startIndex...newlineIndex)
                    
                    guard let lineStr = String(data: sizeLineData, encoding: .ascii) else {
                        throw LocalShareError.serverError("Invalid chunk size encoding")
                    }
                    let cleanLine = lineStr.trimmingCharacters(in: .whitespaces)
                    if cleanLine.isEmpty {
                        continue
                    }
                    let sizeHex = cleanLine.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces) ?? ""
                    guard let chunkSize = Int(sizeHex, radix: 16) else {
                        throw LocalShareError.serverError("Malformed chunk size hex: \(cleanLine)")
                    }
                    
                    if chunkSize == 0 {
                        state = .readingTrailers
                    } else {
                        state = .readingData(remaining: chunkSize)
                    }
                    
                case .readingData(let remaining):
                    let available = min(buffer.count, remaining)
                    let chunkBytes = buffer.subdata(in: buffer.startIndex..<(buffer.startIndex + available))
                    output.append(chunkBytes)
                    buffer.removeSubrange(buffer.startIndex..<(buffer.startIndex + available))
                    let newRemaining = remaining - available
                    if newRemaining == 0 {
                        state = .readingCRLF
                    } else {
                        state = .readingData(remaining: newRemaining)
                    }
                    
                case .readingCRLF:
                    guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
                        return output
                    }
                    buffer.removeSubrange(buffer.startIndex...newlineIndex)
                    state = .readingSize
                    
                case .readingTrailers:
                    guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
                        return output
                    }
                    var trailerLine = buffer.subdata(in: buffer.startIndex..<newlineIndex)
                    if trailerLine.last == 0x0D {
                        trailerLine.removeLast()
                    }
                    buffer.removeSubrange(buffer.startIndex...newlineIndex)
                    if trailerLine.isEmpty {
                        state = .finished
                        isFinished = true
                    }
                    
                case .finished:
                    return output
                }
            }
            
            return output
        }
    }
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        var remoteHost = "127.0.0.1"
        if case .hostPort(let host, _) = connection.endpoint {
            remoteHost = "\(host)"
        }
        let clientIP = LocalShareSecurity.normalizeIP(remoteHost)
        
        guard incrementConnectionCount(for: clientIP) else {
            NSLog("[LocalShareServer] Max connections reached globally or for IP %@. Dropping connection.", clientIP)
            connection.cancel()
            return
        }
        
        registerActiveConnection(connection)
        
        let decremented = LocalShareAtomicFlag()
        let onTerminal: @Sendable () -> Void = { [weak self, weak connection] in
            if decremented.testAndSet() {
                self?.decrementConnectionCount(for: clientIP)
                if let conn = connection {
                    self?.removeActiveConnection(conn)
                }
            }
        }
        
        let endpointDesc = "\(connection.endpoint)"
        connection.stateUpdateHandler = { state in
            switch state {
            case .setup:
                NSLog("[LocalShareServer] Connection to %@ setup", endpointDesc)
            case .preparing:
                NSLog("[LocalShareServer] Connection to %@ preparing (TLS/handshake)", endpointDesc)
            case .ready:
                NSLog("[LocalShareServer] Connection to %@ ready", endpointDesc)
            case .waiting(let error):
                NSLog("[LocalShareServer] Connection to %@ waiting: %@", endpointDesc, String(describing: error))
            case .failed(let error):
                NSLog("[LocalShareServer] Connection to %@ failed: %@", endpointDesc, String(describing: error))
                onTerminal()
            case .cancelled:
                NSLog("[LocalShareServer] Connection to %@ cancelled", endpointDesc)
                onTerminal()
            @unknown default:
                NSLog("[LocalShareServer] Connection to %@ unknown state", endpointDesc)
            }
        }
        
        connection.start(queue: queue)
        
        // 15-second Slowloris pre-header timeout watchdog
        let timeoutWorkItem = DispatchWorkItem { [weak connection] in
            if let conn = connection {
                NSLog("[LocalShareServer] Pre-header watchdog timed out for %@", "\(conn.endpoint)")
                conn.cancel()
            }
        }
        let box = LocalShareTimeoutBox(timeoutWorkItem)
        queue.asyncAfter(deadline: .now() + 15.0, execute: timeoutWorkItem)
        
        receiveHTTPPayload(connection: connection, accumulatedData: Data(), timeoutBox: box)
    }
    
    private func receiveHTTPPayload(connection: NWConnection, accumulatedData: Data, timeoutBox: LocalShareTimeoutBox? = nil) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                NSLog("[LocalShareServer] HTTP receive error from %@: %@", "\(connection.endpoint)", String(describing: error))
                timeoutBox?.cancel()
                connection.cancel()
                return
            }
            
            var buffer = accumulatedData
            if let content = content {
                buffer.append(content)
            }
            
            // Check if full HTTP header has arrived (\r\n\r\n or fallback \n\n)
            let headerEndRange = buffer.range(of: Data("\r\n\r\n".utf8)) ?? buffer.range(of: Data("\n\n".utf8))
            if let headerEndRange = headerEndRange {
                timeoutBox?.cancel()
                let headerData = buffer.subdata(in: 0..<headerEndRange.lowerBound)
                let bodyData = buffer.subdata(in: headerEndRange.upperBound..<buffer.count)
                
                guard let request = self.parseHTTPRequest(headerData: headerData, bodyData: bodyData, connection: connection) else {
                    self.sendRawResponse(connection: connection, statusCode: 400, reason: "Bad Request", body: nil)
                    return
                }
                
                // For /upload, process streaming direct to disk
                if request.path == LocalShareEndpoints.upload || request.path.hasPrefix(LocalShareEndpoints.upload) {
                    self.handleUploadRoute(connection: connection, request: request, initialBody: bodyData)
                    return
                }
                
                // For other JSON routes, verify full Content-Length arrived and enforce maxRequestBodySize cap
                let expectedLength = Int(request.headers["content-length"] ?? "0") ?? 0
                if expectedLength > LocalShareSecurity.maxRequestBodySize {
                    self.sendRawResponse(connection: connection, statusCode: 413, reason: "Payload Too Large", body: nil)
                    return
                }
                
                if bodyData.count < expectedLength && !isComplete {
                    let targetConnection = connection
                    let bodyTimeoutItem = DispatchWorkItem { [weak targetConnection] in
                        if let conn = targetConnection {
                            NSLog("[LocalShareServer] Body receive watchdog timed out for %@", "\(conn.endpoint)")
                            conn.cancel()
                        }
                    }
                    let bodyBox = LocalShareTimeoutBox(bodyTimeoutItem)
                    self.queue.asyncAfter(deadline: .now() + 15.0, execute: bodyTimeoutItem)
                    self.receiveHTTPPayload(connection: connection, accumulatedData: buffer, timeoutBox: bodyBox)
                    return
                }
                
                timeoutBox?.cancel()
                self.routeRequest(connection: connection, request: request)
            } else if buffer.count > LocalShareSecurity.maxHeaderSize {
                // Safeguard against unbounded slowloris header accumulation
                timeoutBox?.cancel()
                self.sendRawResponse(connection: connection, statusCode: 431, reason: "Request Header Fields Too Large", body: nil)
            } else if isComplete {
                NSLog("[LocalShareServer] Connection closed by peer before complete HTTP headers from %@", "\(connection.endpoint)")
                timeoutBox?.cancel()
                connection.cancel()
            } else {
                // Continue accumulating headers
                self.receiveHTTPPayload(connection: connection, accumulatedData: buffer, timeoutBox: timeoutBox)
            }
        }
    }
    
    // MARK: - Request Parsing
    
    private func parseHTTPRequest(headerData: Data, bodyData: Data, connection: NWConnection) -> LocalShareHTTPRequest? {
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return nil
        }
        
        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let requestParts = requestLine.components(separatedBy: " ")
        guard requestParts.count >= 2 else { return nil }
        
        let method = requestParts[0].uppercased()
        let rawURL = requestParts[1]
        
        let urlComponents = URLComponents(string: rawURL) ?? URLComponents(string: "http://localhost" + (rawURL.hasPrefix("/") ? rawURL : "/" + rawURL))
        let pathWithoutQuery = rawURL.components(separatedBy: "?").first ?? rawURL
        let path = urlComponents?.path ?? pathWithoutQuery
        var queryParams: [String: String] = [:]
        urlComponents?.queryItems?.forEach { item in
            queryParams[item.name] = item.value ?? ""
        }
        if queryParams.isEmpty, let qIdx = rawURL.firstIndex(of: "?") {
            let queryString = String(rawURL[rawURL.index(after: qIdx)...])
            for pair in queryString.components(separatedBy: "&") {
                let parts = pair.components(separatedBy: "=")
                if !parts.isEmpty, !parts[0].isEmpty {
                    let key = parts[0]
                    let val = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : ""
                    queryParams[key] = val
                }
            }
        }
        
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                headers[parts[0].lowercased()] = parts[1]
            }
        }
        
        var remoteIP = "127.0.0.1"
        if case .hostPort(let host, _) = connection.endpoint {
            remoteIP = LocalShareSecurity.normalizeIP("\(host)")
        }
        
        return LocalShareHTTPRequest(
            method: method,
            path: path,
            queryParams: queryParams,
            headers: headers,
            body: bodyData,
            remoteIP: remoteIP
        )
    }
    
    // MARK: - Route Dispatcher
    
    private func routeRequest(connection: NWConnection, request: LocalShareHTTPRequest) {
        NSLog("[LocalShareServer] Received %@ %@ from %@", request.method, request.path, request.remoteIP)
        // Enforce rate limiting per client IP (SEC-06: exempt /upload data transfers to prevent dropping batch files)
        if request.path != LocalShareEndpoints.upload && !rateLimiter.isAllowed(ip: request.remoteIP) {
            sendRawResponse(connection: connection, statusCode: 429, reason: "Too Many Requests", body: nil)
            return
        }
        
        switch (request.method, request.path) {
        case ("POST", LocalShareEndpoints.register):
            handleRegisterRoute(connection: connection, request: request)
        case ("POST", LocalShareEndpoints.prepareUpload):
            handlePrepareUploadRoute(connection: connection, request: request)
        case ("POST", LocalShareEndpoints.cancel):
            handleCancelRoute(connection: connection, request: request)
        case ("GET", LocalShareEndpoints.info):
            handleInfoRoute(connection: connection, request: request)
        case ("POST", LocalShareEndpoints.prepareDownload):
            handlePrepareDownloadRoute(connection: connection, request: request)
        case ("GET", LocalShareEndpoints.download):
            handleDownloadRoute(connection: connection, request: request)
        case ("GET", "/"), ("GET", "/index.html"), ("GET", "/download"):
            handleWebDownloadPage(connection: connection, request: request)
        default:
            sendRawResponse(connection: connection, statusCode: 404, reason: "Not Found", body: nil)
        }
    }
    
    // MARK: - Route Handlers
    
    private func handleRegisterRoute(connection: NWConnection, request: LocalShareHTTPRequest) {
        guard let registerDto = try? JSONDecoder().decode(LocalShareRegisterDto.self, from: request.body) else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Bad Request", body: nil)
            return
        }
        
        // Register incoming peer with discovery
        var remoteHost = request.remoteIP
        if case .hostPort(let host, _) = connection.endpoint {
            remoteHost = LocalShareSecurity.normalizeIP("\(host)")
        }
        let peerPort = UInt16(registerDto.port ?? Int(LocalShareConstants.defaultHttpPort))
        let discoveredPeer = LocalShareDiscoveredPeer(
            alias: LocalShareSecurity.sanitizeAlias(registerDto.alias),
            deviceModel: registerDto.deviceModel,
            deviceType: registerDto.deviceType ?? .desktop,
            fingerprint: registerDto.fingerprint,
            host: remoteHost,
            port: peerPort,
            protocol: registerDto.`protocol` ?? "https",
            download: registerDto.download ?? false,
            lastSeen: Date()
        )
        LocalShareDiscovery.shared.registerDiscoveredPeer(discoveredPeer)
        
        let responseDto = LocalShareRegisterDto(
            alias: LocalShareSecurity.sanitizeAlias(serverAlias),
            fingerprint: LocalShareIdentityManager.shared.certificateFingerprint,
            port: Int(boundPort ?? LocalShareConstants.defaultHttpPort),
            protocol: "https"
        )
        sendJSONResponse(connection: connection, statusCode: 200, value: responseDto)
    }
    
    private func handlePrepareUploadRoute(connection: NWConnection, request: LocalShareHTTPRequest) {
        // 1. PIN verification & anti-brute-force throttling / lockout
        if let required = requiredPin, !required.isEmpty {
            let lockout = checkPinLockout(clientIP: request.remoteIP)
            if lockout.isLockedOut {
                sendRawResponse(
                    connection: connection,
                    statusCode: 429,
                    reason: "Too Many Requests",
                    body: "PIN lockout active. Retry in \(lockout.retryAfterSeconds) seconds.".data(using: .utf8)
                )
                return
            }
            
            let providedPin = request.queryParams["pin"]
            if providedPin != required {
                let failureState = recordFailedPinAttempt(clientIP: request.remoteIP)
                if failureState.delaySeconds > 0 {
                    Thread.sleep(forTimeInterval: failureState.delaySeconds)
                }
                sendRawResponse(connection: connection, statusCode: 401, reason: "Unauthorized", body: nil)
                return
            } else {
                recordSuccessfulPinAttempt(clientIP: request.remoteIP)
            }
        }
        
        // 2. Decode prepare request
        guard request.body.count <= LocalShareSecurity.maxRequestBodySize,
              let prepareReq = try? JSONDecoder().decode(LocalSharePrepareUploadRequest.self, from: request.body) else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Bad Request", body: nil)
            return
        }
        
        // 3. Security Caps: File count and individual/aggregate file size
        guard !prepareReq.files.isEmpty else {
            sendRawResponse(connection: connection, statusCode: 204, reason: "No Content", body: nil)
            return
        }
        
        guard prepareReq.files.count <= LocalShareSecurity.maxFilesPerSession else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Too Many Files", body: nil)
            return
        }
        
        var calculatedTotal: Int64 = 0
        for file in prepareReq.files.values {
            if file.size < 0 || file.size > LocalShareSecurity.maxFileSize {
                sendRawResponse(connection: connection, statusCode: 400, reason: "Invalid File Size", body: nil)
                return
            }
            let (newTotal, overflow) = calculatedTotal.addingReportingOverflow(file.size)
            if overflow || newTotal > LocalShareSecurity.maxTotalSessionSize {
                sendRawResponse(connection: connection, statusCode: 400, reason: "Aggregate Size Exceeded", body: nil)
                return
            }
            calculatedTotal = newTotal
        }
        
        // 4. Pre-transfer disk space check
        let targetDir = LocalShareFileManager.shared.activeReceiveDirectory
        guard LocalShareSecurity.hasSufficientDiskSpace(requiredBytes: calculatedTotal, at: targetDir) else {
            sendRawResponse(connection: connection, statusCode: 403, reason: "Insufficient Disk Space", body: nil)
            return
        }
        
        // 5. Generate unique session ID and create session directory
        let sessionId = UUID().uuidString
        let sessionDir: URL
        do {
            sessionDir = try LocalShareFileManager.shared.createSessionDirectory(sessionId: sessionId)
        } catch {
            sendRawResponse(connection: connection, statusCode: 500, reason: "Internal Server Error", body: nil)
            return
        }
        
        // 6. Register active session (enforces single session lock, HTTP 409)
        let session: LocalShareSession
        do {
            session = try LocalShareSessionCoordinator.shared.offerIncomingSession(
                sessionId: sessionId,
                peerInfo: prepareReq.info,
                peerIP: request.remoteIP,
                sessionDirectory: sessionDir,
                filesMetadata: prepareReq.files
            )
        } catch LocalShareError.blockedByAnotherSession {
            LocalShareFileManager.shared.purgeSessionDirectory(sessionId: sessionId)
            sendRawResponse(connection: connection, statusCode: 409, reason: "Conflict", body: nil)
            return
        } catch {
            LocalShareFileManager.shared.purgeSessionDirectory(sessionId: sessionId)
            sendRawResponse(connection: connection, statusCode: 500, reason: "Internal Error", body: nil)
            return
        }
        
        // 7. Acceptance Gate (Peer Trust & Interactive Prompt)
        let senderFp = prepareReq.info.fingerprint
        let senderAlias = prepareReq.info.alias
        let trustState = self.trustStatus(for: senderFp, alias: senderAlias)
        
        if trustState == .certificateChanged {
            LocalShareFileManager.shared.purgeSessionDirectory(sessionId: sessionId)
            sendRawResponse(connection: connection, statusCode: 403, reason: "Peer Certificate Changed", body: nil)
            return
        }
        if trustState == .blocked {
            LocalShareFileManager.shared.purgeSessionDirectory(sessionId: sessionId)
            sendRawResponse(connection: connection, statusCode: 403, reason: "Blocked Peer", body: nil)
            return
        }
        
        // Acceptance Gate: Auto-accept verified favorites or route through interactive prompt gate
        // Cryptographic proof requirement: An unauthenticated JSON fingerprint from an external LAN host
        // MUST NOT bypass the user prompt without shared PIN authentication or loopback trust.
        let normClientIP = LocalShareSecurity.normalizeIP(request.remoteIP)
        let isLoopback = normClientIP == "127.0.0.1" || normClientIP == "::1" || normClientIP.isEmpty
        let isPinAuthenticated = (requiredPin != nil && !requiredPin!.isEmpty && request.queryParams["pin"] == requiredPin)
        // Loopback does not inherently authenticate the process. In production, auto-accept requires PIN or explicit test mode flag.
        let isCryptographicallyVerified = isPinAuthenticated || (isLoopback && isTestHarnessAutoAcceptEnabled)
        
        let favSet = favoriteFingerprints
        let isClaimingFavorite = favSet.contains(senderFp) ||
            favSet.contains(senderFp.lowercased()) ||
            trustedPeers[senderFp.lowercased()]?.trustState == .trusted
        
        let isFav = autoAcceptFavorites && isClaimingFavorite && isCryptographicallyVerified
        
        if isFav {
            session.transition(to: .accepted)
            let tokens = session.generateFileTokens()
            let resp = LocalSharePrepareUploadResponse(sessionId: sessionId, files: tokens)
            self.sendJSONResponse(connection: connection, statusCode: 200, value: resp)
        } else if let gate = onIncomingSessionOffered {
            gate(session) { [weak self] accepted in
                guard let self = self else { return }
                if accepted {
                    session.transition(to: .accepted)
                    let tokens = session.generateFileTokens()
                    let resp = LocalSharePrepareUploadResponse(sessionId: sessionId, files: tokens)
                    self.sendJSONResponse(connection: connection, statusCode: 200, value: resp)
                } else {
                    LocalShareSessionCoordinator.shared.cancelSession(sessionId: sessionId, reason: "Rejected by user")
                    self.sendRawResponse(connection: connection, statusCode: 403, reason: "Forbidden", body: nil)
                }
            }
        } else {
            // Default: Reject if no acceptance gate is attached and not auto-accepted favorite
            LocalShareSessionCoordinator.shared.cancelSession(sessionId: sessionId, reason: "No acceptance handler")
            sendRawResponse(connection: connection, statusCode: 403, reason: "Forbidden", body: nil)
        }
    }
    
    private func handleUploadRoute(connection: NWConnection, request: LocalShareHTTPRequest, initialBody: Data) {
        guard let sessionId = request.queryParams["sessionId"],
              let fileId = request.queryParams["fileId"],
              let token = request.queryParams["token"] else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Missing Parameters", body: nil)
            return
        }
        
        guard let session = LocalShareSessionCoordinator.shared.getActiveSession(sessionId: sessionId) else {
            sendRawResponse(connection: connection, statusCode: 409, reason: "Invalid Session", body: nil)
            return
        }
        
        guard session.validateToken(fileId: fileId, token: token, clientIP: request.remoteIP) else {
            sendRawResponse(connection: connection, statusCode: 403, reason: "Forbidden Token", body: nil)
            return
        }
        
        guard let meta = session.filesMetadata[fileId],
              let sessionDir = session.sessionDirectory else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Unknown File ID", body: nil)
            return
        }
        
        // Content-Length mismatch validation: Reject immediately if declared HTTP Content-Length does not match agreed metadata size
        if let clStr = request.headers["content-length"], let declaredCl = Int64(clStr), declaredCl != meta.size {
            session.releaseTokenReservation(token: token)
            session.markFileFailed(fileId: fileId, error: "Size Mismatch: Content-Length \(declaredCl) != metadata \(meta.size)")
            sendRawResponse(connection: connection, statusCode: 400, reason: "Size Mismatch", body: nil)
            return
        }
        
        let declaredLength = request.headers["content-length"] ?? "MISSING"

        NSLog(
            """
            [LocalShareServer] UPLOAD METADATA
            File ID: %@
            Expected file size: %lld
            HTTP Content-Length: %@
            Initial body bytes: %ld
            """,
            fileId,
            meta.size,
            declaredLength,
            initialBody.count
        )
        
        let sanitizedName = LocalShareSecurity.sanitizeFilename(meta.fileName)
        let streamWriter: LocalShareFileStreamWriter
        do {
            streamWriter = try LocalShareFileManager.shared.beginFileStream(
                fileName: sanitizedName,
                sessionDirectory: sessionDir
            )
            try session.registerActiveWriter(streamWriter, for: fileId)
            session.transition(to: .receiving)
        } catch {
            session.releaseTokenReservation(token: token)
            sendRawResponse(connection: connection, statusCode: 409, reason: "Conflict", body: nil)
            return
        }
        
        let expectedTotal = meta.size
        var currentBytes: Int64 = 0
        
        let isChunked = request.headers["transfer-encoding"]?.lowercased().contains("chunked") == true
            || (request.headers["content-length"] == nil)
        let chunkDecoder = isChunked ? HTTPChunkDecoder() : nil
        
        // Write initial body chunk if already in memory
        if !initialBody.isEmpty {
            let payloadData: Data
            if let decoder = chunkDecoder {
                do {
                    payloadData = try decoder.feed(initialBody)
                } catch {
                    session.releaseTokenReservation(token: token)
                    session.removeActiveWriter(for: fileId)
                    streamWriter.abort()
                    session.markFileFailed(fileId: fileId, error: "Chunk Decode Error: \(error.localizedDescription)")
                    sendRawResponse(connection: connection, statusCode: 400, reason: "Chunk Decode Error", body: nil)
                    return
                }
            } else {
                payloadData = initialBody
            }
            
            if !payloadData.isEmpty {
                do {
                    try streamWriter.writeChunk(payloadData)
                    currentBytes += Int64(payloadData.count)
                    session.updateProgress(fileId: fileId, bytesReceived: currentBytes)
                } catch {
                    session.releaseTokenReservation(token: token)
                    session.removeActiveWriter(for: fileId)
                    streamWriter.abort()
                    session.markFileFailed(fileId: fileId, error: "Write Error: \(error.localizedDescription)")
                    sendRawResponse(connection: connection, statusCode: 500, reason: "Write Error", body: nil)
                    return
                }
            }
        }
        
        if currentBytes >= expectedTotal {
            finalizeStreamAndRespond(connection: connection, session: session, fileId: fileId, token: token, writer: streamWriter, meta: meta)
            return
        }
        
        let maxDuration = max(30.0, min(LocalShareSecurity.totalSessionTimeoutSeconds, Double(expectedTotal) / 10_000.0))
        let transferDeadline = Date().addingTimeInterval(maxDuration)
        
        continueReceivingUpload(
            connection: connection,
            session: session,
            fileId: fileId,
            token: token,
            writer: streamWriter,
            meta: meta,
            expectedTotal: expectedTotal,
            receivedBytes: currentBytes,
            transferDeadline: transferDeadline,
            chunkDecoder: chunkDecoder
        )
    }
    
    private func continueReceivingUpload(
        connection: NWConnection,
        session: LocalShareSession,
        fileId: String,
        token: String,
        writer: LocalShareFileStreamWriter,
        meta: LocalShareFileMetadata,
        expectedTotal: Int64,
        receivedBytes: Int64,
        transferDeadline: Date,
        chunkDecoder: HTTPChunkDecoder?
    ) {
        if Date() > transferDeadline {
            session.releaseTokenReservation(token: token)
            session.removeActiveWriter(for: fileId)
            writer.abort()
            session.markFileFailed(fileId: fileId, error: "Transfer Deadline Exceeded")
            sendRawResponse(connection: connection, statusCode: 408, reason: "Request Timeout", body: nil)
            return
        }
        
        let targetConn = connection
        let targetSess = session
        let idleWorkItem = DispatchWorkItem { [weak targetConn, weak targetSess] in
            targetSess?.releaseTokenReservation(token: token)
            targetSess?.removeActiveWriter(for: fileId)
            writer.abort()
            targetSess?.markFileFailed(fileId: fileId, error: "Upload Inactivity Timeout")
            targetConn?.cancel()
        }
        let idleBox = LocalShareTimeoutBox(idleWorkItem)
        queue.asyncAfter(deadline: .now() + 30.0, execute: idleWorkItem)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            idleBox.cancel()
            guard let self = self else { return }
            if let error = error {
                NSLog("[LocalShareServer] Upload receive error for file %@ from %@: %@", fileId, "\(connection.endpoint)", String(describing: error))
                session.releaseTokenReservation(token: token)
                session.removeActiveWriter(for: fileId)
                writer.abort()
                session.markFileFailed(fileId: fileId, error: error.localizedDescription)
                connection.cancel()
                return
            }
            
            var updatedBytes = receivedBytes
            if let content = content, !content.isEmpty {
                let payloadData: Data
                if let decoder = chunkDecoder {
                    do {
                        payloadData = try decoder.feed(content)
                    } catch {
                        session.releaseTokenReservation(token: token)
                        session.removeActiveWriter(for: fileId)
                        writer.abort()
                        session.markFileFailed(fileId: fileId, error: "Chunk Decode Error: \(error.localizedDescription)")
                        self.sendRawResponse(connection: connection, statusCode: 400, reason: "Chunk Decode Error", body: nil)
                        return
                    }
                } else {
                    payloadData = content
                }
                
                if !payloadData.isEmpty {
                    do {
                        try writer.writeChunk(payloadData)
                        updatedBytes += Int64(payloadData.count)
                        session.updateProgress(fileId: fileId, bytesReceived: updatedBytes)
                    } catch {
                        session.releaseTokenReservation(token: token)
                        session.removeActiveWriter(for: fileId)
                        writer.abort()
                        session.markFileFailed(fileId: fileId, error: "Write Error: \(error.localizedDescription)")
                        self.sendRawResponse(connection: connection, statusCode: 500, reason: "Write Error", body: nil)
                        return
                    }
                    
                    if updatedBytes > expectedTotal {
                        session.releaseTokenReservation(token: token)
                        session.removeActiveWriter(for: fileId)
                        writer.abort()
                        session.markFileFailed(fileId: fileId, error: "Payload Exceeded")
                        self.sendRawResponse(connection: connection, statusCode: 400, reason: "Payload Exceeded", body: nil)
                        return
                    }
                }
            }
            
            if (isComplete || chunkDecoder?.isFinished == true) && updatedBytes < expectedTotal {
                NSLog("[LocalShareServer] Premature connection closure for file %@ from %@ (received %lld of %lld bytes)", fileId, "\(connection.endpoint)", updatedBytes, expectedTotal)
                session.releaseTokenReservation(token: token)
                session.removeActiveWriter(for: fileId)
                writer.abort()
                session.markFileFailed(fileId: fileId, error: "Premature Connection Closure")
                connection.cancel()
                return
            }
            
            if updatedBytes >= expectedTotal {
                self.finalizeStreamAndRespond(
                    connection: connection,
                    session: session,
                    fileId: fileId,
                    token: token,
                    writer: writer,
                    meta: meta
                )
            } else {
                self.continueReceivingUpload(
                    connection: connection,
                    session: session,
                    fileId: fileId,
                    token: token,
                    writer: writer,
                    meta: meta,
                    expectedTotal: expectedTotal,
                    receivedBytes: updatedBytes,
                    transferDeadline: transferDeadline,
                    chunkDecoder: chunkDecoder
                )
            }
        }
    }
    
    private func finalizeStreamAndRespond(
        connection: NWConnection,
        session: LocalShareSession,
        fileId: String,
        token: String,
        writer: LocalShareFileStreamWriter,
        meta: LocalShareFileMetadata
    ) {
        do {
            try writer.finalize(expectedSha256: meta.sha256, expectedSize: meta.size)
            session.markTokenConsumed(fileId: fileId, token: token)
            session.markFileCompleted(fileId: fileId)
            session.removeActiveWriter(for: fileId)
            sendRawResponse(connection: connection, statusCode: 200, reason: "OK", body: nil)
        } catch LocalShareError.checksumMismatch {
            session.releaseTokenReservation(token: token)
            session.removeActiveWriter(for: fileId)
            writer.abort()
            session.markFileFailed(fileId: fileId, error: "Checksum Mismatch")
            sendRawResponse(connection: connection, statusCode: 422, reason: "Unprocessable Entity", body: nil)
        } catch {
            let nsError = error as NSError

            NSLog(
                """
                [LocalShareServer] FILE FINALIZATION FAILED
                File ID: %@
                Expected size: %lld bytes
                Error domain: %@
                Error code: %ld
                Error description: %@
                """,
                fileId,
                meta.size,
                nsError.domain,
                nsError.code,
                error.localizedDescription
            )

            session.releaseTokenReservation(token: token)
            session.removeActiveWriter(for: fileId)
            writer.abort()
            session.markFileFailed(
                fileId: fileId,
                error: error.localizedDescription
            )

            sendRawResponse(
                connection: connection,
                statusCode: 500,
                reason: "Finalize Error",
                body: Data("File finalization failed".utf8)
            )
        }
    }
    
    private func handleCancelRoute(connection: NWConnection, request: LocalShareHTTPRequest) {
        if let sessionId = request.queryParams["sessionId"] {
            LocalShareSessionCoordinator.shared.cancelSession(sessionId: sessionId, reason: "Peer cancelled")
        }
        sendRawResponse(connection: connection, statusCode: 200, reason: "OK", body: nil)
    }
    
    private func handleInfoRoute(connection: NWConnection, request: LocalShareHTTPRequest) {
        let actualPort = boundPort ?? LocalShareConstants.defaultHttpPort
        let info = LocalShareDeviceInfo(
            alias: LocalShareSecurity.sanitizeAlias(serverAlias),
            fingerprint: LocalShareIdentityManager.shared.certificateFingerprint,
            port: Int(actualPort),
            protocol: "https"
        )
        sendJSONResponse(connection: connection, statusCode: 200, value: info)
    }
    
    private func handlePrepareDownloadRoute(connection: NWConnection, request: LocalShareHTTPRequest) {
        if let required = requiredPin, !required.isEmpty {
            let lockout = checkPinLockout(clientIP: request.remoteIP)
            if lockout.isLockedOut {
                sendRawResponse(
                    connection: connection,
                    statusCode: 429,
                    reason: "Too Many Requests",
                    body: "PIN lockout active. Retry in \(lockout.retryAfterSeconds) seconds.".data(using: .utf8)
                )
                return
            }
            
            let providedPin = request.queryParams["pin"]
            if providedPin != required {
                let failureState = recordFailedPinAttempt(clientIP: request.remoteIP)
                if failureState.delaySeconds > 0 {
                    Thread.sleep(forTimeInterval: failureState.delaySeconds)
                }
                sendRawResponse(connection: connection, statusCode: 401, reason: "Unauthorized", body: nil)
                return
            } else {
                recordSuccessfulPinAttempt(clientIP: request.remoteIP)
            }
        }
        
        let files = self.sharedDownloadFiles
        var metadataMap: [String: LocalShareFileMetadata] = [:]
        for (index, url) in files.enumerated() {
            let fileId = "dl-\(index + 1)-\(UUID().uuidString.prefix(6))"
            let size = Int64((try? url.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).fileSize) ?? 0)
            metadataMap[fileId] = LocalShareFileMetadata(
                id: fileId,
                fileName: url.lastPathComponent,
                size: size,
                fileType: "application/octet-stream"
            )
        }
        let resp = LocalSharePrepareUploadResponse(sessionId: UUID().uuidString, files: [:])
        sendJSONResponse(connection: connection, statusCode: 200, value: resp)
    }
    
    private func handleDownloadRoute(connection: NWConnection, request: LocalShareHTTPRequest) {
        if let idxStr = request.queryParams["index"], let idx = Int(idxStr) {
            let files = self.sharedDownloadFiles
            if idx >= 0 && idx < files.count {
                let fileURL = files[idx]
                sendFileResponse(connection: connection, fileURL: fileURL, fileName: fileURL.lastPathComponent)
                return
            }
        }
        sendRawResponse(connection: connection, statusCode: 404, reason: "File Not Found", body: nil)
    }
    
    private func handleWebDownloadPage(connection: NWConnection, request: LocalShareHTTPRequest) {
        let alias = LocalShareSecurity.sanitizeAlias(serverAlias)
        let files = self.sharedDownloadFiles
        
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Local Share - \(alias)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: #121214; color: #f0f0f2; max-width: 600px; margin: 40px auto; padding: 20px; line-height: 1.6; }
                h1 { font-size: 24px; font-weight: 600; margin-bottom: 8px; }
                p { color: #a0a0a5; margin-top: 0; }
                .card { background: #1c1c1f; border-radius: 12px; padding: 16px; margin: 16px 0; border: 1px solid #2c2c30; }
                .file-item { display: flex; justify-content: space-between; align-items: center; padding: 10px 0; border-bottom: 1px solid #2c2c30; }
                .file-item:last-child { border-bottom: none; }
                .file-name { font-weight: 500; word-break: break-all; }
                .file-size { color: #888890; font-size: 13px; }
                .btn { display: inline-block; background: #007aff; color: white; padding: 8px 14px; border-radius: 8px; text-decoration: none; font-size: 13px; font-weight: 500; }
                .btn:hover { background: #0062cc; }
                .empty { text-align: center; color: #666670; padding: 24px 0; }
            </style>
        </head>
        <body>
            <h1>Local Share</h1>
            <p>Shared files from <strong>\(alias)</strong></p>
            <div class="card">
        """
        
        if files.isEmpty {
            html += "<div class=\"empty\">No files currently shared for download.</div>"
        } else {
            for (idx, file) in files.enumerated() {
                let name = file.lastPathComponent
                let size = (try? file.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).fileSize) ?? 0
                let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                let downloadUrl = "/api/localsend/v2/download?index=\(idx)"
                html += """
                <div class="file-item">
                    <div>
                        <div class="file-name">\(name)</div>
                        <div class="file-size">\(sizeStr)</div>
                    </div>
                    <a class="btn" href="\(downloadUrl)">Download</a>
                </div>
                """
            }
        }
        
        html += """
            </div>
        </body>
        </html>
        """
        
        sendRawResponse(connection: connection, statusCode: 200, reason: "OK", body: Data(html.utf8), contentType: "text/html; charset=utf-8")
    }
    
    private func sendFileResponse(
        connection: NWConnection,
        fileURL: URL,
        fileName: String
    ) {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            sendRawResponse(connection: connection, statusCode: 404, reason: "Not Found", body: nil)
            return
        }
        let sanitizedName = LocalShareSecurity.sanitizeFilename(fileName)
        let bodyLength = fileData.count
        var header = "HTTP/1.1 200 OK\r\n"
        header += "Content-Type: application/octet-stream\r\n"
        header += "Content-Length: \(bodyLength)\r\n"
        header += "Content-Disposition: attachment; filename=\"\(sanitizedName)\"\r\n"
        header += "Connection: close\r\n\r\n"
        
        var responseData = Data(header.utf8)
        responseData.append(fileData)
        
        connection.send(content: responseData, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { [weak self, weak connection] _ in
            self?.queue.asyncAfter(deadline: .now() + 3.0) { [weak connection] in
                connection?.cancel()
            }
        })
    }
    
    // MARK: - HTTP Response Builders
    
    private func sendJSONResponse<T: Encodable>(connection: NWConnection, statusCode: Int, value: T) {
        guard let data = try? JSONEncoder().encode(value) else {
            sendRawResponse(connection: connection, statusCode: 500, reason: "Serialization Error", body: nil)
            return
        }
        sendRawResponse(connection: connection, statusCode: statusCode, reason: "OK", body: data, contentType: "application/json")
    }
    
    private func sendRawResponse(
        connection: NWConnection,
        statusCode: Int,
        reason: String,
        body: Data?,
        contentType: String = "text/plain"
    ) {
        let bodyLength = body?.count ?? 0
        NSLog("[LocalShareServer] Sending HTTP %ld %@ (%ld bytes) to %@", statusCode, reason, bodyLength, "\(connection.endpoint)")
        var header = "HTTP/1.1 \(statusCode) \(reason)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(bodyLength)\r\n"
        header += "Connection: close\r\n\r\n"
        
        var responseData = Data(header.utf8)
        if let body = body {
            responseData.append(body)
        }
        
        connection.send(content: responseData, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { [weak self, weak connection] sendError in
            if let sendError = sendError {
                if let conn = connection {
                    NSLog("[LocalShareServer] Response send error to %@: %@", "\(conn.endpoint)", String(describing: sendError))
                    conn.cancel()
                }
            } else {
                self?.queue.asyncAfter(deadline: .now() + 0.05) { [weak connection] in
                    connection?.cancel()
                }
            }
        })
    }
}
