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

// MARK: - LocalShare Module Persistent Settings
@MainActor
public final class LocalShareSettings: ObservableObject {
    public static let shared = LocalShareSettings()
    
    private let serviceName = "com.notch.NotchApp.LocalShare"
    private let pinAccount = "localshare_pin_code"
    
    @Published public var alias: String {
        didSet {
            let sanitized = LocalShareSecurity.sanitizeAlias(alias)
            if alias != sanitized {
                alias = sanitized
                return
            }
            UserDefaults.standard.set(sanitized, forKey: "NotchApp_LocalShare_Alias")
            LocalShareServer.shared.serverAlias = sanitized
            LocalShareDiscovery.shared.localAlias = sanitized
            LocalShareClient.shared.localAlias = sanitized
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
            savePinToKeychain(finalPin)
            syncPinToServer()
        }
    }
    
    @Published public var tcpPort: UInt16 {
        didSet {
            UserDefaults.standard.set(Int(tcpPort), forKey: "NotchApp_LocalShare_Port")
        }
    }
    
    public init() {
        let defaults = UserDefaults.standard
        let defaultHostName = Host.current().localizedName ?? "MacBook"
        let savedAlias = defaults.string(forKey: "NotchApp_LocalShare_Alias") ?? defaultHostName
        self.alias = LocalShareSecurity.sanitizeAlias(savedAlias)
        
        self.customReceivePath = defaults.string(forKey: "NotchApp_LocalShare_ReceiveFolder") ?? ""
        self.isReceiveEnabled = defaults.bool(forKey: "NotchApp_LocalShare_ReceiveEnabled")
        self.favoriteFingerprints = defaults.stringArray(forKey: "NotchApp_LocalShare_Favorites") ?? []
        self.autoAcceptFavorites = defaults.bool(forKey: "NotchApp_LocalShare_AutoAcceptFavorites")
        self.isPinEnabled = defaults.bool(forKey: "NotchApp_LocalShare_PinEnabled")
        
        let savedPort = defaults.integer(forKey: "NotchApp_LocalShare_Port")
        self.tcpPort = savedPort > 0 ? UInt16(savedPort) : LocalShareConstants.defaultHttpPort
        
        // Load PIN from Keychain directly via Security framework
        self.pinCode = ""
        self.pinCode = loadPinFromKeychain()
        
        // Propagate loaded defaults to singletons
        LocalShareServer.shared.serverAlias = self.alias
        LocalShareDiscovery.shared.localAlias = self.alias
        LocalShareClient.shared.localAlias = self.alias
        LocalShareServer.shared.favoriteFingerprints = Set(self.favoriteFingerprints)
        LocalShareServer.shared.autoAcceptFavorites = self.autoAcceptFavorites
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
    
    public func resetToDefaults() {
        alias = Host.current().localizedName ?? "MacBook"
        customReceivePath = ""
        isReceiveEnabled = false
        favoriteFingerprints = []
        autoAcceptFavorites = false
        isPinEnabled = false
        pinCode = ""
        tcpPort = LocalShareConstants.defaultHttpPort
        deletePinFromKeychain()
    }
    
    // MARK: - Native Keychain Persistence for PIN
    
    private func savePinToKeychain(_ pin: String) {
        guard let data = pin.data(using: .utf8) else { return }
        deletePinFromKeychain()
        guard !pin.isEmpty else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: pinAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func loadPinFromKeychain() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: pinAccount,
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
    
    private func deletePinFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: pinAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
