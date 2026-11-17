import Foundation
import Security

// MARK: - LocalShare Transfer History Item
public struct LocalShareHistoryItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let peerAlias: String
    public let fileNames: [String]
    public let totalBytes: Int64
    public let date: Date
    public let isOutgoing: Bool
    public let statusText: String
    
    public init(
        id: UUID = UUID(),
        peerAlias: String,
        fileNames: [String],
        totalBytes: Int64,
        date: Date = Date(),
        isOutgoing: Bool,
        statusText: String
    ) {
        self.id = id
        self.peerAlias = peerAlias
        self.fileNames = fileNames
        self.totalBytes = totalBytes
        self.date = date
        self.isOutgoing = isOutgoing
        self.statusText = statusText
    }
}

// MARK: - Explicit Peer Trust State & Identity Record
public enum LocalSharePeerTrustState: String, Codable, Sendable {
    case unverifiedFirstContact
    case trusted
    case certificateChanged
    case blocked
}

public struct LocalShareTrustedPeer: Codable, Sendable, Identifiable {
    public var id: String { fingerprint }
    public let alias: String
    public let fingerprint: String
    public let deviceModel: String?
    public let firstSeen: Date
    public var lastSeen: Date
    public var trustState: LocalSharePeerTrustState
    
    public init(
        alias: String,
        fingerprint: String,
        deviceModel: String? = nil,
        firstSeen: Date = Date(),
        lastSeen: Date = Date(),
        trustState: LocalSharePeerTrustState = .trusted
    ) {
        self.alias = alias
        self.fingerprint = fingerprint
        self.deviceModel = deviceModel
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.trustState = trustState
    }
}

// MARK: - LocalShare Module Persistent Settings
@MainActor
public final class LocalShareSettings: ObservableObject {
    public static let shared = LocalShareSettings()
    
    public let serviceName: String
    private let fallbackKey: String
    private let pinAccount = "localshare_pin_code"
    private var cachedPin: String?
    
    @Published public var alias: String {
        didSet {
            let sanitized = LocalShareSecurity.sanitizeAlias(alias)
            UserDefaults.standard.set(sanitized, forKey: "NotchApp_LocalShare_Alias")
            LocalShareServer.shared.serverAlias = sanitized
            LocalShareDiscovery.shared.localAlias = sanitized
            LocalShareClient.shared.localAlias = sanitized
            LocalShareDiscovery.shared.sendAnnouncement(isInitial: true)
            if alias != sanitized {
                alias = sanitized
            }
        }
    }
    
    @Published public var customReceivePath: String {
        didSet {
            UserDefaults.standard.set(customReceivePath, forKey: "NotchApp_LocalShare_ReceiveFolder")
            if customReceivePath.isEmpty {
                LocalShareFileManager.shared.setCustomReceiveFolder(nil)
            } else {
                LocalShareFileManager.shared.setCustomReceiveFolder(URL(fileURLWithPath: customReceivePath))
            }
        }
    }
    
    @Published public var isReceiveEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isReceiveEnabled, forKey: "NotchApp_LocalShare_ReceiveEnabled")
            syncReceiveServer()
        }
    }
    
    @Published public var favoriteFingerprints: [String] {
        didSet {
            UserDefaults.standard.set(favoriteFingerprints, forKey: "NotchApp_LocalShare_Favorites")
            LocalShareServer.shared.favoriteFingerprints = Set(favoriteFingerprints)
        }
    }
    
    @Published public var trustedPeers: [String: LocalShareTrustedPeer] {
        didSet {
            if let data = try? JSONEncoder().encode(trustedPeers) {
                UserDefaults.standard.set(data, forKey: "NotchApp_LocalShare_TrustedPeers")
            }
            LocalShareServer.shared.trustedPeers = trustedPeers
        }
    }
    
    @Published public var autoAcceptFavorites: Bool {
        didSet {
            UserDefaults.standard.set(autoAcceptFavorites, forKey: "NotchApp_LocalShare_AutoAcceptFavorites")
            LocalShareServer.shared.autoAcceptFavorites = autoAcceptFavorites
        }
    }
    
    @Published public var isPinEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPinEnabled, forKey: "NotchApp_LocalShare_PinEnabled")
            syncPinToServer()
        }
    }
    
    @Published public var pinCode: String {
        didSet {
            let filtered = pinCode.filter { $0.isNumber || $0.isLetter }.prefix(8)
            let finalPin = String(filtered)
            if pinCode != finalPin {
                pinCode = finalPin
                return
            }
            savePinToKeychain(finalPin)
            syncPinToServer()
        }
    }
    
    @Published public var tcpPort: UInt16 {
        didSet {
            UserDefaults.standard.set(Int(tcpPort), forKey: "NotchApp_LocalShare_Port")
            if isReceiveEnabled && LocalShareServer.shared.isRunning {
                LocalShareServer.shared.restart(port: tcpPort)
            }
        }
    }
    
    public init(serviceName: String = "com.notch.NotchApp.LocalShare") {
        self.serviceName = serviceName
        if serviceName == "com.notch.NotchApp.LocalShare" {
            self.fallbackKey = "NotchApp_LocalShare_Fallback_localshare_pin_code"
        } else {
            self.fallbackKey = "NotchApp_LocalShare_Fallback_\(serviceName)_localshare_pin_code"
        }
        let defaults = UserDefaults.standard
        let defaultHostName = Host.current().localizedName ?? "MacBook"
        let savedAlias = defaults.string(forKey: "NotchApp_LocalShare_Alias") ?? defaultHostName
        self.alias = LocalShareSecurity.sanitizeAlias(savedAlias)
        
        self.customReceivePath = defaults.string(forKey: "NotchApp_LocalShare_ReceiveFolder") ?? ""
        self.isReceiveEnabled = defaults.bool(forKey: "NotchApp_LocalShare_ReceiveEnabled")
        self.favoriteFingerprints = defaults.stringArray(forKey: "NotchApp_LocalShare_Favorites") ?? []
        self.autoAcceptFavorites = defaults.bool(forKey: "NotchApp_LocalShare_AutoAcceptFavorites")
        self.isPinEnabled = defaults.bool(forKey: "NotchApp_LocalShare_PinEnabled")
        
        if let data = defaults.data(forKey: "NotchApp_LocalShare_TrustedPeers"),
           let peers = try? JSONDecoder().decode([String: LocalShareTrustedPeer].self, from: data) {
            self.trustedPeers = peers
        } else {
            self.trustedPeers = [:]
        }
        
        let savedPort = defaults.integer(forKey: "NotchApp_LocalShare_Port")
        self.tcpPort = savedPort > 0 ? UInt16(savedPort) : LocalShareConstants.defaultHttpPort
        
        // Load PIN from Keychain directly via Data Protection Keychain with safe fallback migration
        let loadedPin = Self.loadAndMigratePin(service: serviceName, account: pinAccount, fallbackKey: fallbackKey)
        self.cachedPin = loadedPin.isEmpty ? nil : loadedPin
        self._pinCode = Published(initialValue: loadedPin)
        
        // Propagate loaded defaults to singletons
        LocalShareServer.shared.serverAlias = self.alias
        LocalShareDiscovery.shared.localAlias = self.alias
        LocalShareClient.shared.localAlias = self.alias
        LocalShareServer.shared.favoriteFingerprints = Set(self.favoriteFingerprints)
        LocalShareServer.shared.autoAcceptFavorites = self.autoAcceptFavorites
        LocalShareServer.shared.trustedPeers = self.trustedPeers
        if !self.customReceivePath.isEmpty {
            LocalShareFileManager.shared.setCustomReceiveFolder(URL(fileURLWithPath: self.customReceivePath))
        }
        syncPinToServer()
    }
    
    private func syncPinToServer() {
        if isPinEnabled && !pinCode.isEmpty {
            LocalShareServer.shared.requiredPin = pinCode
        } else {
            LocalShareServer.shared.requiredPin = nil
        }
    }
    
    public func syncReceiveServer() {
        if isReceiveEnabled {
            do {
                try LocalShareServer.shared.start(
                    port: tcpPort,
                    bindInterface: .localNetwork,
                    enableTLS: true
                )
            } catch {
                // Server start failure handled by caller
            }
        } else {
            LocalShareServer.shared.stop()
        }
    }
    
    public func addFavorite(fingerprint: String) {
        guard !fingerprint.isEmpty, !isFavorite(fingerprint: fingerprint) else { return }
        favoriteFingerprints.append(fingerprint)
    }
    
    public func isFavorite(fingerprint: String) -> Bool {
        return favoriteFingerprints.contains(where: { $0.caseInsensitiveCompare(fingerprint) == .orderedSame })
    }
    
    public func removeFavorite(fingerprint: String) {
        favoriteFingerprints.removeAll(where: { $0.caseInsensitiveCompare(fingerprint) == .orderedSame })
    }
    
    // MARK: - Explicit Peer Trust Policy
    
    /// Evaluates trust status for a peer:
    /// - `.trusted`: explicitly accepted by user.
    /// - `.blocked`: explicitly rejected / blocked.
    /// - `.certificateChanged`: previously trusted peer alias returned with a different certificate fingerprint!
    /// - `.unverifiedFirstContact`: first-time peer seen over network.
    public func trustStatus(for fingerprint: String, alias: String?) -> LocalSharePeerTrustState {
        return LocalShareServer.shared.trustStatus(for: fingerprint, alias: alias)
    }
    
    public func acceptAndTrustPeer(fingerprint: String, alias: String, deviceModel: String? = nil) {
        let record = LocalShareTrustedPeer(
            alias: alias,
            fingerprint: fingerprint,
            deviceModel: deviceModel,
            trustState: .trusted
        )
        trustedPeers[fingerprint.lowercased()] = record
        addFavorite(fingerprint: fingerprint)
    }
    
    public func blockPeer(fingerprint: String, alias: String, deviceModel: String? = nil) {
        let record = LocalShareTrustedPeer(
            alias: alias,
            fingerprint: fingerprint,
            deviceModel: deviceModel,
            trustState: .blocked
        )
        trustedPeers[fingerprint.lowercased()] = record
        removeFavorite(fingerprint: fingerprint)
    }
    
    public func removePeerTrust(fingerprint: String) {
        trustedPeers.removeValue(forKey: fingerprint.lowercased())
        removeFavorite(fingerprint: fingerprint)
    }
    
    public func resetToDefaults() {
        alias = Host.current().localizedName ?? "MacBook"
        customReceivePath = ""
        isReceiveEnabled = false
        favoriteFingerprints = []
        trustedPeers = [:]
        LocalShareServer.shared.trustedPeers = [:]
        UserDefaults.standard.removeObject(forKey: "NotchApp_LocalShare_TrustedPeers")
        autoAcceptFavorites = false
        isPinEnabled = false
        pinCode = ""
        tcpPort = LocalShareConstants.defaultHttpPort
        deletePinFromKeychain()
    }
    
    // MARK: - Native Keychain Persistence for PIN
    
    @discardableResult
    public func savePinToKeychain(_ pin: String) -> Bool {
        cachedPin = pin.isEmpty ? nil : pin
        
        if pin.isEmpty {
            deletePinFromKeychain()
            return true
        }
        
        guard let data = pin.data(using: .utf8) else { return false }
        
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: pinAccount
        ]
        SecItemDelete(searchQuery as CFDictionary)
        
        var addQuery = searchQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        var access: SecAccess?
        if SecAccessCreate("Notch LocalShare PIN" as CFString, nil, &access) == errSecSuccess, let acc = access {
            addQuery[kSecAttrAccess as String] = acc
        }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: fallbackKey)
            return true
        }
        return false
    }
    
    public func loadPinFromKeychain() -> String {
        if let cached = cachedPin, !cached.isEmpty {
            return cached
        }
        let pin = Self.loadAndMigratePin(service: serviceName, account: pinAccount, fallbackKey: fallbackKey)
        cachedPin = pin.isEmpty ? nil : pin
        return pin
    }
    
    private static func loadAndMigratePin(service: String, account: String, fallbackKey: String) -> String {
        // 1. Try Keychain first
        let keychainPin = loadPinFromKeychain(service: service, account: account)
        if !keychainPin.isEmpty {
            // Keychain has the PIN: safely clean up any leftover plaintext fallback
            if UserDefaults.standard.object(forKey: fallbackKey) != nil {
                UserDefaults.standard.removeObject(forKey: fallbackKey)
            }
            return keychainPin
        }
        
        // 2. If Keychain was empty, recover from legacy fallback storage
        if let fallbackPin = UserDefaults.standard.string(forKey: fallbackKey), !fallbackPin.isEmpty {
            // 3. Migrate fallback PIN into standard Keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: Data(fallbackPin.utf8),
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            let status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecSuccess {
                // Delete legacy fallback only after write succeeds
                UserDefaults.standard.removeObject(forKey: fallbackKey)
            }
            return fallbackPin
        }
        
        return ""
    }
    
    @discardableResult
    private static func withUserInteractionDisabled<T>(_ body: () -> T) -> T {
        return KeychainInteractionGovernor.shared.withInteractionDisabled(body)
    }
    
    private static func loadPinFromKeychain(service: String, account: String) -> String {
        return withUserInteractionDisabled {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecSuccess, let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                return str
            }
            return ""
        }
    }
    
    private func deletePinFromKeychain() {
        cachedPin = nil
        UserDefaults.standard.removeObject(forKey: fallbackKey)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: pinAccount
        ]
        SecItemDelete(query as CFDictionary)
        
        let dpQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: pinAccount,
            kSecUseDataProtectionKeychain as String: true
        ]
        SecItemDelete(dpQuery as CFDictionary)
    }
}
