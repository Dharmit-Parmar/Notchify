import Foundation

// MARK: - LocalShare Protocol Constants (LocalSend v2.0 - v2.2 Compatible)
public enum LocalShareConstants {
    /// Protocol version string expected by LocalSend v2 clients.
    public static let protocolVersion = "2.0"
    
    /// Default UDP multicast port defined by the LocalSend specification.
    public static let defaultMulticastPort: UInt16 = 53317
    
    /// Default TCP HTTP/HTTPS port defined by the LocalSend specification.
    public static let defaultHttpPort: UInt16 = 53317
    
    /// Default IPv4 multicast group address.
    public static let defaultMulticastGroup = "224.0.0.167"
    
    /// Default application display title.
    public static let moduleTitle = "Local Share"
}

// MARK: - Endpoint Paths (LocalSend v2.0 - v2.2)
public enum LocalShareEndpoints {
    public static let register = "/api/localsend/v2/register"
    public static let prepareUpload = "/api/localsend/v2/prepare-upload"
    public static let upload = "/api/localsend/v2/upload"
    public static let cancel = "/api/localsend/v2/cancel"
    public static let info = "/api/localsend/v2/info"
    
    // Reverse transfer endpoints (download API)
    public static let prepareDownload = "/api/localsend/v2/prepare-download"
    public static let download = "/api/localsend/v2/download"
}

// MARK: - Device Type Enum
public enum LocalShareDeviceType: String, Codable, Sendable, CaseIterable {
    case mobile
    case desktop
    case web
    case headless
    case server
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self).lowercased()
        if let val = LocalShareDeviceType(rawValue: raw) {
            self = val
        } else {
            // Default fallback as defined by LocalSend protocol section 7.1
            self = .desktop
        }
    }
}

// MARK: - Device Info Model
public struct LocalShareDeviceInfo: Codable, Sendable, Equatable {
    public var alias: String
    public var version: String
    public var deviceModel: String?
    public var deviceType: LocalShareDeviceType?
    public var fingerprint: String
    public var port: Int?
    public var `protocol`: String?
    public var download: Bool?
    public var announce: Bool?
    
    public init(
        alias: String,
        version: String = LocalShareConstants.protocolVersion,
        deviceModel: String? = "macOS",
        deviceType: LocalShareDeviceType? = .desktop,
        fingerprint: String,
        port: Int? = Int(LocalShareConstants.defaultHttpPort),
        protocol: String? = "https",
        download: Bool? = false,
        announce: Bool? = nil
    ) {
        self.alias = alias
        self.version = version
        self.deviceModel = deviceModel
        self.deviceType = deviceType
        self.fingerprint = fingerprint
        self.port = port
        self.`protocol` = `protocol`
        self.download = download
        self.announce = announce
    }
}

// MARK: - File Time Metadata
public struct LocalShareFileTimeMetadata: Codable, Sendable, Equatable {
    public var modified: String?
    public var accessed: String?
    
    public init(modified: String? = nil, accessed: String? = nil) {
        self.modified = modified
        self.accessed = accessed
    }
}

// MARK: - File Metadata Model
public struct LocalShareFileMetadata: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var fileName: String
    public var size: Int64
    public var fileType: String
    public var sha256: String?
    public var preview: String?
    public var metadata: LocalShareFileTimeMetadata?
    
    public init(
        id: String,
        fileName: String,
        size: Int64,
        fileType: String = "application/octet-stream",
        sha256: String? = nil,
        preview: String? = nil,
        metadata: LocalShareFileTimeMetadata? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.size = size
        self.fileType = fileType
        self.sha256 = sha256
        self.preview = preview
        self.metadata = metadata
    }
}

// MARK: - Prepare Upload Request & Response
public struct LocalSharePrepareUploadRequest: Codable, Sendable, Equatable {
    public var info: LocalShareDeviceInfo
    public var files: [String: LocalShareFileMetadata]
    
    public init(info: LocalShareDeviceInfo, files: [String: LocalShareFileMetadata]) {
        self.info = info
        self.files = files
    }
    
    /// Total byte size across all files in the request, guarded against integer overflow.
    public var totalSize: Int64 {
        files.values.reduce(Int64(0)) { acc, file in
            let (sum, overflow) = acc.addingReportingOverflow(max(0, file.size))
            return overflow ? Int64.max : sum
        }
    }
}

public struct LocalSharePrepareUploadResponse: Codable, Sendable, Equatable {
    public var sessionId: String
    public var files: [String: String]
    
    public init(sessionId: String, files: [String: String]) {
        self.sessionId = sessionId
        self.files = files
    }
}

// MARK: - Register DTO (Unicast / HTTP Registration)
public struct LocalShareRegisterDto: Codable, Sendable, Equatable {
    public var alias: String
    public var version: String
    public var deviceModel: String?
    public var deviceType: LocalShareDeviceType?
    public var fingerprint: String
    public var port: Int?
    public var `protocol`: String?
    public var download: Bool?
    
    public init(
        alias: String,
        version: String = LocalShareConstants.protocolVersion,
        deviceModel: String? = "macOS",
        deviceType: LocalShareDeviceType? = .desktop,
        fingerprint: String,
        port: Int? = Int(LocalShareConstants.defaultHttpPort),
        protocol: String? = "https",
        download: Bool? = false
    ) {
        self.alias = alias
        self.version = version
        self.deviceModel = deviceModel
        self.deviceType = deviceType
        self.fingerprint = fingerprint
        self.port = port
        self.`protocol` = `protocol`
        self.download = download
    }
    
    public init(from info: LocalShareDeviceInfo) {
        self.alias = info.alias
        self.version = info.version
        self.deviceModel = info.deviceModel
        self.deviceType = info.deviceType
        self.fingerprint = info.fingerprint
        self.port = info.port
        self.`protocol` = info.`protocol`
        self.download = info.download
    }
}

// MARK: - Discovered Peer Model
public struct LocalShareDiscoveredPeer: Identifiable, Sendable, Equatable {
    public var id: String { fingerprint }
    public var alias: String
    public var deviceModel: String?
    public var deviceType: LocalShareDeviceType
    public var fingerprint: String
    public var host: String
    public var port: UInt16
    public var `protocol`: String
    public var download: Bool
    public var lastSeen: Date
    public var isFavorite: Bool
    
    public init(
        alias: String,
        deviceModel: String?,
        deviceType: LocalShareDeviceType,
        fingerprint: String,
        host: String,
        port: UInt16,
        protocol: String = "https",
        download: Bool = false,
        lastSeen: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.alias = alias
        self.deviceModel = deviceModel
        self.deviceType = deviceType
        self.fingerprint = fingerprint
        self.host = host
        self.port = port
        self.`protocol` = `protocol`
        self.download = download
        self.lastSeen = lastSeen
        self.isFavorite = isFavorite
    }
    
    public var baseURL: URL? {
        let cleanHost = LocalShareSecurity.formatHostForURL(host)
        return URL(string: "\(`protocol`)://\(cleanHost):\(port)")
    }
}

// MARK: - Protocol Errors
public enum LocalShareError: LocalizedError, Sendable, Equatable {
    case invalidURL
    case invalidBody
    case pinRequired
    case invalidPin
    case rejected
    case blockedByAnotherSession
    case rateLimited
    case checksumMismatch
    case fileTooLarge(Int64)
    case fileCountExceeded(Int)
    case insufficientDiskSpace
    case sessionCancelled
    case sessionNotFound
    case tokenMismatch
    case peerCertificateMismatch(expected: String, found: String)
    case fileExists
    case invalidFileName
    case serverError(String)
    case connectionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid target URL"
        case .invalidBody:
            return "Malformed or unreadable request payload"
        case .pinRequired:
            return "A transfer PIN is required by recipient"
        case .invalidPin:
            return "Invalid PIN provided"
        case .rejected:
            return "Transfer was declined by recipient"
        case .blockedByAnotherSession:
            return "Recipient is currently engaged in another transfer session"
        case .rateLimited:
            return "Too many requests; rate limited"
        case .checksumMismatch:
            return "File verification checksum mismatch (SHA-256)"
        case .fileTooLarge(let size):
            return "File exceeds maximum permitted size (\(size) bytes)"
        case .fileCountExceeded(let count):
            return "Session file count exceeds maximum permitted (\(count))"
        case .insufficientDiskSpace:
            return "Insufficient free disk capacity to receive files"
        case .sessionCancelled:
            return "Transfer session was cancelled"
        case .sessionNotFound:
            return "Transfer session expired or not found"
        case .tokenMismatch:
            return "Invalid transfer token or authorization"
        case .peerCertificateMismatch(let expected, _):
            return "Peer certificate verification failed (expected fingerprint \(expected.prefix(8))...)"
        case .fileExists:
            return "Destination file already exists on disk"
        case .invalidFileName:
            return "Invalid or malformed file name"
        case .serverError(let msg):
            return "Server error: \(msg)"
        case .connectionFailed(let msg):
            return "Network connection failed: \(msg)"
        }
    }
}
