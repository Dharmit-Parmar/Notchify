import Foundation
import Network
import CryptoKit
import Security

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
    /// Verified peer certificate fingerprint (SHA-256 hex) captured from the
    /// completed TLS handshake, or nil when no peer certificate was presented
    /// / TLS is disabled. Only this value is used for trust decisions.
    let verifiedPeerFingerprint: String?
}

// MARK: - HTTPS LocalShare Server (NWListener-based)
public final class LocalShareServer: @unchecked Sendable {
    public static let shared = LocalShareServer()

    private let lock = NSLock()
    private var listener: NWListener?
    private var state: LocalShareServerState = .stopped
    private let queue = DispatchQueue(label: "com.notch.LocalShare.Server", qos: .userInitiated)

    private var _serverAlias: String = "MacBook"
    public var serverAlias: String {
        get { lock.lock(); defer { lock.unlock() }; return _serverAlias }
        set { lock.lock(); _serverAlias = newValue; lock.unlock() }
    }

    private var _requiredPin: String? = nil
    public var requiredPin: String? {
        get { lock.lock(); defer { lock.unlock() }; return _requiredPin }
        set { lock.lock(); _requiredPin = newValue; lock.unlock() }
    }

    private var _autoAcceptFavorites: Bool = false
    public var autoAcceptFavorites: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _autoAcceptFavorites }
        set { lock.lock(); _autoAcceptFavorites = newValue; lock.unlock() }
    }

    private var _favoriteFingerprints: Set<String> = []
    public var favoriteFingerprints: Set<String> {
        get { lock.lock(); defer { lock.unlock() }; return _favoriteFingerprints }
        set {
            lock.lock()
            _favoriteFingerprints = Set(newValue.map { $0.lowercased() })
            lock.unlock()
        }
    }

    private var _isTestHarnessAutoAcceptEnabled: Bool = false
    public var isTestHarnessAutoAcceptEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isTestHarnessAutoAcceptEnabled }
        set { lock.lock(); _isTestHarnessAutoAcceptEnabled = newValue; lock.unlock() }
    }

    private var _sharedFiles: [URL] = []
    public var sharedDownloadFiles: [URL] {
        get { lock.lock(); defer { lock.unlock() }; return _sharedFiles }
        set { lock.lock(); _sharedFiles = newValue; lock.unlock() }
    }

    private let trustLock = NSLock()
    private var _trustedPeers: [String: LocalShareTrustedPeer] = [:]
    public var trustedPeers: [String: LocalShareTrustedPeer] {
        get { trustLock.lock(); defer { trustLock.unlock() }; return _trustedPeers }
        set { trustLock.lock(); _trustedPeers = newValue; trustLock.unlock() }
    }

    public func trustStatus(for fingerprint: String, alias: String?) -> LocalSharePeerTrustState {
        trustLock.lock()
        defer { trustLock.unlock() }

        // An empty fingerprint is the marker we store for "peer presented no
        // certificate". It must never match a populated trust record.
        if fingerprint.isEmpty {
            return .unverifiedFirstContact
        }

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

    // Per-connection verified peer certificate fingerprint.
    private var verifiedPeerFingerprints: [ObjectIdentifier: String] = [:]

    private func setVerifiedPeerFingerprint(_ fp: String?, for connection: NWConnection) {
        lock.lock()
        defer { lock.unlock() }
        let id = ObjectIdentifier(connection)
        if let fp = fp {
            verifiedPeerFingerprints[id] = fp
        } else {
            verifiedPeerFingerprints.removeValue(forKey: id)
        }
    }

    private func verifiedPeerFingerprint(for connection: NWConnection) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return verifiedPeerFingerprints[ObjectIdentifier(connection)]
    }

    private func clearVerifiedPeerFingerprint(for connection: NWConnection) {
        lock.lock()
        defer { lock.unlock() }
        verifiedPeerFingerprints.removeValue(forKey: ObjectIdentifier(connection))
    }

    // FIX: `sec_protocol_metadata_copy_peer_certificate` is not public API.
    // Use the public `sec_protocol_metadata_access_peer_certificate_chain`
    // and take the leaf certificate (first in the chain).
    private func captureVerifiedPeerFingerprint(
        _ connection: NWConnection
    ) -> String? {

        guard let tlsMetadata = connection.metadata(
            definition: NWProtocolTLS.definition
        ) as? NWProtocolTLS.Metadata else {
            return nil
        }

        let metadata = tlsMetadata.securityProtocolMetadata
        var fingerprint: String?

        let accessible = sec_protocol_metadata_access_peer_certificate_chain(
            metadata
        ) { peerCertificate in
            guard fingerprint == nil else { return }
            // NOTE / WHY THIS IS RUNNING NOW:
            // Previously had forced cast `as! SecCertificate` which gave warning:
            // "warning: forced cast of 'SecCertificate' to same type has no effect".
            let certificate = sec_certificate_copy_ref(peerCertificate).takeRetainedValue()
            let certificateDER = SecCertificateCopyData(certificate) as Data
            let digest = SHA256.hash(data: certificateDER)
            fingerprint = digest.map { String(format: "%02x", $0) }.joined()
        }

        guard accessible else {
            NSLog("[LocalShareServer] Peer certificate chain access denied by TLS metadata")
            return nil
        }
        return fingerprint
    }

    private var _onIncomingSessionOffered: (@Sendable (LocalShareSession, @escaping @Sendable (Bool) -> Void) -> Void)?
    public var onIncomingSessionOffered: (@Sendable (LocalShareSession, @escaping @Sendable (Bool) -> Void) -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return _onIncomingSessionOffered }
        set { lock.lock(); _onIncomingSessionOffered = newValue; lock.unlock() }
    }

    private var _onStateChanged: (@Sendable (LocalShareServerState) -> Void)?
    public var onStateChanged: (@Sendable (LocalShareServerState) -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return _onStateChanged }
        set { lock.lock(); _onStateChanged = newValue; lock.unlock() }
    }

    private var stateObservers: [UUID: @Sendable (LocalShareServerState) -> Void] = [:]

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
        activeConnections[ObjectIdentifier(connection)] = connection
    }

    private func removeActiveConnection(_ connection: NWConnection) {
        lock.lock()
        defer { lock.unlock() }
        activeConnections.removeValue(forKey: ObjectIdentifier(connection))
        verifiedPeerFingerprints.removeValue(forKey: ObjectIdentifier(connection))
    }

    private struct FailedPinState {
        var failCount: Int = 0
        var lockoutUntil: Date? = nil
        var lastAttempt: Date = Date()
    }
    private var failedPinAttemptsByIP: [String: FailedPinState] = [:]

    private let maxFailedPinEntries = 1024
    private let failedPinEntryMaxAge: TimeInterval = 60 * 60

    private func pruneFailedPinStateLocked(now: Date = Date()) {
        var staleKeys: [String] = []
        for (ip, state) in failedPinAttemptsByIP {
            if let lockoutUntil = state.lockoutUntil {
                if lockoutUntil > now { continue }
            }
            if now.timeIntervalSince(state.lastAttempt) > failedPinEntryMaxAge {
                staleKeys.append(ip)
            }
        }
        for key in staleKeys {
            failedPinAttemptsByIP.removeValue(forKey: key)
        }
        if failedPinAttemptsByIP.count > maxFailedPinEntries {
            let sorted = failedPinAttemptsByIP.sorted { $0.value.lastAttempt < $1.value.lastAttempt }
            let toRemove = failedPinAttemptsByIP.count - maxFailedPinEntries
            for (ip, _) in sorted.prefix(toRemove) {
                failedPinAttemptsByIP.removeValue(forKey: ip)
            }
        }
    }

    public var currentActiveConnections: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeConnectionCount
    }

    private func isLoopbackAddress(_ normalizedIP: String) -> Bool {
        return normalizedIP == "127.0.0.1"
            || normalizedIP == "::1"
            || normalizedIP.hasPrefix("127.")
    }

    private func incrementConnectionCount(for clientIP: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if activeConnectionCount >= LocalShareSecurity.maxSimultaneousConnections {
            return false
        }
        let normIP = LocalShareSecurity.normalizeIP(clientIP)
        let ipLimit = isLoopbackAddress(normIP)
            ? LocalShareSecurity.maxConnectionsPerLoopback
            : LocalShareSecurity.maxConnectionsPerIP
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
        pruneFailedPinStateLocked()
        return (delay, lockedOut)
    }

    private func recordSuccessfulPinAttempt(clientIP: String) {
        lock.lock()
        defer { lock.unlock() }
        let normIP = LocalShareSecurity.normalizeIP(clientIP)
        failedPinAttemptsByIP.removeValue(forKey: normIP)
    }

    private func authorizePIN(
        connection: NWConnection,
        request: LocalShareHTTPRequest
    ) -> Bool {
        guard let required = requiredPin, !required.isEmpty else {
            return true
        }

        let lockout = checkPinLockout(clientIP: request.remoteIP)
        if lockout.isLockedOut {
            sendRawResponse(
                connection: connection,
                statusCode: 429,
                reason: "Too Many Requests",
                body: "PIN lockout active. Retry in \(lockout.retryAfterSeconds) seconds.".data(using: .utf8),
                headers: ["Retry-After": "\(lockout.retryAfterSeconds)"]
            )
            return false
        }

        guard let provided = request.queryParams["pin"],
              constantTimePINCompare(provided, required) else {
            let failure = recordFailedPinAttempt(clientIP: request.remoteIP)
            let responseStatus = failure.isLockedOutNow ? 429 : 401
            let responseReason = failure.isLockedOutNow ? "Too Many Requests" : "Unauthorized"
            let retry = failure.isLockedOutNow
                ? checkPinLockout(clientIP: request.remoteIP).retryAfterSeconds
                : 0

            let sendFailure: @Sendable () -> Void = { [weak self, weak connection] in
                guard let self = self, let connection = connection else { return }
                self.sendRawResponse(
                    connection: connection,
                    statusCode: responseStatus,
                    reason: responseReason,
                    body: responseStatus == 429
                        ? "PIN lockout active. Retry in \(retry) seconds.".data(using: .utf8)
                        : nil,
                    headers: retry > 0 ? ["Retry-After": "\(retry)"] : [:]
                )
            }

            if failure.delaySeconds > 0 {
                queue.asyncAfter(deadline: .now() + failure.delaySeconds, execute: sendFailure)
            } else {
                sendFailure()
            }
            return false
        }

        recordSuccessfulPinAttempt(clientIP: request.remoteIP)
        return true
    }

    static func generateSessionId() -> String {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { raw in
            raw.map { String(format: "%02x", $0) }.joined()
        }
    }

    private func constantTimeStringCompare(_ lhs: String, _ rhs: String) -> Bool {
        let leftDigest = SHA256.hash(data: Data(lhs.utf8))
        let rightDigest = SHA256.hash(data: Data(rhs.utf8))
        var difference: UInt8 = 0
        for (l, r) in zip(leftDigest, rightDigest) {
            difference |= l ^ r
        }
        return difference == 0
    }

    private func constantTimePINCompare(_ lhs: String, _ rhs: String) -> Bool {
        constantTimeStringCompare(lhs, rhs)
    }

    private func htmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func contentDispositionValue(for fileName: String) -> String {
        let fallback = fileName.unicodeScalars.map { scalar -> String in
            let value = scalar.value
            guard value >= 0x20, value <= 0x7E, value != 0x22, value != 0x5C else {
                return "_"
            }
            return String(scalar)
        }.joined()

        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$&+-.^_`|~"
        )
        let encoded = fileName.addingPercentEncoding(withAllowedCharacters: allowed) ?? "unnamed_file"
        return "attachment; filename=\"\(fallback)\"; filename*=UTF-8''\(encoded)"
    }

    public func simulateFailedPinAttempt(clientIP: String) -> (delaySeconds: Double, isLockedOutNow: Bool) {
        return recordFailedPinAttempt(clientIP: clientIP)
    }

    public func checkPinLockoutForTest(clientIP: String) -> (isLockedOut: Bool, retryAfterSeconds: Int) {
        return checkPinLockout(clientIP: clientIP)
    }

    public func recordSuccessfulPinAttemptForTest(clientIP: String) {
        recordSuccessfulPinAttempt(clientIP: clientIP)
    }

    public func clearPinLockoutForTest(clientIP: String) {
        lock.lock()
        defer { lock.unlock() }
        let normIP = LocalShareSecurity.normalizeIP(clientIP)
        failedPinAttemptsByIP.removeValue(forKey: normIP)
    }

    private init() {}

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

    // FIX: use `sec_protocol_options_set_peer_authentication_optional(...true)`
    // which requests a client certificate. Previously we used
    // `set_peer_authentication_required(..., false)`, which only disabled the
    // requirement and never asked the peer for a certificate — so
    // `captureVerifiedPeerFingerprint` always returned nil.
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
            let tlsOptions = NWProtocolTLS.Options()
            sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)

            // NOTE / WHY THIS IS RUNNING NOW (Error Fix):
            // The previous line was:
            //   sec_protocol_options_set_peer_authentication_optional(tlsOptions.securityProtocolOptions, true)
            // Error produced:
            //   "error: 'sec_protocol_options_set_peer_authentication_optional' is unavailable in macOS
            //    note: 'sec_protocol_options_set_peer_authentication_optional' has been explicitly marked unavailable here API_UNAVAILABLE(macos, ios, watchos, tvos)"
            // In Apple's Network framework, server TLS endpoints default to not requiring peer authentication
            // (sec_protocol_options_set_peer_authentication_required defaults to false for servers), while still allowing
            // sec_protocol_metadata_access_peer_certificate_chain to inspect the peer certificate when present.

            guard let networkIdentity = LocalShareIdentityManager.shared.createNetworkIdentity() else {
                let message = "Failed to create TLS identity (self-signed cert unavailable)"
                self.state = .failed(message)
                NSLog("[LocalShareServer] CRITICAL: %@", message)
                throw LocalShareError.serverError(message)
            }
            sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, networkIdentity)

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

        let requestedPort = NWEndpoint.Port(rawValue: port) ?? .any
        let newListener: NWListener
        do {
            newListener = try NWListener(using: params, on: requestedPort)
        } catch {
            self.state = .failed(error.localizedDescription)
            throw error
        }

        newListener.stateUpdateHandler = { [weak self] newState in
            self?.handleListenerStateUpdate(newState)
        }
        newListener.newConnectionHandler = { [weak self] newConnection in
            self?.handleIncomingConnection(newConnection)
        }

        self.listener = newListener
        newListener.start(queue: queue)
    }

    public func stop() {
        lock.lock()
        let activeListener = self.listener
        self.listener = nil
        self.state = .stopped
        self.activeConnectionCount = 0
        self.activeConnectionsByIP.removeAll()
        verifiedPeerFingerprints.removeAll()
        let connsToCancel = Array(activeConnections.values)
        activeConnections.removeAll()
        let callback = _onStateChanged
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

    public func restart(port: UInt16) {
        stop()
        do {
            try start(port: port)
        } catch {
            NSLog("[LocalShareServer] Failed to restart server on port %d: %@", port, error.localizedDescription)
        }
    }

    private func handleListenerStateUpdate(_ newState: NWListener.State) {
        var reportedState: LocalShareServerState
        var previousState: LocalShareServerState
        var actualPort: UInt16?

        lock.lock()
        previousState = self.state
        switch newState {
        case .ready:
            let port = listener?.port?.rawValue ?? 0
            self.state = .running(port: port)
            actualPort = port
        case .failed(let error):
            self.state = .failed(error.localizedDescription)
            self.listener?.cancel()
            self.listener = nil
        case .cancelled:
            self.state = .stopped
            self.listener = nil
        default:
            lock.unlock()
            return
        }
        reportedState = self.state
        let callback = _onStateChanged
        let observers = Array(stateObservers.values)
        lock.unlock()

        if let port = actualPort, port > 0 {
            LocalShareDiscovery.shared.localPort = port
        }
        if reportedState == previousState { return }

        callback?(reportedState)
        for obs in observers {
            obs(reportedState)
        }
    }

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

    private final class LocalShareCycleGuard: @unchecked Sendable {
        private let lock = NSLock()
        private var claimed = false
        func testAndClaim() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if claimed { return false }
            claimed = true
            return true
        }
    }

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

    private final class HTTPChunkDecoder: @unchecked Sendable {
        private enum State {
            case readingSize
            case readingData(remaining: Int)
            case readingCRLF
            case readingTrailers
            case finished
        }

        private static let maxSizeLineBytes = 1024
        private static let maxChunkSizeBytes = 64 * 1024 * 1024
        private static let maxTrailerBytes = 8 * 1024

        private var state: State = .readingSize
        private var buffer = Data()
        private var trailerBytesRead = 0
        private(set) var isFinished: Bool = false

        func feed(_ rawData: Data) throws -> Data {
            buffer.append(rawData)
            var output = Data()

            while !buffer.isEmpty && !isFinished {
                switch state {
                case .readingSize:
                    guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
                        if buffer.count > Self.maxSizeLineBytes {
                            throw LocalShareError.serverError("Chunk size line too long")
                        }
                        return output
                    }
                    guard newlineIndex > buffer.startIndex,
                          buffer[buffer.index(before: newlineIndex)] == 0x0D else {
                        throw LocalShareError.serverError("Chunk size line not terminated by CRLF")
                    }
                    var sizeLineData = buffer.subdata(in: buffer.startIndex..<newlineIndex)
                    sizeLineData.removeLast()
                    buffer.removeSubrange(buffer.startIndex...newlineIndex)

                    guard let lineStr = String(data: sizeLineData, encoding: .ascii) else {
                        throw LocalShareError.serverError("Invalid chunk size encoding")
                    }
                    let cleanLine = lineStr.trimmingCharacters(in: .whitespaces)
                    if cleanLine.isEmpty { continue }
                    let sizeHex = cleanLine.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces) ?? ""
                    guard !sizeHex.isEmpty,
                          sizeHex.allSatisfy({ $0.isHexDigit }),
                          let chunkSize = Int(sizeHex, radix: 16) else {
                        throw LocalShareError.serverError("Malformed chunk size hex: \(cleanLine)")
                    }
                    guard chunkSize >= 0 else {
                        throw LocalShareError.serverError("Negative chunk size")
                    }
                    guard chunkSize <= Self.maxChunkSizeBytes else {
                        throw LocalShareError.serverError("Chunk size exceeds maximum")
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
                    guard buffer.count >= 2 else {
                        return output
                    }
                    let firstTwo = buffer.prefix(2)
                    guard firstTwo.elementsEqual([0x0D, 0x0A]) else {
                        throw LocalShareError.serverError("Chunk data not followed by CRLF")
                    }
                    buffer.removeFirst(2)
                    state = .readingSize

                case .readingTrailers:
                    guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
                        if buffer.count > Self.maxTrailerBytes - trailerBytesRead {
                            throw LocalShareError.serverError("Trailer section too large")
                        }
                        return output
                    }
                    let lineLength = buffer.distance(from: buffer.startIndex, to: newlineIndex) + 1
                    trailerBytesRead += lineLength
                    guard trailerBytesRead <= Self.maxTrailerBytes else {
                        throw LocalShareError.serverError("Trailer section too large")
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

        func requireTerminated() throws {
            guard isFinished else {
                throw LocalShareError.serverError("Chunked transfer did not terminate")
            }
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
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .setup:
                NSLog("[LocalShareServer] Connection to %@ setup", endpointDesc)
            case .preparing:
                NSLog("[LocalShareServer] Connection to %@ preparing (TLS/handshake)", endpointDesc)
            case .ready:
                NSLog("[LocalShareServer] Connection to %@ ready", endpointDesc)
                if let self = self, let conn = connection as NWConnection? {
                    let fp = self.captureVerifiedPeerFingerprint(conn)
                    self.setVerifiedPeerFingerprint(fp, for: conn)
                    NSLog("[LocalShareServer] Peer fingerprint for %@: %@", endpointDesc, fp ?? "<none>")
                }
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

        let headerDeadline = Date().addingTimeInterval(15.0)
        let timeoutWorkItem = DispatchWorkItem { [weak connection] in
            if let conn = connection {
                NSLog("[LocalShareServer] Pre-header watchdog timed out for %@", "\(conn.endpoint)")
                conn.cancel()
            }
        }
        let box = LocalShareTimeoutBox(timeoutWorkItem)
        queue.asyncAfter(deadline: .now() + 15.0, execute: timeoutWorkItem)

        receiveHTTPPayload(
            connection: connection,
            accumulatedData: Data(),
            headerTimeoutBox: box,
            headerDeadline: headerDeadline,
            bodyDeadline: nil
        )
    }

    private func receiveHTTPPayload(
        connection: NWConnection,
        accumulatedData: Data,
        headerTimeoutBox: LocalShareTimeoutBox?,
        headerDeadline: Date,
        bodyDeadline: Date?
    ) {
        if Date() > headerDeadline {
            headerTimeoutBox?.cancel()
            connection.cancel()
            return
        }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                NSLog("[LocalShareServer] HTTP receive error from %@: %@", "\(connection.endpoint)", String(describing: error))
                headerTimeoutBox?.cancel()
                connection.cancel()
                return
            }

            var buffer = accumulatedData
            if let content = content {
                buffer.append(content)
            }

            let crlfDelimiter = Data("\r\n\r\n".utf8)
            let lfDelimiter = Data("\n\n".utf8)
            var headerEndRange: Range<Data.Index>?
            var lineDelimiter = "\r\n"
            if let crlfRange = buffer.range(of: crlfDelimiter) {
                headerEndRange = crlfRange
                lineDelimiter = "\r\n"
            } else if let lfRange = buffer.range(of: lfDelimiter) {
                headerEndRange = lfRange
                lineDelimiter = "\n"
            }

            if let headerEndRange = headerEndRange {
                headerTimeoutBox?.cancel()
                let headerData = buffer.subdata(in: 0..<headerEndRange.lowerBound)
                let bodyData = buffer.subdata(in: headerEndRange.upperBound..<buffer.count)

                guard let request = self.parseHTTPRequest(
                    headerData: headerData,
                    bodyData: bodyData,
                    lineDelimiter: lineDelimiter,
                    connection: connection
                ) else {
                    self.sendRawResponse(connection: connection, statusCode: 400, reason: "Bad Request", body: nil)
                    return
                }

                if !self.rateLimiter.isAllowed(ip: request.remoteIP) {
                    self.sendRawResponse(connection: connection, statusCode: 429, reason: "Too Many Requests", body: nil)
                    return
                }

                if request.path == LocalShareEndpoints.upload || request.path.hasPrefix(LocalShareEndpoints.upload) {
                    self.handleUploadRoute(connection: connection, request: request, initialBody: bodyData)
                    return
                }

                let expectedLength = Int(request.headers["content-length"] ?? "0") ?? 0
                if expectedLength > LocalShareSecurity.maxRequestBodySize {
                    self.sendRawResponse(connection: connection, statusCode: 413, reason: "Payload Too Large", body: nil)
                    return
                }

                if bodyData.count < expectedLength {
                    if isComplete {
                        self.sendRawResponse(connection: connection, statusCode: 400, reason: "Bad Request", body: nil)
                        return
                    }

                    let effectiveDeadline = bodyDeadline ?? Date().addingTimeInterval(15.0)
                    let remaining = effectiveDeadline.timeIntervalSinceNow
                    if remaining <= 0 {
                        NSLog("[LocalShareServer] Body deadline exceeded for %@", "\(connection.endpoint)")
                        connection.cancel()
                        return
                    }

                    let targetConnection = connection
                    let bodyTimeoutItem = DispatchWorkItem { [weak targetConnection] in
                        if let conn = targetConnection {
                            NSLog("[LocalShareServer] Body receive watchdog timed out for %@", "\(conn.endpoint)")
                            conn.cancel()
                        }
                    }
                    let bodyBox = LocalShareTimeoutBox(bodyTimeoutItem)
                    self.queue.asyncAfter(deadline: .now() + remaining, execute: bodyTimeoutItem)

                    self.receiveHTTPPayload(
                        connection: connection,
                        accumulatedData: buffer,
                        headerTimeoutBox: bodyBox,
                        headerDeadline: headerDeadline,
                        bodyDeadline: effectiveDeadline
                    )
                    return
                }

                self.routeRequest(connection: connection, request: request)
            } else if buffer.count > LocalShareSecurity.maxHeaderSize {
                headerTimeoutBox?.cancel()
                self.sendRawResponse(connection: connection, statusCode: 431, reason: "Request Header Fields Too Large", body: nil)
            } else if isComplete {
                NSLog("[LocalShareServer] Connection closed by peer before complete HTTP headers from %@", "\(connection.endpoint)")
                headerTimeoutBox?.cancel()
                connection.cancel()
            } else {
                self.receiveHTTPPayload(
                    connection: connection,
                    accumulatedData: buffer,
                    headerTimeoutBox: headerTimeoutBox,
                    headerDeadline: headerDeadline,
                    bodyDeadline: bodyDeadline
                )
            }
        }
    }

    private func parseHTTPRequest(
        headerData: Data,
        bodyData: Data,
        lineDelimiter: String,
        connection: NWConnection
    ) -> LocalShareHTTPRequest? {
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return nil
        }

        let lines = headerString.components(separatedBy: lineDelimiter)
        guard let requestLine = lines.first else { return nil }
        let requestParts = requestLine.components(separatedBy: " ")
        guard requestParts.count >= 3 else { return nil }

        let method = requestParts[0].uppercased()
        let rawURL = requestParts[1]
        let httpVersion = requestParts[2]
        guard httpVersion.hasPrefix("HTTP/1.") else { return nil }
        guard ["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"].contains(method) else { return nil }

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
        var duplicateContentLength = false
        var contentLengthValues: [String] = []
        var transferEncodingValues: [String] = []

        for line in lines.dropFirst() {
            if line.isEmpty { continue }
            guard line.first != " ", line.first != "\t" else { return nil }
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                let name = parts[0].lowercased()
                let value = parts[1]
                if name == "content-length" {
                    contentLengthValues.append(value)
                } else if name == "transfer-encoding" {
                    transferEncodingValues.append(value)
                }
                if headers[name] != nil && name == "content-length" {
                    duplicateContentLength = true
                }
                headers[name] = value
            }
        }

        if duplicateContentLength { return nil }

        let hasCL = !contentLengthValues.isEmpty
        let hasTE = !transferEncodingValues.isEmpty
        if hasCL && hasTE { return nil }

        if let clStr = headers["content-length"] {
            guard let cl = Int64(clStr), cl >= 0 else { return nil }
            _ = cl
        }

        if let teStr = headers["transfer-encoding"] {
            let tokens = teStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            guard tokens == ["chunked"] else { return nil }
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
            remoteIP: remoteIP,
            verifiedPeerFingerprint: self.verifiedPeerFingerprint(for: connection)
        )
    }

    private func routeRequest(connection: NWConnection, request: LocalShareHTTPRequest) {
        NSLog("[LocalShareServer] Received %@ %@ from %@", request.method, request.path, request.remoteIP)

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

    // FIX: never fall back to the client-claimed fingerprint. Store empty
    // string for "peer did not present a cert" so downstream trust logic
    // recognises it as unverified.
    private func handleRegisterRoute(connection: NWConnection, request: LocalShareHTTPRequest) {
        guard let registerDto = try? JSONDecoder().decode(LocalShareRegisterDto.self, from: request.body) else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Bad Request", body: nil)
            return
        }

        var remoteHost = request.remoteIP
        if case .hostPort(let host, _) = connection.endpoint {
            remoteHost = LocalShareSecurity.normalizeIP("\(host)")
        }
        let rawPort = registerDto.port ?? Int(LocalShareConstants.defaultHttpPort)
        guard let peerPort = UInt16(exactly: rawPort), peerPort > 0 else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Invalid Port", body: nil)
            return
        }
        let scheme = (registerDto.`protocol` ?? "https").lowercased()
        guard scheme == "https" || scheme == "http" else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Invalid Protocol", body: nil)
            return
        }

        if request.verifiedPeerFingerprint == nil,
           !registerDto.fingerprint.isEmpty {
            NSLog(
                "[LocalShareServer] Register: peer %@ presented no cert (claimed fp=%@); storing unverified",
                remoteHost, registerDto.fingerprint
            )
        }

        let discoveredPeer = LocalShareDiscoveredPeer(
            alias: LocalShareSecurity.sanitizeAlias(registerDto.alias),
            deviceModel: registerDto.deviceModel,
            deviceType: registerDto.deviceType ?? .desktop,
            fingerprint: request.verifiedPeerFingerprint ?? "",
            host: remoteHost,
            port: peerPort,
            protocol: scheme,
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
        guard authorizePIN(connection: connection, request: request) else {
            return
        }

        guard request.body.count <= LocalShareSecurity.maxRequestBodySize,
              let prepareReq = try? JSONDecoder().decode(LocalSharePrepareUploadRequest.self, from: request.body) else {
            sendRawResponse(connection: connection, statusCode: 400, reason: "Bad Request", body: nil)
            return
        }

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

        let targetDir = LocalShareFileManager.shared.activeReceiveDirectory
        guard LocalShareSecurity.hasSufficientDiskSpace(requiredBytes: calculatedTotal, at: targetDir) else {
            sendRawResponse(connection: connection, statusCode: 403, reason: "Insufficient Disk Space", body: nil)
            return
        }

        let sessionId = Self.generateSessionId()
        let sessionDir: URL
        do {
            sessionDir = try LocalShareFileManager.shared.createSessionDirectory(sessionId: sessionId)
        } catch {
            sendRawResponse(connection: connection, statusCode: 500, reason: "Internal Server Error", body: nil)
            return
        }

        let session: LocalShareSession
        do {
            session = try LocalShareSessionCoordinator.shared.offerIncomingSession(
                sessionId: sessionId,
                peerInfo: prepareReq.info,
                peerIP: request.remoteIP,
                verifiedPeerFingerprint: request.verifiedPeerFingerprint,
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

        let claimedFp = prepareReq.info.fingerprint
        let verifiedFp = request.verifiedPeerFingerprint
        let senderAlias = prepareReq.info.alias

        if let verifiedFp = verifiedFp, verifiedFp.caseInsensitiveCompare(claimedFp) != .orderedSame {
            NSLog(
                "[LocalShareServer] Peer identity mismatch: claimed=%@ verified=%@",
                claimedFp, verifiedFp
            )
            LocalShareSessionCoordinator.shared.cancelSession(sessionId: sessionId, reason: "Identity mismatch")
            LocalShareFileManager.shared.purgeSessionDirectory(sessionId: sessionId)
            sendRawResponse(connection: connection, statusCode: 403, reason: "Peer Identity Mismatch", body: nil)
            return
        }

        let effectiveFp = verifiedFp
        let trustState: LocalSharePeerTrustState
        if let effectiveFp = effectiveFp {
            trustState = self.trustStatus(for: effectiveFp, alias: senderAlias)
        } else {
            trustState = .unverifiedFirstContact
        }

        if trustState == .certificateChanged {
            LocalShareSessionCoordinator.shared.cancelSession(sessionId: sessionId, reason: "Peer certificate changed")
            LocalShareFileManager.shared.purgeSessionDirectory(sessionId: sessionId)
            sendRawResponse(connection: connection, statusCode: 403, reason: "Peer Certificate Changed", body: nil)
            return
        }
        if trustState == .blocked {
            LocalShareSessionCoordinator.shared.cancelSession(sessionId: sessionId, reason: "Blocked peer")
            LocalShareFileManager.shared.purgeSessionDirectory(sessionId: sessionId)
            sendRawResponse(connection: connection, statusCode: 403, reason: "Blocked Peer", body: nil)
            return
        }

        let normClientIP = LocalShareSecurity.normalizeIP(request.remoteIP)
        let isLoopback = isLoopbackAddress(normClientIP)
        let configuredPin = requiredPin
        let pinAuthenticated: Bool
        if let configuredPin, !configuredPin.isEmpty,
           let providedPin = request.queryParams["pin"],
           constantTimePINCompare(providedPin, configuredPin) {
            pinAuthenticated = true
        } else {
            pinAuthenticated = false
        }

        let testHarnessLoopbackTrust: Bool = {
            guard isLoopback else { return false }
            return isTestHarnessAutoAcceptEnabled
        }()
        let hasVerifiedIdentity = effectiveFp != nil
        let isCryptographicallyVerified = hasVerifiedIdentity && (pinAuthenticated || testHarnessLoopbackTrust)

        let favSet = favoriteFingerprints
        let effectiveFpLower = effectiveFp?.lowercased()
        let isClaimingFavorite = (effectiveFpLower.map { favSet.contains($0) } ?? false) || trustState == .trusted

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
                    LocalShareFileManager.shared.purgeSessionDirectory(sessionId: sessionId)
                    self.sendRawResponse(connection: connection, statusCode: 403, reason: "Forbidden", body: nil)
                }
            }
        } else {
            LocalShareSessionCoordinator.shared.cancelSession(sessionId: sessionId, reason: "No acceptance handler")
            LocalShareFileManager.shared.purgeSessionDirectory(sessionId: sessionId)
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

        if let clStr = request.headers["content-length"], let declaredCl = Int64(clStr), declaredCl != meta.size {
            session.releaseTokenReservation(token: token)
            session.markFileFailed(fileId: fileId, error: "Size Mismatch: Content-Length \(declaredCl) != metadata \(meta.size)")
            sendRawResponse(connection: connection, statusCode: 400, reason: "Size Mismatch", body: nil)
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

        let isChunked = request.headers["transfer-encoding"]?.lowercased().contains("chunked") == true
            || (request.headers["content-length"] == nil)
        let chunkDecoder = isChunked ? HTTPChunkDecoder() : nil

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

        if currentBytes > expectedTotal {
            session.releaseTokenReservation(token: token)
            session.removeActiveWriter(for: fileId)
            streamWriter.abort()
            session.markFileFailed(fileId: fileId, error: "Payload Exceeded")
            sendRawResponse(connection: connection, statusCode: 400, reason: "Payload Exceeded", body: nil)
            return
        }

        if currentBytes >= expectedTotal {
            finalizeStreamAndRespond(
                connection: connection,
                session: session,
                fileId: fileId,
                token: token,
                writer: streamWriter,
                meta: meta,
                chunkDecoder: chunkDecoder
            )
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

        let cycleGuard = LocalShareCycleGuard()

        let targetConn = connection
        let targetSess = session
        let idleWorkItem = DispatchWorkItem { [weak targetConn, weak targetSess] in
            guard cycleGuard.testAndClaim() else { return }
            targetSess?.releaseTokenReservation(token: token)
            targetSess?.removeActiveWriter(for: fileId)
            writer.abort()
            targetSess?.markFileFailed(fileId: fileId, error: "Upload Inactivity Timeout")
            targetConn?.cancel()
        }
        let idleBox = LocalShareTimeoutBox(idleWorkItem)
        queue.asyncAfter(deadline: .now() + 30.0, execute: idleWorkItem)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard cycleGuard.testAndClaim() else { return }
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
                    meta: meta,
                    chunkDecoder: chunkDecoder
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
        meta: LocalShareFileMetadata,
        chunkDecoder: HTTPChunkDecoder?
    ) {
        if let decoder = chunkDecoder {
            do {
                try decoder.requireTerminated()
            } catch {
                session.releaseTokenReservation(token: token)
                session.removeActiveWriter(for: fileId)
                writer.abort()
                session.markFileFailed(fileId: fileId, error: "Chunked transfer not terminated")
                sendRawResponse(connection: connection, statusCode: 400, reason: "Incomplete Chunked Transfer", body: nil)
                return
            }
        }

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
            session.markFileFailed(fileId: fileId, error: error.localizedDescription)
            sendRawResponse(connection: connection, statusCode: 500, reason: "Finalize Error", body: Data("File finalization failed".utf8))
        }
    }

    private func handleCancelRoute(connection: NWConnection, request: LocalShareHTTPRequest) {
        let outcome = authorizeAndCancelSession(
            sessionId: request.queryParams["sessionId"],
            remoteIP: request.remoteIP,
            verifiedPeerFingerprint: request.verifiedPeerFingerprint,
            coordinator: .shared
        )
        sendRawResponse(connection: connection, statusCode: outcome.statusCode, reason: outcome.reason, body: nil)
    }

    func authorizeAndCancelSession(
        sessionId: String?,
        remoteIP: String,
        verifiedPeerFingerprint: String?,
        coordinator: LocalShareSessionCoordinator = .shared
    ) -> (statusCode: Int, reason: String) {
        guard let sessionId, !sessionId.isEmpty else {
            return (400, "Missing Session ID")
        }
        guard let session = coordinator.getActiveSession(sessionId: sessionId),
              constantTimeStringCompare(session.sessionId, sessionId) else {
            return (404, "Session Not Found")
        }

        // Reject cancellation of completed/terminal sessions so promoted files/directories are never purged
        guard session.currentState.isActive else {
            return (409, "Session Already Terminated")
        }

        let callerIP = LocalShareSecurity.normalizeIP(remoteIP)
        let sessionPeerIP = LocalShareSecurity.normalizeIP(session.peerIP)
        let bothLoopback = LocalShareSecurity.isLoopbackAddress(callerIP)
            && LocalShareSecurity.isLoopbackAddress(sessionPeerIP)
        guard !callerIP.isEmpty, callerIP == sessionPeerIP || bothLoopback else {
            return (403, "Forbidden")
        }

        // If the session was bound to a verified mTLS client cert on /prepare-upload, enforce strict match (no nil downgrade)
        if let boundFingerprint = session.verifiedPeerFingerprint,
           !boundFingerprint.isEmpty {
            guard let presented = verifiedPeerFingerprint,
                  presented.caseInsensitiveCompare(boundFingerprint) == .orderedSame else {
                return (403, "Forbidden")
            }
        }

        coordinator.cancelSession(sessionId: sessionId, reason: "Peer cancelled")
        return (200, "OK")
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

    private func stableDownloadFileId(index: Int) -> String {
        return "file-\(index)"
    }

    private func handlePrepareDownloadRoute(connection: NWConnection, request: LocalShareHTTPRequest) {
        guard authorizePIN(connection: connection, request: request) else {
            return
        }

        let files = self.sharedDownloadFiles
        var metadataMap: [String: LocalShareFileMetadata] = [:]
        for (index, url) in files.enumerated() {
            let fileId = stableDownloadFileId(index: index)
            let size = Int64((try? url.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).fileSize) ?? 0)
            metadataMap[fileId] = LocalShareFileMetadata(
                id: fileId,
                fileName: url.lastPathComponent,
                size: size,
                fileType: "application/octet-stream"
            )
        }

        sendJSONResponse(connection: connection, statusCode: 200, value: metadataMap)
    }

    private func handleDownloadRoute(connection: NWConnection, request: LocalShareHTTPRequest) {
        guard authorizePIN(connection: connection, request: request) else {
            return
        }

        var resolvedIndex: Int?
        if let fileId = request.queryParams["fileId"], fileId.hasPrefix("file-"),
           let n = Int(fileId.dropFirst("file-".count)) {
            resolvedIndex = n
        } else if let idxStr = request.queryParams["index"], let n = Int(idxStr) {
            resolvedIndex = n
        }

        if let idx = resolvedIndex {
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
        guard authorizePIN(connection: connection, request: request) else {
            return
        }

        let alias = htmlEscaped(LocalShareSecurity.sanitizeAlias(serverAlias))
        let files = self.sharedDownloadFiles
        let suppliedPIN = request.queryParams["pin"]

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
                let name = htmlEscaped(file.lastPathComponent)
                let sizeLabel: String
                do {
                    let values = try file.resourceValues(forKeys: [.fileSizeKey])
                    if let size = values.fileSize, size >= 0 {
                        sizeLabel = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                    } else {
                        sizeLabel = "Size unavailable"
                    }
                } catch {
                    sizeLabel = "Size unavailable"
                }

                var queryItems = [URLQueryItem(name: "fileId", value: stableDownloadFileId(index: idx))]
                if let suppliedPIN = suppliedPIN {
                    queryItems.append(URLQueryItem(name: "pin", value: suppliedPIN))
                }
                var queryComponents = URLComponents()
                queryComponents.queryItems = queryItems
                let encodedQuery = queryComponents.percentEncodedQuery ?? "fileId=\(stableDownloadFileId(index: idx))"
                let downloadURL = "/api/localsend/v2/download?\(encodedQuery)"

                html += """
                <div class="file-item">
                    <div>
                        <div class="file-name">\(name)</div>
                        <div class="file-size">\(htmlEscaped(sizeLabel))</div>
                    </div>
                    <a class="btn" href="\(downloadURL)">Download</a>
                </div>
                """
            }
        }

        html += """
            </div>
        </body>
        </html>
        """

        sendRawResponse(
            connection: connection,
            statusCode: 200,
            reason: "OK",
            body: Data(html.utf8),
            contentType: "text/html; charset=utf-8",
            headers: [
                "X-Content-Type-Options": "nosniff",
                "X-Frame-Options": "DENY",
                "Referrer-Policy": "no-referrer",
                "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline';"
            ]
        )
    }

    private func sendFileResponse(
        connection: NWConnection,
        fileURL: URL,
        fileName: String
    ) {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            sendRawResponse(connection: connection, statusCode: 404, reason: "Not Found", body: nil)
            return
        }

        let fileSize: UInt64
        do {
            fileSize = try fileHandle.seekToEnd()
            try fileHandle.seek(toOffset: 0)
        } catch {
            try? fileHandle.close()
            NSLog("[LocalShareServer] Unable to determine opened file size for %@: %@", fileURL.lastPathComponent, error.localizedDescription)
            sendRawResponse(connection: connection, statusCode: 500, reason: "Unable to Read File Metadata", body: nil)
            return
        }

        guard fileSize <= UInt64(LocalShareSecurity.maxFileSize) else {
            try? fileHandle.close()
            sendRawResponse(connection: connection, statusCode: 413, reason: "File Too Large", body: nil)
            return
        }

        let sanitizedName = LocalShareSecurity.sanitizeFilename(fileName)
        var header = "HTTP/1.1 200 OK\r\n"
        header += "Content-Type: application/octet-stream\r\n"
        header += "Content-Length: \(fileSize)\r\n"
        header += "Content-Disposition: \(contentDispositionValue(for: sanitizedName))\r\n"
        header += "X-Content-Type-Options: nosniff\r\n"
        header += "Connection: close\r\n\r\n"

        let headerData = Data(header.utf8)

        if fileSize == 0 {
            try? fileHandle.close()
            connection.send(
                content: headerData,
                contentContext: .finalMessage,
                isComplete: true,
                completion: .contentProcessed { [weak connection] error in
                    if let error = error {
                        NSLog("[LocalShareServer] Empty-file response send failed: %@", error.localizedDescription)
                    }
                    connection?.cancel()
                }
            )
            return
        }

        connection.send(
            content: headerData,
            contentContext: .defaultMessage,
            isComplete: false,
            completion: .contentProcessed { [weak self, weak connection] error in
                if let error = error {
                    self?.abortFileStream(
                        connection: connection,
                        fileHandle: fileHandle,
                        reason: "HTTP header send failed: \(error.localizedDescription)"
                    )
                    return
                }

                guard let self = self, let connection = connection else {
                    try? fileHandle.close()
                    return
                }
                self.streamFileChunks(connection: connection, fileHandle: fileHandle, remainingBytes: fileSize)
            }
        )
    }

    private func streamFileChunks(
        connection: NWConnection,
        fileHandle: FileHandle,
        remainingBytes: UInt64
    ) {
        let chunkSize: UInt64 = 128 * 1024
        let bytesToRead = min(chunkSize, remainingBytes)

        guard bytesToRead > 0 else {
            try? fileHandle.close()
            connection.cancel()
            return
        }

        let chunk: Data
        do {
            guard let data = try fileHandle.read(upToCount: Int(bytesToRead)), !data.isEmpty else {
                abortFileStream(
                    connection: connection,
                    fileHandle: fileHandle,
                    reason: "Premature EOF: \(remainingBytes) bytes remained in the advertised response"
                )
                return
            }
            chunk = data
        } catch {
            abortFileStream(
                connection: connection,
                fileHandle: fileHandle,
                reason: "File read failed with \(remainingBytes) bytes remaining: \(error.localizedDescription)"
            )
            return
        }

        let chunkLength = UInt64(chunk.count)
        guard chunkLength <= remainingBytes else {
            abortFileStream(
                connection: connection,
                fileHandle: fileHandle,
                reason: "Read returned more bytes than the remaining Content-Length"
            )
            return
        }

        let nextRemaining = remainingBytes - chunkLength
        let isLastChunk = nextRemaining == 0
        let context: NWConnection.ContentContext = isLastChunk ? .finalMessage : .defaultMessage

        connection.send(
            content: chunk,
            contentContext: context,
            isComplete: isLastChunk,
            completion: .contentProcessed { [weak self, weak connection] sendError in
                if let sendError = sendError {
                    self?.abortFileStream(
                        connection: connection,
                        fileHandle: fileHandle,
                        reason: "Chunk send failed: \(sendError.localizedDescription)"
                    )
                    return
                }

                if isLastChunk {
                    try? fileHandle.close()
                    connection?.cancel()
                    return
                }

                guard let self = self, let connection = connection else {
                    try? fileHandle.close()
                    connection?.cancel()
                    return
                }

                self.queue.async {
                    self.streamFileChunks(
                        connection: connection,
                        fileHandle: fileHandle,
                        remainingBytes: nextRemaining
                    )
                }
            }
        )
    }

    private func abortFileStream(
        connection: NWConnection?,
        fileHandle: FileHandle,
        reason: String
    ) {
        NSLog("[LocalShareServer] Aborting incomplete file download: %@", reason)
        try? fileHandle.close()
        connection?.cancel()
    }

    private func sendJSONResponse<T: Encodable>(connection: NWConnection, statusCode: Int, value: T) {
        guard let data = try? JSONEncoder().encode(value) else {
            sendRawResponse(connection: connection, statusCode: 500, reason: "Serialization Error", body: nil)
            return
        }
        sendRawResponse(connection: connection, statusCode: statusCode, reason: reasonPhrase(for: statusCode), body: data, contentType: "application/json")
    }

    private func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 408: return "Request Timeout"
        case 409: return "Conflict"
        case 413: return "Payload Too Large"
        case 422: return "Unprocessable Entity"
        case 429: return "Too Many Requests"
        case 431: return "Request Header Fields Too Large"
        case 500: return "Internal Server Error"
        case 503: return "Service Unavailable"
        default: return "Unknown"
        }
    }

    private func sanitizeHeaderField(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    private func sendRawResponse(
        connection: NWConnection,
        statusCode: Int,
        reason: String,
        body: Data?,
        contentType: String = "text/plain",
        headers: [String: String] = [:]
    ) {
        let bodyLength = body?.count ?? 0
        NSLog("[LocalShareServer] Sending HTTP %ld %@ (%ld bytes) to %@", statusCode, reason, bodyLength, "\(connection.endpoint)")
        var header = "HTTP/1.1 \(statusCode) \(sanitizeHeaderField(reason))\r\n"
        header += "Content-Type: \(sanitizeHeaderField(contentType))\r\n"
        header += "Content-Length: \(bodyLength)\r\n"
        for (k, v) in headers {
            header += "\(sanitizeHeaderField(k)): \(sanitizeHeaderField(v))\r\n"
        }
        header += "Connection: close\r\n\r\n"

        var responseData = Data(header.utf8)
        if let body = body {
            responseData.append(body)
        }

        connection.send(content: responseData, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { [weak connection] sendError in
            if let sendError = sendError, let conn = connection {
                NSLog("[LocalShareServer] Response send error to %@: %@", "\(conn.endpoint)", String(describing: sendError))
                conn.cancel()
                return
            }
            connection?.cancel()
        })
    }
}