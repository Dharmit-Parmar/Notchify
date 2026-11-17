import Foundation
import Network
import CryptoKit
import Security

// MARK: - Outgoing Client Transfer Session State
public final class LocalShareClientSession: @unchecked Sendable {
    public let sessionId: String
    public let peer: LocalShareDiscoveredPeer
    public let fileTokens: [String: String]
    public let files: [URL]
    public let fileIdToURLMap: [String: URL]
    
    private let lock = NSLock()
    private var isCancelled = false
    private var activeTasks: Set<URLSessionTask> = []
    private var activeTask: URLSessionTask?
    
    public init(
        sessionId: String,
        peer: LocalShareDiscoveredPeer,
        fileTokens: [String: String],
        files: [URL],
        fileIdToURLMap: [String: URL] = [:]
    ) {
        self.sessionId = sessionId
        self.peer = peer
        self.fileTokens = fileTokens
        self.files = files
        self.fileIdToURLMap = fileIdToURLMap
    }
    
    public func url(for fileId: String) -> URL? {
        if let mapped = fileIdToURLMap[fileId] { return mapped }
        if fileId.hasPrefix("file-"), let dashIdx = fileId.dropFirst(5).firstIndex(of: "-") {
            let numStr = fileId[fileId.index(fileId.startIndex, offsetBy: 5)..<dashIdx]
            if let idx = Int(numStr), idx >= 1, idx <= files.count {
                return files[idx - 1]
            }
        }
        return nil
    }
    
    public func addActiveTask(_ task: URLSessionTask) {
        lock.lock()
        defer { lock.unlock() }
        if isCancelled {
            task.cancel()
        } else {
            activeTasks.insert(task)
            activeTask = task
        }
    }
    
    public func removeActiveTask(_ task: URLSessionTask) {
        lock.lock()
        defer { lock.unlock() }
        activeTasks.remove(task)
        if activeTask == task {
            activeTask = activeTasks.first
        }
    }
    
    public func setActiveTask(_ task: URLSessionTask?) {
        lock.lock()
        defer { lock.unlock() }
        self.activeTask = task
        if let t = task {
            if isCancelled {
                t.cancel()
            } else {
                activeTasks.insert(t)
            }
        }
    }
    
    public func markCancelled() {
        lock.lock()
        isCancelled = true
        let tasks = activeTasks
        activeTasks.removeAll()
        activeTask = nil
        lock.unlock()
        for task in tasks {
            task.cancel()
        }
    }
    
    public var cancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelled
    }
}

// MARK: - LocalShare Client Engine
public final class LocalShareClient: NSObject, @unchecked Sendable {
    public static let shared = LocalShareClient()
    
    public var localAlias: String = "MacBook"
    
    public override init() {
        super.init()
    }
    
    // MARK: - Prepare Upload Call
    
    /// Prepares a multi-file upload session with a peer.
    public func prepareUpload(
        to peer: LocalShareDiscoveredPeer,
        fileURLs: [URL],
        pin: String? = nil
    ) async throws -> (LocalShareClientSession, LocalSharePrepareUploadResponse) {
        guard !fileURLs.isEmpty else {
            throw LocalShareError.invalidBody
        }
        
        // Verify peer trust state before initiating transfer
        let trustState = LocalShareServer.shared.trustStatus(for: peer.fingerprint, alias: peer.alias)
        if trustState == .certificateChanged {
            throw LocalShareError.peerCertificateMismatch(
                expected: "Previously trusted identity certificate",
                found: peer.fingerprint
            )
        }
        if trustState == .blocked {
            throw LocalShareError.rejected
        }
        
        // 1. Build file metadata map and precompute hashes
        var metadataMap: [String: LocalShareFileMetadata] = [:]
        var idToURLMap: [String: URL] = [:]
        for (index, url) in fileURLs.enumerated() {
            let fileId = "file-\(index + 1)-\(UUID().uuidString.prefix(6))"
            idToURLMap[fileId] = url
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
            let size = Int64(values?.fileSize ?? 0)
            let mimeType = values?.contentType?.preferredMIMEType ?? "application/octet-stream"
            let sha256 = computeFileSHA256(url: url)
            
            var resolvedMimeType = mimeType
            if url.pathExtension.lowercased() == "txt" {
                resolvedMimeType = "text/plain"
            }
            
            var previewText: String? = nil
            if (resolvedMimeType.hasPrefix("text/") || url.pathExtension.lowercased() == "txt"), size <= 65536 {
                if let content = try? String(contentsOf: url, encoding: .utf8), !content.isEmpty {
                    previewText = String(content.prefix(4000))
                }
            }
            
            metadataMap[fileId] = LocalShareFileMetadata(
                id: fileId,
                fileName: url.lastPathComponent,
                size: size,
                fileType: resolvedMimeType,
                sha256: sha256,
                preview: previewText
            )
        }
        
        let myPort = Int(LocalShareDiscovery.shared.localPort)
        let myInfo = LocalShareDeviceInfo(
            alias: LocalShareSecurity.sanitizeAlias(localAlias),
            fingerprint: LocalShareIdentityManager.shared.certificateFingerprint,
            port: myPort,
            protocol: "https"
        )
        
        let prepareReq = LocalSharePrepareUploadRequest(info: myInfo, files: metadataMap)
        let bodyData = try JSONEncoder().encode(prepareReq)
        
        // 2. Build URL with optional pin query parameter
        let cleanHost = LocalShareSecurity.formatHostForURL(peer.host)
        var urlComponents = URLComponents(string: "\(peer.`protocol`)://\(cleanHost):\(peer.port)\(LocalShareEndpoints.prepareUpload)")
        if let pin = pin, !pin.isEmpty {
            urlComponents?.queryItems = [URLQueryItem(name: "pin", value: pin)]
        }
        guard let targetURL = urlComponents?.url else {
            throw LocalShareError.invalidURL
        }
        
        var request = URLRequest(url: targetURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 180.0
        
        // 3. Ephemeral URLSession with pinned peer certificate fingerprint
        let delegate = LocalSharePeerPinningDelegate(expectedFingerprint: peer.fingerprint)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 180.0
        config.timeoutIntervalForResource = 180.0
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw LocalShareError.sessionCancelled
        } catch let urlErr as URLError where urlErr.code == .cancelled {
            throw LocalShareError.sessionCancelled
        } catch let urlErr as URLError where urlErr.code == .timedOut {
            throw LocalShareError.connectionFailed("Recipient took too long to respond (timed out)")
        } catch {
            let nsError = error as NSError
            NSLog("[LocalShareClient] prepareUpload failed to %@:%d%@ Domain: %@ Code: %ld Description: %@", cleanHost, peer.port, LocalShareEndpoints.prepareUpload, nsError.domain, Int(nsError.code), nsError.localizedDescription)
            let scrubbed = LocalShareSecurity.scrubSecrets(from: error.localizedDescription)
            throw LocalShareError.connectionFailed(scrubbed)
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw LocalShareError.connectionFailed("No HTTP response")
        }
        
        switch http.statusCode {
        case 200:
            let resp = try JSONDecoder().decode(LocalSharePrepareUploadResponse.self, from: data)
            let clientSession = LocalShareClientSession(
                sessionId: resp.sessionId,
                peer: peer,
                fileTokens: resp.files,
                files: fileURLs,
                fileIdToURLMap: idToURLMap
            )
            return (clientSession, resp)
        case 204:
            // No file transfer needed (0 files accepted)
            let emptyResp = LocalSharePrepareUploadResponse(sessionId: "", files: [:])
            let emptySession = LocalShareClientSession(sessionId: "", peer: peer, fileTokens: [:], files: [])
            return (emptySession, emptyResp)
        case 401:
            throw LocalShareError.pinRequired
        case 403:
            throw LocalShareError.rejected
        case 409:
            throw LocalShareError.blockedByAnotherSession
        case 429:
            throw LocalShareError.rateLimited
        default:
            throw LocalShareError.serverError("Prepare upload failed with HTTP \(http.statusCode)")
        }
    }
    
    // MARK: - File Streaming Upload Call
    
    /// Uploads a single file stream within an established session.
    public func uploadFile(
        session: LocalShareClientSession,
        fileURL: URL,
        fileId: String,
        token: String,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        guard !session.cancelled else {
            throw LocalShareError.sessionCancelled
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw LocalShareError.serverError("Source file not found at \(fileURL.lastPathComponent)")
        }
        
        let peer = session.peer
        let cleanHost = LocalShareSecurity.formatHostForURL(peer.host)
        guard var components = URLComponents(string: "\(peer.`protocol`)://\(cleanHost):\(peer.port)\(LocalShareEndpoints.upload)") else {
            throw LocalShareError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "sessionId", value: session.sessionId),
            URLQueryItem(name: "fileId", value: fileId),
            URLQueryItem(name: "token", value: token)
        ]
        guard let uploadURL = components.url else {
            throw LocalShareError.invalidURL
        }
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300.0 // 5 minutes per file
        
        let delegate = LocalSharePeerPinningDelegate(expectedFingerprint: peer.fingerprint, onProgress: onProgress)
        let config = URLSessionConfiguration.ephemeral
        let urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { urlSession.finishTasksAndInvalidate() }
        
        var uploadTask: URLSessionUploadTask?
        defer {
            if let t = uploadTask {
                session.removeActiveTask(t)
            }
        }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    let task = urlSession.uploadTask(with: request, fromFile: fileURL) { data, response, error in
                        if let error = error {
                            let nsError = error as NSError
                            NSLog("[LocalShareClient] uploadFile failed for file %@ Domain: %@ Code: %ld Description: %@", fileId, nsError.domain, Int(nsError.code), nsError.localizedDescription)
                            continuation.resume(throwing: error)
                        } else if let data = data, let response = response {
                            continuation.resume(returning: (data, response))
                        } else {
                            continuation.resume(throwing: LocalShareError.connectionFailed("No HTTP response"))
                        }
                    }
                    uploadTask = task
                    session.addActiveTask(task)
                    task.resume()
                }
            } onCancel: {
                uploadTask?.cancel()
            }
        } catch is CancellationError {
            throw LocalShareError.sessionCancelled
        } catch let urlErr as URLError where urlErr.code == .cancelled {
            throw LocalShareError.sessionCancelled
        } catch {
            let nsError = error as NSError
            NSLog("[LocalShareClient] uploadFile caught error for file %@ Domain: %@ Code: %ld Description: %@", fileId, nsError.domain, Int(nsError.code), nsError.localizedDescription)
            throw error
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw LocalShareError.connectionFailed("No HTTP response")
        }
        
        switch http.statusCode {
        case 200:
            onProgress?(1.0)
            return
        case 403:
            throw LocalShareError.tokenMismatch
        case 409:
            throw LocalShareError.blockedByAnotherSession
        case 422:
            throw LocalShareError.checksumMismatch
        default:
            let bodyMsg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw LocalShareError.serverError(LocalShareSecurity.scrubSecrets(from: bodyMsg))
        }
    }
    
    // MARK: - Controlled Parallel File Uploads
    
    private final class UploadProgressAccumulator: @unchecked Sendable {
        private let lock = NSLock()
        private var transferredBytesMap: [String: Int64] = [:]
        private let totalBytesMap: [String: Int64]
        let aggregateTotal: Int64
        
        init(totalBytesMap: [String: Int64]) {
            self.totalBytesMap = totalBytesMap
            self.aggregateTotal = totalBytesMap.values.reduce(Int64(0), +)
            for (k, _) in totalBytesMap {
                transferredBytesMap[k] = 0
            }
        }
        
        func update(fileId: String, fraction: Double) -> Double {
            lock.lock()
            defer { lock.unlock() }
            let fileSize = totalBytesMap[fileId] ?? 0
            transferredBytesMap[fileId] = Int64(Double(fileSize) * fraction)
            let currentOverall = transferredBytesMap.values.reduce(Int64(0), +)
            return aggregateTotal > 0 ? min(1.0, max(0.0, Double(currentOverall) / Double(aggregateTotal))) : 1.0
        }
    }
    
    /// Streams all files in the session with controlled parallelism (default concurrency limit = 2)
    /// and reports smooth, aggregated overall progress across all files.
    public func uploadFiles(
        session: LocalShareClientSession,
        prepResp: LocalSharePrepareUploadResponse,
        maxConcurrency: Int = 2,
        onOverallProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        let filesList = Array(prepResp.files)
        guard !filesList.isEmpty else { return }
        
        var totalBytesMap: [String: Int64] = [:]
        for (fileId, _) in filesList {
            if let fileURL = session.url(for: fileId),
               let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalBytesMap[fileId] = Int64(size)
            } else {
                totalBytesMap[fileId] = 0
            }
        }
        
        let accumulator = UploadProgressAccumulator(totalBytesMap: totalBytesMap)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            var submitted = 0
            let limit = max(1, min(maxConcurrency, 4))
            
            for (fileId, token) in filesList {
                guard let fileURL = session.url(for: fileId) else {
                    throw LocalShareError.serverError("Missing file URL mapping for fileId: \(fileId)")
                }
                
                if submitted >= limit {
                    try await group.next()
                }
                
                group.addTask {
                    try await self.uploadFile(
                        session: session,
                        fileURL: fileURL,
                        fileId: fileId,
                        token: token
                    ) { fileFraction in
                        let overallFrac = accumulator.update(fileId: fileId, fraction: fileFraction)
                        onOverallProgress?(overallFrac)
                    }
                }
                submitted += 1
            }
            
            while try await group.next() != nil {}
        }
        
        onOverallProgress?(1.0)
    }
    
    // MARK: - Cancellation Call
    
    /// Cancels an in-flight session with the peer.
    public func cancelSession(_ session: LocalShareClientSession) async {
        session.markCancelled()
        
        let peer = session.peer
        let cleanHost = LocalShareSecurity.formatHostForURL(peer.host)
        guard var components = URLComponents(string: "\(peer.`protocol`)://\(cleanHost):\(peer.port)\(LocalShareEndpoints.cancel)") else {
            return
        }
        components.queryItems = [URLQueryItem(name: "sessionId", value: session.sessionId)]
        guard let cancelURL = components.url else { return }
        
        var request = URLRequest(url: cancelURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 5.0
        
        let delegate = LocalSharePeerPinningDelegate(expectedFingerprint: peer.fingerprint)
        let config = URLSessionConfiguration.ephemeral
        let urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        _ = try? await urlSession.data(for: request)
        urlSession.finishTasksAndInvalidate()
    }
    
    // MARK: - SHA-256 Checksum Computation
    
    private func computeFileSHA256(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 65536)
            if chunk.isEmpty {
                return false
            }
            hasher.update(data: chunk)
            return true
        }) {}
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Peer Certificate Fingerprint Pinning URLSessionDelegate
public final class LocalSharePeerPinningDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, Sendable {
    public let expectedFingerprint: String
    private let onProgress: (@Sendable (Double) -> Void)?
    
    public init(expectedFingerprint: String, onProgress: (@Sendable (Double) -> Void)? = nil) {
        self.expectedFingerprint = expectedFingerprint
        self.onProgress = onProgress
        super.init()
    }
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = min(1.0, max(0.0, Double(totalBytesSent) / Double(totalBytesExpectedToSend)))
        onProgress?(fraction)
    }
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Disallow all peer-supplied HTTP redirects (LocalSend security requirement)
        completionHandler(nil)
    }
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleAuthenticationChallenge(challenge, completionHandler: completionHandler)
    }
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleAuthenticationChallenge(challenge, completionHandler: completionHandler)
    }
    
    private func handleAuthenticationChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        NSLog("[LocalShareClient] Auth challenge received for method: %@", challenge.protectionSpace.authenticationMethod)
        // Provide our own identity for mutual TLS client certificate challenges
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            if let identity = LocalShareIdentityManager.shared.getSecIdentity() {
                NSLog("[LocalShareClient] Providing local identity for client certificate challenge")
                let credential = URLCredential(identity: identity, certificates: nil, persistence: .forSession)
                completionHandler(.useCredential, credential)
            } else {
                NSLog("[LocalShareClient] No local identity available for client certificate challenge")
                completionHandler(.performDefaultHandling, nil)
            }
            return
        }
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // 1. Evaluate trust to extract certificates
        var secError: CFError?
        _ = SecTrustEvaluateWithError(serverTrust, &secError)
        
        // 2. Extract leaf certificate
        guard let certChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let leaf = certChain.first else {
            NSLog("[LocalShareClient] Failed to extract leaf certificate from SecTrust (error=%@)", String(describing: secError))
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let certDER = SecCertificateCopyData(leaf) as Data
        let digest = SHA256.hash(data: certDER)
        let actualHex = digest.map { String(format: "%02x", $0) }.joined()
        
        NSLog("[LocalShareClient] Comparing peer certificate fingerprint. Expected: %@, Actual: %@", expectedFingerprint, actualHex)
        
        // 3. Verify SHA-256 certificate fingerprint matches peer discovery identity (fail closed)
        if !expectedFingerprint.isEmpty && LocalShareSecurity.isFingerprintValid(peerCertDER: certDER, expectedFingerprint: expectedFingerprint) {
            NSLog("[LocalShareClient] Fingerprint matched. Accepting peer server trust.")
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            NSLog("[LocalShareClient] Peer certificate fingerprint mismatch! Expected: %@, Actual: %@", expectedFingerprint, actualHex)
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
