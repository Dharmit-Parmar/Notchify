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
    
    private let lock = NSLock()
    private var isCancelled = false
    private var activeTask: URLSessionTask?
    
    public init(
        sessionId: String,
        peer: LocalShareDiscoveredPeer,
        fileTokens: [String: String],
        files: [URL]
    ) {
        self.sessionId = sessionId
        self.peer = peer
        self.fileTokens = fileTokens
        self.files = files
    }
    
    public func setActiveTask(_ task: URLSessionTask?) {
        lock.lock()
        defer { lock.unlock() }
        self.activeTask = task
    }
    
    public func markCancelled() {
        lock.lock()
        isCancelled = true
        let task = activeTask
        activeTask = nil
        lock.unlock()
        task?.cancel()
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
        
        // 1. Build file metadata map and precompute hashes
        var metadataMap: [String: LocalShareFileMetadata] = [:]
        for (index, url) in fileURLs.enumerated() {
            let fileId = "file-\(index + 1)-\(UUID().uuidString.prefix(6))"
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
            let size = Int64(values?.fileSize ?? 0)
            let mimeType = values?.contentType?.preferredMIMEType ?? "application/octet-stream"
            let sha256 = computeFileSHA256(url: url)
            
            metadataMap[fileId] = LocalShareFileMetadata(
                id: fileId,
                fileName: url.lastPathComponent,
                size: size,
                fileType: mimeType,
                sha256: sha256
            )
        }
        
        let myInfo = LocalShareDeviceInfo(
            alias: LocalShareSecurity.sanitizeAlias(localAlias),
            fingerprint: LocalShareIdentityManager.shared.certificateFingerprint,
            port: Int(LocalShareConstants.defaultHttpPort),
            protocol: "https"
        )
        
        let prepareReq = LocalSharePrepareUploadRequest(info: myInfo, files: metadataMap)
        let bodyData = try JSONEncoder().encode(prepareReq)
        
        // 2. Build URL with optional pin query parameter
        var urlComponents = URLComponents(string: "\(peer.`protocol`)://\(peer.host):\(peer.port)\(LocalShareEndpoints.prepareUpload)")
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
        request.timeoutInterval = 30.0
        
        // 3. Ephemeral URLSession with pinned peer certificate fingerprint
        let delegate = LocalSharePeerPinningDelegate(expectedFingerprint: peer.fingerprint)
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
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
                files: fileURLs
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
        guard var components = URLComponents(string: "\(peer.`protocol`)://\(peer.host):\(peer.port)\(LocalShareEndpoints.upload)") else {
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
        
        let delegate = LocalSharePeerPinningDelegate(expectedFingerprint: peer.fingerprint)
        let config = URLSessionConfiguration.ephemeral
        let urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { urlSession.finishTasksAndInvalidate() }
        
        let (data, response) = try await urlSession.upload(for: request, fromFile: fileURL)
        
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
    
    // MARK: - Cancellation Call
    
    /// Cancels an in-flight session with the peer.
    public func cancelSession(_ session: LocalShareClientSession) async {
        session.markCancelled()
        
        let peer = session.peer
        guard var components = URLComponents(string: "\(peer.`protocol`)://\(peer.host):\(peer.port)\(LocalShareEndpoints.cancel)") else {
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
private final class LocalSharePeerPinningDelegate: NSObject, URLSessionDelegate, Sendable {
    private let expectedFingerprint: String
    
    init(expectedFingerprint: String) {
        self.expectedFingerprint = expectedFingerprint
        super.init()
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
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
              let leafCert = certChain.first else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let certDER = SecCertificateCopyData(leafCert) as Data
        
        // 3. Verify SHA-256 certificate fingerprint matches peer discovery identity
        if LocalShareSecurity.isFingerprintValid(peerCertDER: certDER, expectedFingerprint: expectedFingerprint) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
