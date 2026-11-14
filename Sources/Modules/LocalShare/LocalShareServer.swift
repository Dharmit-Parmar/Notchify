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
    
    // Server Configuration
    public var serverAlias: String = "MacBook"
    public var requiredPin: String? = nil
    public var autoAcceptFavorites: Bool = false
    public var favoriteFingerprints: Set<String> = []
    
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
    
    private let rateLimiter = LocalShareRateLimiter(maxRequests: 10, windowDuration: 1.0)
    
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
        let callback = onStateChanged
        let observers = Array(stateObservers.values)
        lock.unlock()
        
        activeListener?.cancel()
        LocalShareSessionCoordinator.shared.reset()
        callback?(.stopped)
        for obs in observers {
            obs(.stopped)
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
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        // 15-second Slowloris pre-header timeout watchdog
        let timeoutWorkItem = DispatchWorkItem { [weak connection] in
            connection?.cancel()
        }
        let box = LocalShareTimeoutBox(timeoutWorkItem)
        queue.asyncAfter(deadline: .now() + 15.0, execute: timeoutWorkItem)
        
        receiveHTTPPayload(connection: connection, accumulatedData: Data(), timeoutBox: box)
    }
    
    private func receiveHTTPPayload(connection: NWConnection, accumulatedData: Data, timeoutBox: LocalShareTimeoutBox? = nil) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            if error != nil {
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
                        targetConnection?.cancel()
                    }
                    let bodyBox = LocalShareTimeoutBox(bodyTimeoutItem)
                    self.queue.asyncAfter(deadline: .now() + 15.0, execute: bodyTimeoutItem)
                    self.receiveHTTPPayload(connection: connection, accumulatedData: buffer, timeoutBox: bodyBox)
                    return
                }
                
                timeoutBox?.cancel()
                self.routeRequest(connection: connection, request: request)
            } else if buffer.count > 65536 {
                // Safeguard against unbounded slowloris header accumulation
                timeoutBox?.cancel()
                self.sendRawResponse(connection: connection, statusCode: 431, reason: "Request Header Fields Too Large", body: nil)
            } else if isComplete {
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
        // Enforce rate limiting per client IP
        guard rateLimiter.isAllowed(ip: request.remoteIP) else {
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
        // 1. PIN verification
        if let required = requiredPin, !required.isEmpty {
            let providedPin = request.queryParams["pin"]
            if providedPin != required {
                sendRawResponse(connection: connection, statusCode: 401, reason: "Unauthorized", body: nil)
                return
            }
        }
        
        // 2. Decode prepare request
        guard request.body.count <= LocalShareSecurity.maxRequestBodySize,
              let prepareReq = try? JSONDecoder().decode(LocalSharePrepareUploadRequest.self, from: request.body) else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Bad Request", body: nil)
            return
        }
        
        // 3. Security Caps: File count and individual file size
        guard prepareReq.files.count <= LocalShareSecurity.maxFilesPerSession else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Too Many Files", body: nil)
            return
        }
        
        for file in prepareReq.files.values {
            if file.size > LocalShareSecurity.maxFileSize {
                sendRawResponse(connection: connection, statusCode: 400, reason: "File Too Large", body: nil)
                return
            }
        }
        
        // 4. Pre-transfer disk space check
        let targetDir = LocalShareFileManager.shared.activeReceiveDirectory
        guard LocalShareSecurity.hasSufficientDiskSpace(requiredBytes: prepareReq.totalSize, at: targetDir) else {
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
        
        // Note: Auto-accept from unauthenticated JSON fingerprint is disabled to prevent spoofed auto-acceptance.
        // All incoming sessions must route through the interactive prompt gate.
        if let gate = onIncomingSessionOffered {
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
            // Default: Reject if no acceptance gate is attached
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
        
        // Write initial body chunk if already in memory
        if !initialBody.isEmpty {
            do {
                try streamWriter.writeChunk(initialBody)
                currentBytes += Int64(initialBody.count)
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
            transferDeadline: transferDeadline
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
        transferDeadline: Date
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
                session.releaseTokenReservation(token: token)
                session.removeActiveWriter(for: fileId)
                writer.abort()
                session.markFileFailed(fileId: fileId, error: error.localizedDescription)
                self.sendRawResponse(connection: connection, statusCode: 500, reason: "Upload Stream Error", body: nil)
                connection.cancel()
                return
            }
            
            var updatedBytes = receivedBytes
            if let content = content, !content.isEmpty {
                do {
                    try writer.writeChunk(content)
                    updatedBytes += Int64(content.count)
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
            
            if isComplete && updatedBytes < expectedTotal {
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
                    transferDeadline: transferDeadline
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
            session.releaseTokenReservation(token: token)
            session.removeActiveWriter(for: fileId)
            writer.abort()
            session.markFileFailed(fileId: fileId, error: error.localizedDescription)
            sendRawResponse(connection: connection, statusCode: 500, reason: "Finalize Error", body: nil)
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
        var header = "HTTP/1.1 \(statusCode) \(reason)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(bodyLength)\r\n"
        header += "Connection: close\r\n\r\n"
        
        var responseData = Data(header.utf8)
        if let body = body {
            responseData.append(body)
        }
        
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
