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
    
    // Explicit Acceptance Gate Hook: (Session, Completion(Bool))
    public var onIncomingSessionOffered: (@Sendable (LocalShareSession, @escaping @Sendable (Bool) -> Void) -> Void)?
    
    // Server State Update Callback
    public var onStateChanged: (@Sendable (LocalShareServerState) -> Void)?
    
    private let rateLimiter = LocalShareRateLimiter(maxRequests: 10, windowDuration: 1.0)
    
    public init() {}
    
    // MARK: - Lifecycle Management
    
    public var currentState: LocalShareServerState {
        lock.lock()
        defer { lock.unlock() }
        return state
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
        lock.unlock()
        
        activeListener?.cancel()
        LocalShareSessionCoordinator.shared.reset()
        callback?(.stopped)
    }
    
    private func handleListenerStateUpdate(_ newState: NWListener.State) {
        let reportedState: LocalShareServerState
        lock.lock()
        switch newState {
        case .ready:
            let actualPort = listener?.port?.rawValue ?? 0
            self.state = .running(port: actualPort)
            reportedState = self.state
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
        lock.unlock()
        
        callback?(reportedState)
    }
    
    // MARK: - Connection & Request Handling
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveHTTPPayload(connection: connection, accumulatedData: Data())
    }
    
    private func receiveHTTPPayload(connection: NWConnection, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            if error != nil {
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
                let headerData = buffer.subdata(in: 0..<headerEndRange.lowerBound)
                let bodyData = buffer.subdata(in: headerEndRange.upperBound..<buffer.count)
                
                guard let request = self.parseHTTPRequest(headerData: headerData, bodyData: bodyData, connection: connection) else {
                    self.sendRawResponse(connection: connection, statusCode: 400, reason: "Bad Request", body: nil)
                    return
                }
                
                // For /upload, process streaming direct to disk
                if request.path == LocalShareEndpoints.upload {
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
                    self.receiveHTTPPayload(connection: connection, accumulatedData: buffer)
                    return
                }
                
                self.routeRequest(connection: connection, request: request)
            } else if buffer.count > 65536 {
                // Safeguard against unbounded slowloris header accumulation
                self.sendRawResponse(connection: connection, statusCode: 431, reason: "Request Header Fields Too Large", body: nil)
            } else if isComplete {
                connection.cancel()
            } else {
                // Continue accumulating headers
                self.receiveHTTPPayload(connection: connection, accumulatedData: buffer)
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
        
        let urlComponents = URLComponents(string: rawURL)
        let path = urlComponents?.path ?? rawURL
        var queryParams: [String: String] = [:]
        urlComponents?.queryItems?.forEach { item in
            queryParams[item.name] = item.value ?? ""
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
            remoteIP = "\(host)"
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
        guard let _ = try? JSONDecoder().decode(LocalShareRegisterDto.self, from: request.body) else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Bad Request", body: nil)
            return
        }
        
        let responseDto = LocalShareRegisterDto(
            alias: LocalShareSecurity.sanitizeAlias(serverAlias),
            fingerprint: LocalShareIdentityManager.shared.certificateFingerprint
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
        
        // 7. Acceptance Gate (Favorites or Interactive Prompt)
        let isFav = favoriteFingerprints.contains(prepareReq.info.fingerprint)
        if autoAcceptFavorites && isFav {
            session.transition(to: .accepted)
            let tokens = session.generateFileTokens()
            let resp = LocalSharePrepareUploadResponse(sessionId: sessionId, files: tokens)
            sendJSONResponse(connection: connection, statusCode: 200, value: resp)
            return
        }
        
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
            session.setActiveWriter(streamWriter)
            session.transition(to: .receiving)
        } catch {
            session.releaseTokenReservation(token: token)
            sendRawResponse(connection: connection, statusCode: 500, reason: "Disk Error", body: nil)
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
                streamWriter.abort()
                sendRawResponse(connection: connection, statusCode: 500, reason: "Write Error", body: nil)
                return
            }
        }
        
        if currentBytes >= expectedTotal {
            finalizeStreamAndRespond(connection: connection, session: session, fileId: fileId, token: token, writer: streamWriter, meta: meta)
            return
        }
        
        continueReceivingUpload(
            connection: connection,
            session: session,
            fileId: fileId,
            token: token,
            writer: streamWriter,
            meta: meta,
            expectedTotal: expectedTotal,
            receivedBytes: currentBytes
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
        receivedBytes: Int64
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            if error != nil {
                session.releaseTokenReservation(token: token)
                writer.abort()
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
                    writer.abort()
                    self.sendRawResponse(connection: connection, statusCode: 500, reason: "Write Error", body: nil)
                    return
                }
                
                if updatedBytes > expectedTotal {
                    session.releaseTokenReservation(token: token)
                    writer.abort()
                    self.sendRawResponse(connection: connection, statusCode: 400, reason: "Payload Exceeded", body: nil)
                    return
                }
            }
            
            if updatedBytes >= expectedTotal || isComplete {
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
                    receivedBytes: updatedBytes
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
            session.setActiveWriter(nil)
            sendRawResponse(connection: connection, statusCode: 200, reason: "OK", body: nil)
        } catch LocalShareError.checksumMismatch {
            session.releaseTokenReservation(token: token)
            writer.abort()
            session.markFileFailed(fileId: fileId, error: "Checksum Mismatch")
            session.setActiveWriter(nil)
            sendRawResponse(connection: connection, statusCode: 422, reason: "Unprocessable Entity", body: nil)
        } catch {
            session.releaseTokenReservation(token: token)
            writer.abort()
            session.markFileFailed(fileId: fileId, error: error.localizedDescription)
            session.setActiveWriter(nil)
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
        let info = LocalShareDeviceInfo(
            alias: LocalShareSecurity.sanitizeAlias(serverAlias),
            fingerprint: LocalShareIdentityManager.shared.certificateFingerprint
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
