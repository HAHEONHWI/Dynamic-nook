import CryptoKit
import Foundation
import LicenseCore
import Security

private let service = "dev.dynamicnook.licenseissuer"
private let account = "issuer-private-key-v1"
private let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecReturnData as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne
]
var result: CFTypeRef?
guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data else {
    FileHandle.standardError.write(Data("Issuer key not found. Run the private issuer app once first.\n".utf8))
    exit(1)
}

let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: data)
let publicKey = privateKey.publicKey.rawRepresentation.base64URLString
guard publicKey == LicenseAuthority.issuerPublicKeyBase64URL else {
    FileHandle.standardError.write(Data("Issuer key does not match the public app key.\n".utf8))
    exit(1)
}

let jwk: [String: Any] = [
    "crv": "Ed25519",
    "d": privateKey.rawRepresentation.base64URLString,
    "ext": true,
    "key_ops": ["sign"],
    "kty": "OKP",
    "x": publicKey
]
let json = try JSONSerialization.data(withJSONObject: jwk, options: [.sortedKeys])
FileHandle.standardOutput.write(json)
