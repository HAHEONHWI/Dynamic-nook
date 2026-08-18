import Foundation

public enum LicenseKind: String, Codable, CaseIterable, Sendable {
    case standard
    case master
}

public struct DeviceRequestPayload: Codable, Equatable, Sendable {
    public let version: Int
    public let product: String
    public let devicePublicKey: String
    public let nonce: String
    public let createdAt: Int64

    public init(
        version: Int = 1,
        product: String,
        devicePublicKey: String,
        nonce: String = UUID().uuidString,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970)
    ) {
        self.version = version
        self.product = product
        self.devicePublicKey = devicePublicKey
        self.nonce = nonce
        self.createdAt = createdAt
    }
}

public struct VerifiedDeviceRequest: Equatable, Sendable {
    public let payload: DeviceRequestPayload
    public let devicePublicKey: Data
    public let deviceKeyHash: String
}

public struct LicensePayload: Codable, Equatable, Sendable {
    public let version: Int
    public let licenseID: String
    public let product: String
    public let kind: LicenseKind
    public let tier: String
    public let customerReference: String
    public let deviceKeyHash: String?
    public let issuedAt: Int64
    public let expiresAt: Int64?
    public let validatedUntil: Int64?

    public init(
        version: Int = 1,
        licenseID: String = UUID().uuidString,
        product: String,
        kind: LicenseKind,
        tier: String = "pro",
        customerReference: String,
        deviceKeyHash: String?,
        issuedAt: Int64 = Int64(Date().timeIntervalSince1970),
        expiresAt: Int64?,
        validatedUntil: Int64? = nil
    ) {
        self.version = version
        self.licenseID = licenseID
        self.product = product
        self.kind = kind
        self.tier = tier
        self.customerReference = customerReference
        self.deviceKeyHash = deviceKeyHash
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.validatedUntil = validatedUntil
    }

    public var expirationDate: Date? {
        expiresAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }
}

public enum LicenseValidationError: Error, LocalizedError, Equatable {
    case malformedToken
    case unsupportedVersion
    case invalidSignature
    case invalidRequest
    case wrongProduct
    case unsupportedTier
    case wrongDevice
    case expired
    case issuedInFuture
    case missingDeviceBinding
    case invalidExpirationDate
    case serverValidationRequired

    public var errorDescription: String? {
        switch self {
        case .malformedToken: "The license key format is invalid."
        case .unsupportedVersion: "This license key version is not supported."
        case .invalidSignature: "The license signature is invalid."
        case .invalidRequest: "The device request code is invalid."
        case .wrongProduct: "This key belongs to a different product."
        case .unsupportedTier: "A Dynamic Nook Pro license is required."
        case .wrongDevice: "This key was issued for a different Mac."
        case .expired: "This license has expired."
        case .issuedInFuture: "The license issue date is invalid."
        case .missingDeviceBinding: "A standard license must be bound to a Mac."
        case .invalidExpirationDate: "Choose today or a future expiration date."
        case .serverValidationRequired: "Connect to the internet to validate this license."
        }
    }
}
