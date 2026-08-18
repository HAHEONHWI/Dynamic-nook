import CryptoKit
import Foundation
import LicenseCore
import Security

enum DeviceIdentityError: Error, LocalizedError {
    case keychain(OSStatus)
    case invalidStoredKey

    var errorDescription: String? {
        switch self {
        case .keychain(let status): "Device identity Keychain error: \(status)"
        case .invalidStoredKey: "The stored device identity is invalid."
        }
    }
}

struct DeviceIdentityService: Sendable {
    private let service = "dev.nookclone.app"
    private let account = "license-device-key-v1"

    func publicKeyData() throws -> Data {
        try loadOrCreateKey().publicKey.x963Representation
    }

    func makeRequestCode(now: Date = Date()) throws -> String {
        let key = try loadOrCreateKey()
        let payload = DeviceRequestPayload(
            product: LicenseTokenCodec.productIdentifier,
            devicePublicKey: key.publicKey.x963Representation.base64URLString,
            createdAt: Int64(now.timeIntervalSince1970)
        )
        let payloadData = try LicenseTokenCodec.deviceRequestPayloadData(payload)
        let signature = try key.signature(for: payloadData)
        return try LicenseTokenCodec.makeDeviceRequest(
            payload: payload,
            signatureDER: signature.derRepresentation
        )
    }

    private func loadOrCreateKey() throws -> P256.Signing.PrivateKey {
        if let data = try readKey() {
            do {
                return try P256.Signing.PrivateKey(rawRepresentation: data)
            } catch {
                throw DeviceIdentityError.invalidStoredKey
            }
        }

        let key = P256.Signing.PrivateKey()
        try writeKey(key.rawRepresentation)
        return key
    }

    private func readKey() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw DeviceIdentityError.keychain(status)
        }
        return data
    }

    private func writeKey(_ data: Data) throws {
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw DeviceIdentityError.keychain(status)
        }
    }
}
