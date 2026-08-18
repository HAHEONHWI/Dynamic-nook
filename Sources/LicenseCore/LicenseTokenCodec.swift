import CryptoKit
import Foundation

public enum LicenseTokenCodec {
    public static let productIdentifier = "dynamic-nook"
    private static let requestPrefix = "DNR1"
    private static let licensePrefix = "DNL1"

    public static func makeDeviceRequest(
        payload: DeviceRequestPayload,
        signatureDER: Data
    ) throws -> String {
        let payloadData = try deviceRequestPayloadData(payload)
        return [requestPrefix, payloadData.base64URLString, signatureDER.base64URLString]
            .joined(separator: ".")
    }

    public static func deviceRequestPayloadData(_ payload: DeviceRequestPayload) throws -> Data {
        try makeEncoder().encode(payload)
    }

    public static func verifyDeviceRequest(_ token: String) throws -> VerifiedDeviceRequest {
        let (payloadData, signatureData) = try split(token, prefix: requestPrefix)
        let payload = try decode(DeviceRequestPayload.self, from: payloadData)
        guard payload.version == 1 else { throw LicenseValidationError.unsupportedVersion }
        guard payload.product == productIdentifier else { throw LicenseValidationError.wrongProduct }
        guard let publicKeyData = Data(base64URLString: payload.devicePublicKey) else {
            throw LicenseValidationError.invalidRequest
        }

        do {
            let publicKey = try P256.Signing.PublicKey(x963Representation: publicKeyData)
            let signature = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
            guard publicKey.isValidSignature(signature, for: payloadData) else {
                throw LicenseValidationError.invalidSignature
            }
        } catch let error as LicenseValidationError {
            throw error
        } catch {
            throw LicenseValidationError.invalidRequest
        }

        return VerifiedDeviceRequest(
            payload: payload,
            devicePublicKey: publicKeyData,
            deviceKeyHash: deviceKeyHash(publicKeyData)
        )
    }

    public static func issueLicense(
        payload: LicensePayload,
        issuerPrivateKey: Curve25519.Signing.PrivateKey
    ) throws -> String {
        guard payload.version == 1 || payload.version == 2 else {
            throw LicenseValidationError.unsupportedVersion
        }
        guard payload.product == productIdentifier else { throw LicenseValidationError.wrongProduct }
        guard payload.tier == "pro" else { throw LicenseValidationError.unsupportedTier }
        if payload.kind == .standard, payload.deviceKeyHash == nil {
            throw LicenseValidationError.missingDeviceBinding
        }
        let payloadData = try makeEncoder().encode(payload)
        let signature = try issuerPrivateKey.signature(for: payloadData)
        return [licensePrefix, payloadData.base64URLString, signature.base64URLString]
            .joined(separator: ".")
    }

    public static func verifyLicense(
        _ token: String,
        issuerPublicKey: Curve25519.Signing.PublicKey,
        currentDevicePublicKey: Data? = nil,
        now: Date = Date()
    ) throws -> LicensePayload {
        let (payloadData, signature) = try split(token, prefix: licensePrefix)
        guard issuerPublicKey.isValidSignature(signature, for: payloadData) else {
            throw LicenseValidationError.invalidSignature
        }

        let payload = try decode(LicensePayload.self, from: payloadData)
        guard payload.version == 1 || payload.version == 2 else {
            throw LicenseValidationError.unsupportedVersion
        }
        guard payload.product == productIdentifier else { throw LicenseValidationError.wrongProduct }
        guard payload.tier == "pro" else { throw LicenseValidationError.unsupportedTier }
        guard payload.issuedAt <= Int64(now.timeIntervalSince1970) + 300 else {
            throw LicenseValidationError.issuedInFuture
        }
        if let expiresAt = payload.expiresAt,
           Int64(now.timeIntervalSince1970) > expiresAt {
            throw LicenseValidationError.expired
        }
        if payload.version == 2 {
            guard let validatedUntil = payload.validatedUntil,
                  Int64(now.timeIntervalSince1970) <= validatedUntil else {
                throw LicenseValidationError.serverValidationRequired
            }
        }

        if payload.kind == .standard {
            guard let expectedHash = payload.deviceKeyHash else {
                throw LicenseValidationError.missingDeviceBinding
            }
            guard let currentDevicePublicKey else {
                throw LicenseValidationError.wrongDevice
            }
            guard expectedHash == deviceKeyHash(currentDevicePublicKey) else {
                throw LicenseValidationError.wrongDevice
            }
        }
        return payload
    }

    public static func deviceKeyHash(_ publicKey: Data) -> String {
        Data(SHA256.hash(data: publicKey)).base64URLString
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw LicenseValidationError.malformedToken
        }
    }

    private static func split(_ token: String, prefix: String) throws -> (Data, Data) {
        let parts = token.trimmingCharacters(in: .whitespacesAndNewlines).split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard parts.count == 3,
              parts[0] == Substring(prefix),
              let payload = Data(base64URLString: String(parts[1])),
              let signature = Data(base64URLString: String(parts[2])),
              !payload.isEmpty,
              !signature.isEmpty else {
            throw LicenseValidationError.malformedToken
        }
        return (payload, signature)
    }
}

public extension Data {
    var base64URLString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLString: String) {
        guard !base64URLString.isEmpty else { return nil }
        var value = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = value.count % 4
        if remainder != 0 { value += String(repeating: "=", count: 4 - remainder) }
        self.init(base64Encoded: value, options: [])
    }
}
