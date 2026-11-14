import Foundation
import CryptoKit

// MARK: - Transfer Session State
public enum LocalShareSessionState: Sendable, Equatable {
    case idle
    case offered
    case accepted
    case receiving
    case sending
    case completed
    case cancelled(reason: String)
    case failed(LocalShareError)
    
    public var isActive: Bool {
        switch self {
        case .offered, .accepted, .receiving, .sending:
            return true
        default:
            return false
        }
    }
}

// MARK: - File Transfer Progress
public struct LocalShareFileProgress: Sendable, Identifiable, Equatable {
    public var id: String { fileId }
    public let fileId: String
    public let fileName: String
    public let totalBytes: Int64
    public var bytesTransferred: Int64
    public var isCompleted: Bool
    public var error: String?
    
    public init(
        fileId: String,
        fileName: String,
        totalBytes: Int64,
        bytesTransferred: Int64 = 0,
        isCompleted: Bool = false,
        error: String? = nil
    ) {
        self.fileId = fileId
        self.fileName = fileName
        self.totalBytes = totalBytes
        self.bytesTransferred = bytesTransferred
        self.isCompleted = isCompleted
        self.error = error
    }
    
    public var fraction: Double {
        guard totalBytes > 0 else { return isCompleted ? 1.0 : 0.0 }
        return min(1.0, max(0.0, Double(bytesTransferred) / Double(totalBytes)))
    }
}

// MARK: - Active Transfer Session Model
public final class LocalShareSession: @unchecked Sendable {
    public let sessionId: String
    public let peerInfo: LocalShareDeviceInfo
    public let peerIP: String
    public let isIncoming: Bool
    public let sessionDirectory: URL?
    public let filesMetadata: [String: LocalShareFileMetadata]
    
    private let lock = NSLock()
    private var state: LocalShareSessionState = .idle
    private var fileTokens: [String: String] = [:]
    private var consumedTokens: Set<String> = []
    private var inProgressTokens: Set<String> = []
    private var fileProgressMap: [String: LocalShareFileProgress] = [:]
    private var activeWriters: [String: LocalShareFileStreamWriter] = [:]
    private let createdAt = Date()
    private var lastActivity = Date()
    
    public init(
        sessionId: String,
        peerInfo: LocalShareDeviceInfo,
        peerIP: String,
        isIncoming: Bool,
        sessionDirectory: URL?,
        filesMetadata: [String: LocalShareFileMetadata]
    ) {
        self.sessionId = sessionId
        self.peerInfo = peerInfo
        self.peerIP = peerIP
        self.isIncoming = isIncoming
        self.sessionDirectory = sessionDirectory
        self.filesMetadata = filesMetadata
        
        for (id, meta) in filesMetadata {
            fileProgressMap[id] = LocalShareFileProgress(
                fileId: id,
                fileName: meta.fileName,
                totalBytes: meta.size
            )
        }
    }
    
    // MARK: - State Inspection & Transitions
    
    public var currentState: LocalShareSessionState {
        lock.lock()
        defer { lock.unlock() }
        return state
    }
    
    public func transition(to newState: LocalShareSessionState) {
        lock.lock()
        defer { lock.unlock() }
        self.state = newState
        self.lastActivity = Date()
        if !newState.isActive {
            for (_, writer) in activeWriters {
                writer.abort()
            }
            activeWriters.removeAll()
        }
    }
    
    // MARK: - Token Management (Single-Use per File)
    
    /// Generates cryptographically secure single-use transfer tokens for all files in the session.
    public func generateFileTokens() -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        fileTokens.removeAll()
        consumedTokens.removeAll()
        for (fileId, _) in filesMetadata {
            let tokenBytes = SymmetricKey(size: .bits256)
            let tokenString = tokenBytes.withUnsafeBytes { raw in
                raw.map { String(format: "%02x", $0) }.joined()
            }
            fileTokens[fileId] = tokenString
        }
        return fileTokens
    }
    
    /// Validates an incoming upload request's file token and client IP.
    /// Atomically reserves the token in `inProgressTokens` to prevent concurrent replays.
    public func validateToken(fileId: String, token: String, clientIP: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // Ensure IP matches session origin
        guard peerIP == clientIP || clientIP == "127.0.0.1" || clientIP == "::1" else {
            return false
        }
        
        // Ensure token has not been consumed already (anti-replay)
        guard !consumedTokens.contains(token) else {
            return false
        }
        
        // Ensure token is not already in-progress concurrently
        guard !inProgressTokens.contains(token) else {
            return false
        }
        
        guard let expected = fileTokens[fileId], expected == token else {
            return false
        }
        
        inProgressTokens.insert(token)
        return true
    }
    
    /// Releases an in-progress token reservation if the upload fails or terminates before completion.
    public func releaseTokenReservation(token: String) {
        lock.lock()
        defer { lock.unlock() }
        inProgressTokens.remove(token)
    }
    
    /// Marks a token as consumed upon successful completion of a file upload.
    public func markTokenConsumed(fileId: String, token: String) {
        lock.lock()
        defer { lock.unlock() }
        inProgressTokens.remove(token)
        consumedTokens.insert(token)
        lastActivity = Date()
    }
    
    // MARK: - Progress Tracking
    
    public func updateProgress(fileId: String, bytesReceived: Int64) {
        lock.lock()
        defer { lock.unlock() }
        if var p = fileProgressMap[fileId] {
            p.bytesTransferred = bytesReceived
            fileProgressMap[fileId] = p
        }
        lastActivity = Date()
    }
    
    public func markFileCompleted(fileId: String) {
        lock.lock()
        defer { lock.unlock() }
        if var p = fileProgressMap[fileId] {
            p.bytesTransferred = p.totalBytes
            p.isCompleted = true
            fileProgressMap[fileId] = p
        }
        lastActivity = Date()
        
        // Check if all files completed
        let allDone = fileProgressMap.values.allSatisfy { $0.isCompleted }
        if allDone {
            state = .completed
        }
    }
    
    public func markFileFailed(fileId: String, error: String) {
        lock.lock()
        defer { lock.unlock() }
        if var p = fileProgressMap[fileId] {
            p.error = error
            fileProgressMap[fileId] = p
        }
        lastActivity = Date()
    }
    
    public var allProgress: [LocalShareFileProgress] {
        lock.lock()
        defer { lock.unlock() }
        return Array(fileProgressMap.values)
    }
    
    public var overallFraction: Double {
        lock.lock()
        defer { lock.unlock() }
        let total = fileProgressMap.values.reduce(Int64(0)) { $0 + $1.totalBytes }
        guard total > 0 else { return 1.0 }
        let transferred = fileProgressMap.values.reduce(Int64(0)) { $0 + $1.bytesTransferred }
        return min(1.0, max(0.0, Double(transferred) / Double(total)))
    }
    
    // MARK: - Active Writer Tracking (Per-File Synchronized Collection)
    
    public func registerActiveWriter(_ writer: LocalShareFileStreamWriter, for fileId: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard state.isActive else {
            throw LocalShareError.sessionCancelled
        }
        if activeWriters[fileId] != nil {
            throw LocalShareError.serverError("Upload writer already active for fileId \(fileId)")
        }
        self.activeWriters[fileId] = writer
    }
    
    @discardableResult
    public func removeActiveWriter(for fileId: String) -> LocalShareFileStreamWriter? {
        lock.lock()
        defer { lock.unlock() }
        return self.activeWriters.removeValue(forKey: fileId)
    }
    
    public func getActiveWriter(for fileId: String) -> LocalShareFileStreamWriter? {
        lock.lock()
        defer { lock.unlock() }
        return self.activeWriters[fileId]
    }
    
    public var activeWriterCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return self.activeWriters.count
    }
    
    public func abortActiveWriter(for fileId: String) {
        lock.lock()
        defer { lock.unlock() }
        if let writer = activeWriters.removeValue(forKey: fileId) {
            writer.abort()
        }
    }
    
    public func abortAllActiveWriters() {
        lock.lock()
        defer { lock.unlock() }
        for (_, writer) in activeWriters {
            writer.abort()
        }
        activeWriters.removeAll()
    }
    
    /// Backward-compatible single-writer setter mapping to "default" slot
    public func setActiveWriter(_ writer: LocalShareFileStreamWriter?) {
        lock.lock()
        defer { lock.unlock() }
        if let w = writer {
            activeWriters["default"] = w
        } else {
            activeWriters.removeValue(forKey: "default")
        }
    }
    
    /// Backward-compatible abort calling abortAllActiveWriters
    public func abortActiveWriter() {
        abortAllActiveWriters()
    }
    
    // MARK: - Timeouts
    
    public func isTimedOut(now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard state.isActive else { return false }
        let idleElapsed = now.timeIntervalSince(lastActivity)
        let totalElapsed = now.timeIntervalSince(createdAt)
        return idleElapsed > LocalShareSecurity.idleTimeoutSeconds ||
               totalElapsed > LocalShareSecurity.totalSessionTimeoutSeconds
    }
}

// MARK: - Thread-Safe Session Coordinator (Enforces Single Active Session)
public final class LocalShareSessionCoordinator: @unchecked Sendable {
    public static let shared = LocalShareSessionCoordinator()
    
    private let lock = NSLock()
    private var activeSession: LocalShareSession?
    
    public init() {}
    
    /// Attempts to register an offered incoming transfer session. Fails if another session is active.
    public func offerIncomingSession(
        sessionId: String,
        peerInfo: LocalShareDeviceInfo,
        peerIP: String,
        sessionDirectory: URL,
        filesMetadata: [String: LocalShareFileMetadata]
    ) throws -> LocalShareSession {
        lock.lock()
        defer { lock.unlock() }
        
        // Clean up timed out sessions
        if let current = activeSession, current.isTimedOut() {
            current.abortActiveWriter()
            current.transition(to: .failed(.sessionCancelled))
            if let dir = current.sessionDirectory {
                try? FileManager.default.removeItem(at: dir)
            }
            activeSession = nil
        }
        
        // Enforce strict single active session rule (HTTP 409)
        if let current = activeSession, current.currentState.isActive {
            throw LocalShareError.blockedByAnotherSession
        }
        
        let session = LocalShareSession(
            sessionId: sessionId,
            peerInfo: peerInfo,
            peerIP: peerIP,
            isIncoming: true,
            sessionDirectory: sessionDirectory,
            filesMetadata: filesMetadata
        )
        session.transition(to: .offered)
        self.activeSession = session
        return session
    }
    
    /// Retrieves the current active session matching the given sessionId.
    public func getActiveSession(sessionId: String) -> LocalShareSession? {
        lock.lock()
        defer { lock.unlock() }
        guard let current = activeSession, current.sessionId == sessionId else {
            return nil
        }
        return current
    }
    
    /// Current active session (if any).
    public var currentSession: LocalShareSession? {
        lock.lock()
        defer { lock.unlock() }
        return activeSession
    }
    
    /// Explicitly cancels the active session and cleans up disk artifacts.
    public func cancelSession(sessionId: String, reason: String = "User cancelled") {
        lock.lock()
        defer { lock.unlock() }
        guard let current = activeSession, current.sessionId == sessionId else { return }
        current.abortActiveWriter()
        current.transition(to: .cancelled(reason: reason))
        if let dir = current.sessionDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
        self.activeSession = nil
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        activeSession?.abortActiveWriter()
        activeSession = nil
    }
}
