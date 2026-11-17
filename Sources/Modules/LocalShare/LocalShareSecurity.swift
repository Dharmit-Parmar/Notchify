import Foundation
import CryptoKit

// MARK: - LocalShare Security Runtime
public enum LocalShareSecurity {
    
    // MARK: - Security Caps & Limits
    public static let maxFilesPerSession: Int = 500
    public static let maxSimultaneousConnections: Int = 32
    public static let maxConnectionsPerIP: Int = 8
    public static let maxConnectionsPerLoopback: Int = 16
    public static let maxConcurrentWriters: Int = 8
    public static let maxHeaderSize: Int = 32 * 1024 // 32 KB
    public static let maxFailedPinAttemptsBeforeLockout: Int = 5
    public static let pinLockoutDurationSeconds: TimeInterval = 60.0
    public static let extendedPinLockoutDurationSeconds: TimeInterval = 300.0
    public static let maxFileSize: Int64 = 50 * 1024 * 1024 * 1024 // 50 GB
    public static let maxTotalSessionSize: Int64 = 100 * 1024 * 1024 * 1024 // 100 GB aggregate session limit
    public static let maxRequestBodySize: Int = 1024 * 1024 // 1 MB JSON limit
    public static let minFreeDiskBuffer: Int64 = 500 * 1024 * 1024 // 500 MB safety margin
    public static let maxAliasLength: Int = 32
    public static let maxFilenameLength: Int = 255
    public static let idleTimeoutSeconds: TimeInterval = 30.0
    public static let totalSessionTimeoutSeconds: TimeInterval = 900.0 // 15 minutes
    
    // MARK: - Filename Sanitization
    /// Strictly sanitizes peer-provided file names to prevent directory traversal, hidden files, and shell injection.
    public static func sanitizeFilename(_ raw: String) -> String {
        // 1. Normalize Windows backslashes to forward slashes first so lastPathComponent works consistently
        let normalized = raw.replacingOccurrences(of: "\\", with: "/")
        
        // 2. Take strictly the last path component
        var name = (normalized as NSString).lastPathComponent
        
        // 3. Strip remaining path separators, colons, null bytes, and non-printable control characters
        name = name.replacingOccurrences(of: "/", with: "_")
        name = name.replacingOccurrences(of: ":", with: "_")
        name = name.replacingOccurrences(of: "\0", with: "")
        
        // Strip ASCII control characters 0...31 and 127
        name = name.unicodeScalars.filter { scalar in
            let val = scalar.value
            return val >= 32 && val != 127
        }.reduce("") { $0 + String($1) }
        
        // 3. Strip all leading dots to prevent UNIX hidden files (.bashrc, .zshrc, .env)
        while name.hasPrefix(".") {
            name.removeFirst()
        }
        
        // 4. Trim leading/trailing whitespace
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 5. Fallback for empty strings
        if name.isEmpty {
            name = "unnamed_file"
        }
        
        // 6. Enforce filesystem max length
        if name.utf8.count > maxFilenameLength {
            let ext = (name as NSString).pathExtension
            let base = (name as NSString).deletingPathExtension
            let maxBaseLen = max(1, maxFilenameLength - (ext.isEmpty ? 0 : ext.utf8.count + 1))
            let trimmedBase = String(base.prefix(maxBaseLen))
            name = ext.isEmpty ? trimmedBase : "\(trimmedBase).\(ext)"
        }
        
        return name
    }
    
    // MARK: - Path Containment Verification
    /// Validates that a sanitized filename strictly stays within the designated session folder.
    public static func isContained(fileName: String, within parentDirectory: URL) -> Bool {
        let destinationURL: URL
        if fileName.hasPrefix("/") {
            destinationURL = URL(fileURLWithPath: fileName)
        } else {
            destinationURL = parentDirectory.appendingPathComponent(fileName)
        }
        
        let parentStandardized = parentDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let destinationStandardized = destinationURL.standardizedFileURL.resolvingSymlinksInPath()
        
        let parentPath = parentStandardized.path
        let destPath = destinationStandardized.path
        
        // Ensure trailing slash on parentPath to prevent sibling directory prefix collisions
        // (e.g. /tmp/session-1 vs /tmp/session-12)
        let safeParent = parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
        
        // Must start with safe parent path and not escape
        guard destPath.hasPrefix(safeParent) else {
            return false
        }
        
        // Ensure destination does not equal parent directly
        guard destPath.count > safeParent.count else {
            return false
        }
        
        return true
    }
    
    // MARK: - Non-Overwriting Destination Resolution
    /// Generates a non-colliding destination URL by appending numeric suffixes (" (1)", " (2)") if a file exists.
    public static func uniqueDestinationURL(for fileName: String, in directory: URL) -> URL {
        let sanitized = sanitizeFilename(fileName)
        let fileManager = FileManager.default
        var candidateURL = directory.appendingPathComponent(sanitized)
        
        guard fileManager.fileExists(atPath: candidateURL.path) else {
            return candidateURL
        }
        
        let baseName = (sanitized as NSString).deletingPathExtension
        let extensionName = (sanitized as NSString).pathExtension
        var counter = 1
        
        while fileManager.fileExists(atPath: candidateURL.path) {
            let newName: String
            if extensionName.isEmpty {
                newName = "\(baseName) (\(counter))"
            } else {
                newName = "\(baseName) (\(counter)).\(extensionName)"
            }
            candidateURL = directory.appendingPathComponent(newName)
            counter += 1
            if counter > 9999 {
                // Safeguard against infinite loops
                let randomSuffix = UUID().uuidString.prefix(6)
                let fallbackName = extensionName.isEmpty ? "\(baseName)_\(randomSuffix)" : "\(baseName)_\(randomSuffix).\(extensionName)"
                return directory.appendingPathComponent(fallbackName)
            }
        }
        
        return candidateURL
    }
    
    // MARK: - Disk Capacity Verification
    /// Verifies that the destination volume has enough capacity for the transfer batch plus safety buffer.
    public static func hasSufficientDiskSpace(requiredBytes: Int64, at targetDirectory: URL) -> Bool {
        guard requiredBytes >= 0 else { return false }
        let (needed, overflow) = requiredBytes.addingReportingOverflow(minFreeDiskBuffer)
        guard !overflow else { return false }
        do {
            let values = try targetDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
            let available = values.volumeAvailableCapacityForImportantUsage ?? values.volumeAvailableCapacity.map(Int64.init) ?? 0
            return available >= needed
        } catch {
            // Fallback to POSIX statvfs
            var stat = statvfs()
            if targetDirectory.withUnsafeFileSystemRepresentation({ statvfs($0, &stat) }) == 0 {
                let available = Int64(stat.f_bavail) * Int64(stat.f_frsize)
                return available >= needed
            }
            return false
        }
    }
    
    // MARK: - Peer Certificate Fingerprint Verification
    /// Normalizes a SHA-256 fingerprint by stripping prefixes (sha256:, sha-256:), colons, hyphens, and whitespace.
    public static func normalizeFingerprint(_ fp: String) -> String {
        var clean = fp.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.hasPrefix("sha256:") {
            clean = String(clean.dropFirst(7))
        } else if clean.hasPrefix("sha-256:") {
            clean = String(clean.dropFirst(8))
        }
        return clean.replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    /// Validates that a peer's DER-encoded certificate matches the expected SHA-256 fingerprint.
    public static func isFingerprintValid(peerCertDER: Data, expectedFingerprint: String) -> Bool {
        guard !peerCertDER.isEmpty, !expectedFingerprint.isEmpty else { return false }
        let digest = SHA256.hash(data: peerCertDER)
        let computedHex = digest.map { String(format: "%02x", $0) }.joined()
        let normExpected = normalizeFingerprint(expectedFingerprint)
        return computedHex.caseInsensitiveCompare(normExpected) == .orderedSame
    }

    /// Computes a deterministic, human-readable 6-digit Short Authentication String (SAS)
    /// from two peer fingerprints to authenticate the TLS session out-of-band and defeat active LAN MITM.
    public static func computeVerificationCode(localFingerprint: String, peerFingerprint: String) -> String {
        let clean1 = normalizeFingerprint(localFingerprint)
        let clean2 = normalizeFingerprint(peerFingerprint)
        let pair = [clean1, clean2].sorted()
        let combined = "\(pair[0]):\(pair[1])"
        let digest = SHA256.hash(data: Data(combined.utf8))
        let bytes = Array(digest)
        let num = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
        let codeNum = num % 1_000_000
        return String(format: "%03d-%03d", codeNum / 1000, codeNum % 1000)
    }

    // MARK: - IP Address Normalization
    /// Strips interface scopes (e.g., %en0) and IPv4-mapped IPv6 prefixes (::ffff:) for robust peer matching.
    public static func normalizeIP(_ raw: String) -> String {
        var ip = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let scopeIdx = ip.firstIndex(of: "%") {
            ip = String(ip[..<scopeIdx])
        }
        if ip.lowercased().hasPrefix("::ffff:") {
            ip = String(ip.dropFirst(7))
        }
        return ip
    }

    /// Formats an IP address or hostname for safe inclusion in an RFC 3986 URL, wrapping IPv6 in brackets.
    public static func formatHostForURL(_ host: String) -> String {
        let clean = normalizeIP(host)
        if clean.contains(":") && !clean.hasPrefix("[") && !clean.hasSuffix("]") {
            return "[\(clean)]"
        }
        return clean
    }
    
    // MARK: - Secret & Path Redaction
    /// Scrubs authentication tokens, session IDs, PINs, and local user home paths from error messages and logs.
    public static func scrubSecrets(from input: String) -> String {
        var output = input
        
        // Redact transfer tokens in query strings
        if let tokenRegex = try? NSRegularExpression(pattern: "token=[^&\\s]+", options: .caseInsensitive) {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = tokenRegex.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: "token=[REDACTED_TOKEN]")
        }
        
        // Redact session IDs
        if let sessionRegex = try? NSRegularExpression(pattern: "sessionId=[^&\\s]+", options: .caseInsensitive) {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = sessionRegex.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: "sessionId=[REDACTED_SESSION]")
        }
        
        // Redact PINs
        if let pinRegex = try? NSRegularExpression(pattern: "pin=[^&\\s]+", options: .caseInsensitive) {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = pinRegex.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: "pin=[REDACTED_PIN]")
        }
        
        // Redact local username in filesystem paths (/Users/username/...)
        if let userRegex = try? NSRegularExpression(pattern: "/Users/[^/\\s]+", options: []) {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = userRegex.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: "/Users/[REDACTED_USER]")
        }
        
        return output
    }
    
    // MARK: - Device Alias Sanitization
    /// Sanitizes remote device alias for safe UI display (caps length, strips control chars).
    public static func sanitizeAlias(_ raw: String) -> String {
        let stripped = raw.unicodeScalars.filter { scalar in
            let val = scalar.value
            return val >= 32 && val != 127
        }.reduce("") { $0 + String($1) }
        
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Unknown Device"
        }
        return String(trimmed.prefix(maxAliasLength))
    }
}

// MARK: - Thread-Safe Sliding Window Rate Limiter
public final class LocalShareRateLimiter: @unchecked Sendable {
    private let lock = NSLock()
    private let maxRequestsPerWindow: Int
    private let windowDuration: TimeInterval
    private var clientRequests: [String: [Date]] = [:]
    
    public init(maxRequests: Int = 5, windowDuration: TimeInterval = 1.0) {
        self.maxRequestsPerWindow = maxRequests
        self.windowDuration = windowDuration
    }
    
    /// Checks whether an incoming request from the given IP address is within rate limits.
    public func isAllowed(ip: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let cutoff = now.addingTimeInterval(-windowDuration)
        
        // Periodic eviction when table grows to prevent memory bloat
        if clientRequests.count > 1000 {
            clientRequests = clientRequests.compactMapValues { list in
                let valid = list.filter { $0 > cutoff }
                return valid.isEmpty ? nil : valid
            }
        }
        
        var timestamps = clientRequests[ip]?.filter { $0 > cutoff } ?? []
        
        if timestamps.count >= maxRequestsPerWindow {
            clientRequests[ip] = timestamps
            return false
        }
        
        timestamps.append(now)
        clientRequests[ip] = timestamps
        return true
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        clientRequests.removeAll()
    }
}
