import Foundation
import CryptoKit
import Darwin

// MARK: - LocalShare Security Runtime

public enum LocalShareSecurity {

    // MARK: - Security Caps & Limits

    public static let maxFilesPerSession: Int = 500
    public static let maxSimultaneousConnections: Int = 32
    public static let maxConnectionsPerIP: Int = 8
    public static let maxConnectionsPerLoopback: Int = 16
    public static let maxConcurrentWriters: Int = 8

    public static let maxHeaderSize: Int = 32 * 1024

    public static let maxFailedPinAttemptsBeforeLockout: Int = 5
    public static let pinLockoutDurationSeconds: TimeInterval = 60.0
    public static let extendedPinLockoutDurationSeconds: TimeInterval = 300.0

    public static let maxFileSize: Int64 = 50 * 1024 * 1024 * 1024
    public static let maxTotalSessionSize: Int64 = 100 * 1024 * 1024 * 1024
    public static let maxRequestBodySize: Int = 1024 * 1024
    public static let minFreeDiskBuffer: Int64 = 500 * 1024 * 1024

    public static let maxAliasLength: Int = 32
    public static let maxFilenameLength: Int = 255

    public static let idleTimeoutSeconds: TimeInterval = 30.0
    public static let totalSessionTimeoutSeconds: TimeInterval = 900.0

    // MARK: - Character Filters

    private static let bidiRanges: [ClosedRange<UInt32>] = [
        0x202A...0x202E,
        0x2066...0x2069,
        0x200E...0x200F,
        0x061C...0x061C
    ]

    @inline(__always)
    private static func isDisallowedScalar(_ value: UInt32) -> Bool {
        // C0 control characters.
        if value < 0x20 {
            return true
        }

        // DEL.
        if value == 0x7F {
            return true
        }

        // C1 control characters.
        if value >= 0x80 && value <= 0x9F {
            return true
        }

        // Unicode bidirectional control characters.
        return bidiRanges.contains { $0.contains(value) }
    }

    // MARK: - UTF-8 Safe Truncation

    private static func truncateToUTF8Budget(
        _ string: String,
        maxBytes: Int
    ) -> String {

        guard maxBytes > 0 else {
            return ""
        }

        var result = ""
        var accumulated = 0

        for character in string {
            let byteCount = String(character).utf8.count

            guard accumulated + byteCount <= maxBytes else {
                break
            }

            result.append(character)
            accumulated += byteCount
        }

        return result
    }

    // MARK: - Filename Sanitization

    /// Sanitizes peer-provided filenames.
    ///
    /// This function is intended for display and destination-name preparation.
    /// Actual file creation must still use exclusive, no-follow filesystem APIs.
    public static func sanitizeFilename(_ raw: String) -> String {

        // Normalize Windows separators.
        let normalized = raw.replacingOccurrences(
            of: "\\",
            with: "/"
        )

        // Extract the final path component.
        var name = (normalized as NSString).lastPathComponent

        // Remove remaining dangerous separators.
        name = name.replacingOccurrences(of: "/", with: "_")
        name = name.replacingOccurrences(of: ":", with: "_")
        name = name.replacingOccurrences(of: "\0", with: "")

        // Remove control and Bidi characters.
        name = name.unicodeScalars
            .filter { !isDisallowedScalar($0.value) }
            .reduce(into: "") {
                $0.unicodeScalars.append($1)
            }

        // Prevent hidden filenames.
        while name.hasPrefix(".") {
            name.removeFirst()
        }

        // Trim whitespace.
        name = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        // Prevent empty filenames.
        if name.isEmpty {
            name = "unnamed_file"
        }

        // Enforce UTF-8 byte limit.
        if name.utf8.count > maxFilenameLength {

            let extensionName = (name as NSString).pathExtension
            let baseName = (name as NSString).deletingPathExtension

            let extensionBudget = max(1, maxFilenameLength / 2)

            let safeExtension: String

            if extensionName.utf8.count > extensionBudget {
                safeExtension = truncateToUTF8Budget(
                    extensionName,
                    maxBytes: extensionBudget
                )
            } else {
                safeExtension = extensionName
            }

            let extensionBytes = safeExtension.isEmpty
                ? 0
                : safeExtension.utf8.count + 1

            let baseBudget = max(
                1,
                maxFilenameLength - extensionBytes
            )

            var safeBase = truncateToUTF8Budget(
                baseName,
                maxBytes: baseBudget
            )

            if safeBase.isEmpty {
                safeBase = "file"
            }

            name = safeExtension.isEmpty
                ? safeBase
                : "\(safeBase).\(safeExtension)"

            // Final defensive verification.
            if name.utf8.count > maxFilenameLength {
                name = truncateToUTF8Budget(
                    name,
                    maxBytes: maxFilenameLength
                )
            }
        }

        return name
    }

    // MARK: - Path Containment Verification

    /// Validates that a filename resolves inside the specified directory.
    ///
    /// This is a validation helper, NOT a substitute for O_NOFOLLOW
    /// and exclusive file creation.
    public static func isContained(
        fileName: String,
        within parentDirectory: URL
    ) -> Bool {

        guard !fileName.isEmpty,
              fileName != ".",
              fileName != "..",
              !fileName.contains("/"),
              !fileName.contains("\\"),
              fileName == sanitizeFilename(fileName)
        else {
            return false
        }

        let parent = parentDirectory
            .standardizedFileURL
            .resolvingSymlinksInPath()

        let destination = parent
            .appendingPathComponent(
                fileName,
                isDirectory: false
            )
            .standardizedFileURL
            .resolvingSymlinksInPath()

        let parentPath = parent.path
        let destinationPath = destination.path

        let safePrefix = parentPath.hasSuffix("/")
            ? parentPath
            : parentPath + "/"

        guard destinationPath.hasPrefix(safePrefix) else {
            return false
        }

        guard destinationPath.count > safePrefix.count else {
            return false
        }

        return true
    }

    // MARK: - Non-Overwriting Destination Resolution

    /// Selects an unused destination filename.
    ///
    /// The returned URL is NOT reserved. The receiver must create the file
    /// atomically using exclusive creation to prevent TOCTOU attacks.
    public static func uniqueDestinationURL(
        for fileName: String,
        in directory: URL
    ) -> URL {

        let sanitized = sanitizeFilename(fileName)

        let fileManager = FileManager.default

        let baseName = (sanitized as NSString)
            .deletingPathExtension

        let extensionName = (sanitized as NSString)
            .pathExtension

        func makeCandidateName(suffix: String) -> String {

            let ending = extensionName.isEmpty
                ? " (\(suffix))"
                : " (\(suffix)).\(extensionName)"

            let endingBytes = ending.utf8.count

            let availableBytes = max(
                1,
                maxFilenameLength - endingBytes
            )

            let safeBase = truncateToUTF8Budget(
                baseName,
                maxBytes: availableBytes
            )

            let finalBase = safeBase.isEmpty ? "file" : safeBase

            return finalBase + ending
        }

        let originalURL = directory.appendingPathComponent(
            sanitized,
            isDirectory: false
        )

        if !fileManager.fileExists(atPath: originalURL.path) {
            return originalURL
        }

        // Numbered fallback.
        for counter in 1...9_999 {

            let candidateName = makeCandidateName(
                suffix: String(counter)
            )

            let candidateURL = directory.appendingPathComponent(
                candidateName,
                isDirectory: false
            )

            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        // UUID fallback.
        while true {

            let uuid = UUID().uuidString

            let suffix = "_\(uuid)"

            let ending = extensionName.isEmpty
                ? suffix
                : "\(suffix).\(extensionName)"

            let availableBytes = max(
                1,
                maxFilenameLength - ending.utf8.count
            )

            let safeBase = truncateToUTF8Budget(
                baseName,
                maxBytes: availableBytes
            )

            let finalBase = safeBase.isEmpty ? "file" : safeBase

            let candidateName = finalBase + ending

            let candidateURL = directory.appendingPathComponent(
                candidateName,
                isDirectory: false
            )

            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }
    }

    // MARK: - Disk Capacity Verification

    public static func hasSufficientDiskSpace(
        requiredBytes: Int64,
        at targetDirectory: URL
    ) -> Bool {

        guard requiredBytes >= 0 else {
            return false
        }

        let (needed, overflow) = requiredBytes.addingReportingOverflow(
            minFreeDiskBuffer
        )

        guard !overflow else {
            return false
        }

        do {

            let values = try targetDirectory.resourceValues(
                forKeys: [
                    .volumeAvailableCapacityForImportantUsageKey,
                    .volumeAvailableCapacityKey
                ]
            )

            let available = values.volumeAvailableCapacityForImportantUsage
                ?? values.volumeAvailableCapacity.map(Int64.init)
                ?? 0

            return available >= needed

        } catch {

            var stats = statvfs()

            let result: Int32? = targetDirectory.withUnsafeFileSystemRepresentation { path in
                guard let path else { return -1 }
                return statvfs(path, &stats)
            }

            guard result == 0 else {
                return false
            }

            let available = Int64(stats.f_bavail)
                * Int64(stats.f_frsize)

            return available >= needed
        }
    }

    // MARK: - Fingerprint Normalization

    public static func normalizeFingerprint(
        _ fingerprint: String
    ) -> String {

        var clean = fingerprint
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if clean.hasPrefix("sha256:") {
            clean = String(clean.dropFirst(7))
        } else if clean.hasPrefix("sha-256:") {
            clean = String(clean.dropFirst(8))
        }

        return clean
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    // MARK: - Fingerprint Format Validation

    public static func isValidFingerprint(
        _ fingerprint: String
    ) -> Bool {

        let normalized = normalizeFingerprint(fingerprint)

        guard normalized.utf8.count == 64 else {
            return false
        }

        return normalized.utf8.allSatisfy { byte in
            (48...57).contains(byte) ||
            (97...102).contains(byte)
        }
    }

    // MARK: - Peer Certificate Fingerprint Verification

    public static func isFingerprintValid(
        peerCertDER: Data,
        expectedFingerprint: String
    ) -> Bool {

        guard !peerCertDER.isEmpty,
              isValidFingerprint(expectedFingerprint)
        else {
            return false
        }

        let digest = SHA256.hash(data: peerCertDER)

        let computedHex = digest
            .map { String(format: "%02x", $0) }
            .joined()

        let normalizedExpected = normalizeFingerprint(
            expectedFingerprint
        )

        return computedHex == normalizedExpected
    }

    // MARK: - Verification Code Generation

    public static func computeVerificationCode(
        localFingerprint: String,
        peerFingerprint: String
    ) -> String {

        let clean1 = normalizeFingerprint(localFingerprint)
        let clean2 = normalizeFingerprint(peerFingerprint)

        // Reject malformed fingerprints.
        guard isValidFingerprint(clean1),
              isValidFingerprint(clean2)
        else {
            return "000-000"
        }

        // Sort fingerprints so both devices generate the same code.
        let pair = [clean1, clean2].sorted()

        let combined = "\(pair[0]):\(pair[1])"

        let digest = SHA256.hash(
            data: Data(combined.utf8)
        )

        let bytes = Array(digest)

        let number =
            (UInt32(bytes[0]) << 24) |
            (UInt32(bytes[1]) << 16) |
            (UInt32(bytes[2]) << 8) |
            UInt32(bytes[3])

        let codeNumber = number % 1_000_000

        return String(
            format: "%03d-%03d",
            codeNumber / 1000,
            codeNumber % 1000
        )
    }

    // MARK: - IP Address Normalization

    public static func normalizeIP(
        _ raw: String
    ) -> String {

        var ip = raw.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        // Remove IPv6 brackets and optional port.
        if ip.hasPrefix("[") {

            if let closeBracket = ip.firstIndex(of: "]") {

                ip = String(
                    ip[ip.index(after: ip.startIndex)..<closeBracket]
                )

            } else {

                ip = ip
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
            }
        }

        // Remove IPv6 interface scope.
        if let scopeIndex = ip.firstIndex(of: "%") {
            ip = String(ip[..<scopeIndex])
        }

        // Remove IPv4 or hostname port.
        let colonCount = ip.filter { $0 == ":" }.count

        if colonCount == 1,
           let colonIndex = ip.firstIndex(of: ":") {

            ip = String(ip[..<colonIndex])
        }

        // Remove one trailing FQDN root dot.
        if ip.hasSuffix(".") {
            ip.removeLast()
        }

        // IPv4-mapped IPv6.
        if ip.lowercased().hasPrefix("::ffff:") {
            ip = String(ip.dropFirst(7))
        }

        // Normalize IPv4 decimal octets.
        let octets = ip.components(separatedBy: ".")

        if octets.count == 4 {

            var normalizedOctets: [String] = []
            var valid = true

            for octet in octets {

                guard !octet.isEmpty,
                      octet.allSatisfy({ $0.isASCII && $0.isNumber }),
                      let number = Int(octet),
                      (0...255).contains(number)
                else {
                    valid = false
                    break
                }

                normalizedOctets.append(String(number))
            }

            if valid {
                return normalizedOctets.joined(separator: ".")
            }
        }

        // Normalize common IPv6 loopback representations.
        let lower = ip.lowercased()

        if lower == "::1" ||
            lower == "0:0:0:0:0:0:0:1" ||
            lower == "0000:0000:0000:0000:0000:0000:0000:0001" {

            return "::1"
        }

        return ip
    }

    // MARK: - Loopback Detection

    public static func isLoopbackAddress(
        _ address: String
    ) -> Bool {

        let ip = normalizeIP(address)

        if ip == "::1" {
            return true
        }

        // IPv4 loopback range: 127.0.0.0/8.
        if ip.hasPrefix("127.") {
            return true
        }

        return false
    }

    // MARK: - URL Host Formatting

    public static func formatHostForURL(
        _ host: String
    ) -> String {

        let clean = normalizeIP(host)

        if clean.contains(":") &&
            !clean.hasPrefix("[") &&
            !clean.hasSuffix("]") {

            return "[\(clean)]"
        }

        return clean
    }

    // MARK: - Secret & Path Redaction

    public static func scrubSecrets(
        from input: String
    ) -> String {

        var output = input

        let patterns: [(String, String)] = [

            (
                "token=[^&\\s]+",
                "token=[REDACTED_TOKEN]"
            ),

            (
                "sessionId=[^&\\s]+",
                "sessionId=[REDACTED_SESSION]"
            ),

            (
                "pin=[^&\\s]+",
                "pin=[REDACTED_PIN]"
            ),

            (
                "/Users/[^/\\s]+",
                "/Users/[REDACTED_USER]"
            )
        ]

        for (pattern, replacement) in patterns {

            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }

            let range = NSRange(
                output.startIndex..<output.endIndex,
                in: output
            )

            output = regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: replacement
            )
        }

        return output
    }

    // MARK: - Device Alias Sanitization

    public static func sanitizeAlias(
        _ raw: String
    ) -> String {

        let stripped = raw.unicodeScalars
            .filter {
                !isDisallowedScalar($0.value)
            }
            .reduce(into: "") {
                $0.unicodeScalars.append($1)
            }

        let trimmed = stripped.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return "Unknown Device"
        }

        return truncateToUTF8Budget(
            trimmed,
            maxBytes: maxAliasLength
        )
    }
}

// MARK: - Thread-Safe Sliding Window Rate Limiter

public final class LocalShareRateLimiter: @unchecked Sendable {

    private let lock = NSLock()

    private let maxRequestsPerWindow: Int
    private let windowDuration: TimeInterval

    // Monotonic timestamps prevent wall-clock adjustments
    // from affecting rate-limit calculations.
    private var clientRequests: [String: [TimeInterval]] = [:]

    private var lastGlobalPrune: TimeInterval = 0

    private let pruneInterval: TimeInterval = 60.0

    // MARK: - Initialization

    public init(
        maxRequests: Int = 5,
        windowDuration: TimeInterval = 1.0
    ) {

        self.maxRequestsPerWindow = max(
            1,
            maxRequests
        )

        self.windowDuration = windowDuration.isFinite
            ? max(0.001, windowDuration)
            : 1.0
    }

    // MARK: - Request Validation

    public func isAllowed(
        ip: String
    ) -> Bool {

        lock.lock()
        defer { lock.unlock() }

        let key = LocalShareSecurity.normalizeIP(ip)

        guard !key.isEmpty else {
            return false
        }

        let now = ProcessInfo.processInfo.systemUptime

        let cutoff = now - windowDuration

        // Periodically prune stale IP entries.
        if now - lastGlobalPrune >= pruneInterval {

            pruneGlobalTable(
                cutoff: cutoff
            )

            lastGlobalPrune = now
        }

        // Additional cleanup if the table becomes unusually large.
        if clientRequests.count > 1_000 {

            pruneGlobalTable(
                cutoff: cutoff
            )
        }

        var timestamps = clientRequests[key, default: []]
            .filter { $0 > cutoff }

        // Enforce sliding-window request limit.
        guard timestamps.count < maxRequestsPerWindow else {

            clientRequests[key] = timestamps

            return false
        }

        timestamps.append(now)

        clientRequests[key] = timestamps

        return true
    }

    // MARK: - Global Pruning

    private func pruneGlobalTable(
        cutoff: TimeInterval
    ) {

        clientRequests = clientRequests.compactMapValues {
            timestamps in

            let valid = timestamps.filter {
                $0 > cutoff
            }

            return valid.isEmpty
                ? nil
                : valid
        }
    }

    // MARK: - Reset

    public func reset() {

        lock.lock()
        defer { lock.unlock() }

        clientRequests.removeAll(
            keepingCapacity: false
        )

        lastGlobalPrune = 0
    }
}
