import Foundation
import Security
import CryptoKit
import Network
import LocalAuthentication

// MARK: - C ABI Dynamic Bindings for Legacy Keychain API (Silencing Deprecation Diagnostics)
@_silgen_name("SecKeychainGetUserInteractionAllowed")
private func sys_SecKeychainGetUserInteractionAllowed(_ state: UnsafeMutablePointer<DarwinBoolean>) -> OSStatus

@_silgen_name("SecKeychainSetUserInteractionAllowed")
private func sys_SecKeychainSetUserInteractionAllowed(_ state: DarwinBoolean) -> OSStatus

// MARK: - Reentrant Thread-Safe Keychain Interaction Governor
final class KeychainInteractionGovernor: @unchecked Sendable {
    static let shared = KeychainInteractionGovernor()
    private let lock = NSRecursiveLock()
    private var depth = 0
    private var originalState: DarwinBoolean = true

    func withInteractionDisabled<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }

        if depth == 0 {
            _ = sys_SecKeychainGetUserInteractionAllowed(&originalState)
            _ = sys_SecKeychainSetUserInteractionAllowed(false)
        }
        depth += 1

        defer {
            depth -= 1
            if depth == 0 {
                _ = sys_SecKeychainSetUserInteractionAllowed(originalState)
            }
        }

        return try body()
    }
}

// MARK: - LocalShare ASN.1 DER Encoding Helpers
private enum ASN1 {
    static func length(_ length: Int) -> Data {
        if length < 128 {
            return Data([UInt8(length)])
        } else if length < 256 {
            return Data([0x81, UInt8(length)])
        } else {
            return Data([0x82, UInt8(length >> 8), UInt8(length & 0xFF)])
        }
    }
    
    static func sequence(_ elements: [Data]) -> Data {
        let body = elements.reduce(Data(), +)
        var result = Data([0x30])
        result.append(length(body.count))
        result.append(body)
        return result
    }
    
    static func set(_ elements: [Data]) -> Data {
        let body = elements.reduce(Data(), +)
        var result = Data([0x31])
        result.append(length(body.count))
        result.append(body)
        return result
    }
    
    static func integer(_ value: Int) -> Data {
        if value < 128 {
            return Data([0x02, 0x01, UInt8(value)])
        }
        var val = value
        var bytes: [UInt8] = []
        while val > 0 {
            bytes.insert(UInt8(val & 0xFF), at: 0)
            val >>= 8
        }
        if let first = bytes.first, first >= 0x80 {
            bytes.insert(0x00, at: 0)
        }
        var result = Data([0x02])
        result.append(length(bytes.count))
        result.append(contentsOf: bytes)
        return result
    }
    
    static func bitString(_ data: Data) -> Data {
        var result = Data([0x03])
        result.append(length(data.count + 1))
        result.append(0x00) // 0 unused bits
        result.append(data)
        return result
    }
    
    static func oid(_ bytes: [UInt8]) -> Data {
        var result = Data([0x06])
        result.append(length(bytes.count))
        result.append(contentsOf: bytes)
        return result
    }
    
    static func printableString(_ str: String) -> Data {
        let utf = Data(str.utf8)
        var result = Data([0x13])
        result.append(length(utf.count))
        result.append(utf)
        return result
    }
    
    static func utcTime(_ dateStr: String) -> Data {
        let utf = Data(dateStr.utf8)
        var result = Data([0x17])
        result.append(length(utf.count))
        result.append(utf)
        return result
    }
}

// MARK: - Native TLS Identity Manager
public final class LocalShareIdentityManager: @unchecked Sendable {
    public static let shared = LocalShareIdentityManager()
    
    private let lock = NSLock()
    public let serviceName: String
    private let fallbackPrefix: String
    private let keyAccount = "localshare_p256_private_key"
    private let certAccount = "localshare_x509_certificate"
    
    private var cachedFingerprint: String?
    private var cachedCertificateDER: Data?
    private var cachedIdentity: SecIdentity?
    
    public init(serviceName: String = "com.notch.NotchApp.LocalShare") {
        self.serviceName = serviceName
        if serviceName == "com.notch.NotchApp.LocalShare" {
            self.fallbackPrefix = "NotchApp_LocalShare_Fallback_"
        } else {
            self.fallbackPrefix = "NotchApp_LocalShare_Fallback_\(serviceName)_"
        }
    }
    
    // MARK: - Public Identity Accessors
    
    /// Returns the SHA-256 fingerprint of the self-signed certificate (lowercase hex).
    public var certificateFingerprint: String {
        lock.lock()
        defer { lock.unlock() }
        if let fp = cachedFingerprint {
            return fp
        }
        let (certData, _) = loadOrGenerateIdentityLocked()
        let digest = SHA256.hash(data: certData)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        cachedFingerprint = hex
        return hex
    }
    
    /// Returns the DER-encoded X.509 certificate data.
    public var certificateDER: Data {
        lock.lock()
        defer { lock.unlock() }
        if let der = cachedCertificateDER {
            return der
        }
        let (certData, _) = loadOrGenerateIdentityLocked()
        return certData
    }
    
    /// Returns a SecIdentityRef suitable for TLS listeners and clients.
    public func getSecIdentity() -> SecIdentity? {
        lock.lock()
        defer { lock.unlock() }
        if let ident = cachedIdentity {
            return ident
        }
        let (_, ident) = loadOrGenerateIdentityLocked()
        return ident
    }
    
    /// Creates a Network.framework sec_identity_t for NWProtocolTLS.Options.
    public func createNetworkIdentity() -> sec_identity_t? {
        guard let secIdentity = getSecIdentity() else { return nil }
        return sec_identity_create(secIdentity)
    }
    
    // MARK: - Internal Key & Certificate Generation / Persistence
    
    @discardableResult
    private func withUserInteractionDisabled<T>(_ body: () -> T) -> T {
        return KeychainInteractionGovernor.shared.withInteractionDisabled(body)
    }
    
    private func loadOrGenerateIdentityLocked() -> (Data, SecIdentity?) {
        return withUserInteractionDisabled {
            // 1. Try the existing Keychain identity first.
            let keychainCert = loadKeychainData(account: certAccount)
            let keychainKey = loadKeychainData(account: keyAccount)

            if let certData = keychainCert,
               let keyData = keychainKey,
               let identity = assembleIdentity(
                    certDER: certData,
                    privateKeyRaw: keyData
               ) {
                cachedCertificateDER = certData
                cachedIdentity = identity

                let digest = SHA256.hash(data: certData)
                cachedFingerprint = digest.map {
                    String(format: "%02x", $0)
                }.joined()

                removeFallbackData(account: certAccount)
                removeFallbackData(account: keyAccount)

                return (certData, identity)
            }

            // 2. Recover the previous identity from fallback storage.
            if let fallbackCert = loadFallbackData(account: certAccount),
               let fallbackKey = loadFallbackData(account: keyAccount),
               let identity = assembleIdentity(
                    certDER: fallbackCert,
                    privateKeyRaw: fallbackKey
               ) {

                cachedCertificateDER = fallbackCert
                cachedIdentity = identity

                let digest = SHA256.hash(data: fallbackCert)
                cachedFingerprint = digest.map {
                    String(format: "%02x", $0)
                }.joined()

                let certSaved = saveKeychainData(fallbackCert, account: certAccount)
                let keySaved = saveKeychainData(fallbackKey, account: keyAccount)
                if certSaved && keySaved {
                    removeFallbackData(account: certAccount)
                    removeFallbackData(account: keyAccount)
                }

                return (fallbackCert, identity)
            }

            // 3. Create a new identity only when no recoverable identity exists.
            let privateKey = P256.Signing.PrivateKey()
            let certDER = buildSelfSignedCertificateDER(
                privateKey: privateKey
            )
            let keyRaw = privateKey.x963Representation

            let identity = assembleIdentity(
                certDER: certDER,
                privateKeyRaw: keyRaw
            )

            cachedCertificateDER = certDER
            cachedIdentity = identity

            let digest = SHA256.hash(data: certDER)
            cachedFingerprint = digest.map {
                String(format: "%02x", $0)
            }.joined()

            _ = saveKeychainData(certDER, account: certAccount)
            _ = saveKeychainData(keyRaw, account: keyAccount)

            return (certDER, identity)
        }
    }
    
    private func assembleIdentity(certDER: Data, privateKeyRaw: Data) -> SecIdentity? {
        guard let cert = SecCertificateCreateWithData(nil, certDER as CFData) else {
            return nil
        }
        
        let keyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        guard let secKey = SecKeyCreateWithData(privateKeyRaw as CFData, keyAttributes as CFDictionary, nil) else {
            return nil
        }
        
        return SecIdentityCreate(kCFAllocatorDefault, cert, secKey)
    }
    
    private func buildSelfSignedCertificateDER(privateKey: P256.Signing.PrivateKey) -> Data {
        // ecdsaWithSHA256: 1.2.840.10045.4.3.2 -> 2A 86 48 CE 3D 04 03 02
        let ecdsaWithSHA256OID = ASN1.oid([0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02])
        let algId = ASN1.sequence([ecdsaWithSHA256OID])
        
        // ecPublicKey: 1.2.840.10045.2.1 -> 2A 86 48 CE 3D 02 01
        let ecPublicKeyOID = ASN1.oid([0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01])
        // secp256r1: 1.2.840.10045.3.1.7 -> 2A 86 48 CE 3D 03 01 07
        let secp256r1OID = ASN1.oid([0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07])
        let ecKeyAlgId = ASN1.sequence([ecPublicKeyOID, secp256r1OID])
        
        let rawPub = privateKey.publicKey.x963Representation
        let spki = ASN1.sequence([ecKeyAlgId, ASN1.bitString(rawPub)])
        
        // Common Name RDN: CN=LocalShare
        // id-at-commonName: 2.5.4.3 -> 55 04 03
        let cnOID = ASN1.oid([0x55, 0x04, 0x03])
        let rdn = ASN1.set([ASN1.sequence([cnOID, ASN1.printableString("LocalShare")])])
        let name = ASN1.sequence([rdn])
        
        // 10-year validity window
        let validity = ASN1.sequence([ASN1.utcTime("240101000000Z"), ASN1.utcTime("350101000000Z")])
        let serial = ASN1.integer(Int.random(in: 1000...999999))
        
        // Version 3: [0] EXPLICIT INTEGER (2)
        let versionTag = Data([0xA0, 0x03, 0x02, 0x01, 0x02])
        
        let tbs = ASN1.sequence([
            versionTag,
            serial,
            algId,
            name,
            validity,
            name,
            spki
        ])
        
        let signatureData: Data
        if let sig = try? privateKey.signature(for: tbs) {
            signatureData = sig.derRepresentation
        } else {
            signatureData = Data()
        }
        
        return ASN1.sequence([
            tbs,
            algId,
            ASN1.bitString(signatureData)
        ])
    }
    
    // MARK: - Keychain & Fallback Persistence
    
    private func nonInteractiveContext() -> LAContext {
        let ctx = LAContext()
        ctx.interactionNotAllowed = true
        return ctx
    }
    
    private func logKeychain(op: String, account: String, status: OSStatus) {
        #if DEBUG
        if status != errSecSuccess && status != errSecItemNotFound {
            print("[LocalShareIdentity] Keychain \(op) for account '\(account)' returned OSStatus \(status)")
        }
        #endif
    }
    
    @discardableResult
    private func saveKeychainData(
        _ data: Data,
        account: String
    ) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        // Delete any existing item first to ensure current binary ownership and avoid stale ACL prompts
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(
            addQuery as CFDictionary,
            nil
        )

        if addStatus == errSecSuccess {
            removeFallbackData(account: account)
            return true
        }

        logKeychain(
            op: "add",
            account: account,
            status: addStatus
        )

        return false
    }

    private func loadKeychainData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?

        let status = SecItemCopyMatching(
            query as CFDictionary,
            &item
        )

        logKeychain(
            op: "load",
            account: account,
            status: status
        )

        if status == errSecSuccess, let data = item as? Data {
            return data
        }

        return nil
    }

    private func removeFallbackData(account: String) {
        let key = "\(fallbackPrefix)\(account)"
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func saveFallbackData(_ data: Data, account: String) {
        let key = "\(fallbackPrefix)\(account)"
        UserDefaults.standard.set(data, forKey: key)
        if serviceName == "com.notch.NotchApp.LocalShare" {
            UserDefaults(suiteName: "NotchApp")?.set(data, forKey: key)
        }
    }

    private func loadFallbackData(account: String) -> Data? {
        let key = "\(fallbackPrefix)\(account)"
        if let data = UserDefaults.standard.data(forKey: key) {
            return data
        }
        if serviceName == "com.notch.NotchApp.LocalShare" {
            if let data = UserDefaults(suiteName: "NotchApp")?.data(forKey: key) {
                return data
            }
        }
        return nil
    }
    
    public func resetIdentityForTesting() {
        lock.lock()
        defer { lock.unlock() }
        cachedFingerprint = nil
        cachedCertificateDER = nil
        cachedIdentity = nil
        
        // Safety guard: Never delete production identity from Keychain or UserDefaults
        guard serviceName != "com.notch.NotchApp.LocalShare" else {
            #if DEBUG
            print("[LocalShareIdentity] Safety invariant: Refusing to reset production identity via resetIdentityForTesting()")
            #endif
            return
        }
        
        for account in [keyAccount, certAccount] {
            let q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(q as CFDictionary)
            UserDefaults.standard.removeObject(forKey: "\(fallbackPrefix)\(account)")
        }
    }
}
