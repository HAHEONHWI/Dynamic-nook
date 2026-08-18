import CryptoKit
import Foundation
import Security

enum IssuerKeyStore {
    private static let service = "dev.dynamicnook.licenseissuer"
    private static let account = "issuer-private-key-v1"

    static func loadOrCreate() throws -> Curve25519.Signing.PrivateKey {
        if let data = read() {
            return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        }

        let key = Curve25519.Signing.PrivateKey()
        try write(key.rawRepresentation)
        return key
    }

    private static func read() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    private static func write(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw IssuerError.keychain(status)
        }
    }
}

enum IssuerError: Error, LocalizedError {
    case keychain(OSStatus)
    case missingCustomerReference
    case wrongIssuerKey
    case randomGenerationFailed

    var errorDescription: String? {
        switch self {
        case .keychain(let status): "Keychain error: \(status)"
        case .missingCustomerReference: "Enter a customer or order reference."
        case .wrongIssuerKey: "This Mac has a different issuer key. Its licenses will not work in public builds."
        case .randomGenerationFailed: "A secure license key could not be generated."
        }
    }
}
