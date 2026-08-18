import CryptoKit
import LicenseCore
@testable import NookClone
import XCTest

final class LicenseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testSignedDeviceRequestRoundTrip() throws {
        let deviceKey = P256.Signing.PrivateKey()
        let payload = DeviceRequestPayload(
            product: LicenseTokenCodec.productIdentifier,
            devicePublicKey: deviceKey.publicKey.x963Representation.base64URLString,
            createdAt: Int64(now.timeIntervalSince1970)
        )
        let data = try LicenseTokenCodec.deviceRequestPayloadData(payload)
        let token = try LicenseTokenCodec.makeDeviceRequest(
            payload: payload,
            signatureDER: try deviceKey.signature(for: data).derRepresentation
        )

        let verified = try LicenseTokenCodec.verifyDeviceRequest(token)
        XCTAssertEqual(verified.payload, payload)
        XCTAssertEqual(verified.deviceKeyHash, LicenseTokenCodec.deviceKeyHash(deviceKey.publicKey.x963Representation))
    }

    func testStandardLicenseOnlyWorksOnRequestedMac() throws {
        let issuer = Curve25519.Signing.PrivateKey()
        let firstMac = P256.Signing.PrivateKey().publicKey.x963Representation
        let secondMac = P256.Signing.PrivateKey().publicKey.x963Representation
        let payload = LicensePayload(
            product: LicenseTokenCodec.productIdentifier,
            kind: .standard,
            customerReference: "ORDER-100",
            deviceKeyHash: LicenseTokenCodec.deviceKeyHash(firstMac),
            issuedAt: Int64(now.timeIntervalSince1970),
            expiresAt: nil
        )
        let token = try LicenseTokenCodec.issueLicense(payload: payload, issuerPrivateKey: issuer)

        XCTAssertEqual(
            try LicenseTokenCodec.verifyLicense(token, issuerPublicKey: issuer.publicKey, currentDevicePublicKey: firstMac, now: now),
            payload
        )
        XCTAssertThrowsError(
            try LicenseTokenCodec.verifyLicense(token, issuerPublicKey: issuer.publicKey, currentDevicePublicKey: secondMac, now: now)
        ) { error in
            XCTAssertEqual(error as? LicenseValidationError, .wrongDevice)
        }
    }

    func testMasterLicenseWorksOnAnyMac() throws {
        let issuer = Curve25519.Signing.PrivateKey()
        let payload = LicensePayload(
            product: LicenseTokenCodec.productIdentifier,
            kind: .master,
            customerReference: "OWNER",
            deviceKeyHash: nil,
            issuedAt: Int64(now.timeIntervalSince1970),
            expiresAt: nil
        )
        let token = try LicenseTokenCodec.issueLicense(payload: payload, issuerPrivateKey: issuer)

        _ = try LicenseTokenCodec.verifyLicense(
            token,
            issuerPublicKey: issuer.publicKey,
            currentDevicePublicKey: P256.Signing.PrivateKey().publicKey.x963Representation,
            now: now
        )
    }

    func testServerActivationTokenUsesValidationWindow() throws {
        let issuer = Curve25519.Signing.PrivateKey()
        let mac = P256.Signing.PrivateKey().publicKey.x963Representation
        let payload = LicensePayload(
            version: 2,
            product: LicenseTokenCodec.productIdentifier,
            kind: .standard,
            customerReference: "SERVER-ORDER",
            deviceKeyHash: LicenseTokenCodec.deviceKeyHash(mac),
            issuedAt: Int64(now.timeIntervalSince1970),
            expiresAt: nil,
            validatedUntil: Int64(now.timeIntervalSince1970) + 3_600
        )
        let token = try LicenseTokenCodec.issueLicense(payload: payload, issuerPrivateKey: issuer)

        XCTAssertNoThrow(
            try LicenseTokenCodec.verifyLicense(
                token,
                issuerPublicKey: issuer.publicKey,
                currentDevicePublicKey: mac,
                now: now.addingTimeInterval(3_599)
            )
        )
        XCTAssertThrowsError(
            try LicenseTokenCodec.verifyLicense(
                token,
                issuerPublicKey: issuer.publicKey,
                currentDevicePublicKey: mac,
                now: now.addingTimeInterval(3_601)
            )
        ) { error in
            XCTAssertEqual(error as? LicenseValidationError, .serverValidationRequired)
        }
    }

    func testServerStandardTokenRequiresDeviceBinding() throws {
        let issuer = Curve25519.Signing.PrivateKey()
        let payload = LicensePayload(
            version: 2,
            product: LicenseTokenCodec.productIdentifier,
            kind: .standard,
            customerReference: "SERVER-ORDER",
            deviceKeyHash: nil,
            issuedAt: Int64(now.timeIntervalSince1970),
            expiresAt: nil,
            validatedUntil: Int64(now.timeIntervalSince1970) + 3_600
        )
        let token = try manuallySignedToken(payload, issuer: issuer)

        XCTAssertThrowsError(
            try LicenseTokenCodec.verifyLicense(
                token,
                issuerPublicKey: issuer.publicKey,
                currentDevicePublicKey: P256.Signing.PrivateKey().publicKey.x963Representation,
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? LicenseValidationError, .missingDeviceBinding)
        }
    }

    func testStandardLicenseCannotBeIssuedWithoutDeviceBinding() throws {
        let issuer = Curve25519.Signing.PrivateKey()
        let payload = LicensePayload(
            product: LicenseTokenCodec.productIdentifier,
            kind: .standard,
            customerReference: "STANDARD",
            deviceKeyHash: nil,
            issuedAt: Int64(now.timeIntervalSince1970),
            expiresAt: nil
        )
        XCTAssertThrowsError(
            try LicenseTokenCodec.issueLicense(payload: payload, issuerPrivateKey: issuer)
        ) { error in
            XCTAssertEqual(error as? LicenseValidationError, .missingDeviceBinding)
        }
        XCTAssertThrowsError(
            try LicenseTokenCodec.verifyLicense(
                manuallySignedToken(payload, issuer: issuer),
                issuerPublicKey: issuer.publicKey,
                currentDevicePublicKey: P256.Signing.PrivateKey().publicKey.x963Representation,
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? LicenseValidationError, .missingDeviceBinding)
        }
    }

    func testNonProLicenseCannotBeIssuedOrActivated() throws {
        let issuer = Curve25519.Signing.PrivateKey()
        let payload = LicensePayload(
            product: LicenseTokenCodec.productIdentifier,
            kind: .master,
            tier: "free",
            customerReference: "FREE",
            deviceKeyHash: nil,
            issuedAt: Int64(now.timeIntervalSince1970),
            expiresAt: nil
        )

        XCTAssertThrowsError(
            try LicenseTokenCodec.issueLicense(payload: payload, issuerPrivateKey: issuer)
        ) { error in
            XCTAssertEqual(error as? LicenseValidationError, .unsupportedTier)
        }

        let payloadData = try JSONEncoder.sortedLicenseEncoder.encode(payload)
        let signature = try issuer.signature(for: payloadData)
        let token = ["DNL1", payloadData.base64URLString, signature.base64URLString].joined(separator: ".")
        XCTAssertThrowsError(
            try LicenseTokenCodec.verifyLicense(
                token,
                issuerPublicKey: issuer.publicKey,
                currentDevicePublicKey: Data([1]),
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? LicenseValidationError, .unsupportedTier)
        }
    }

    func testExpiredLicenseIsRejectedAndPermanentLicenseRemainsValid() throws {
        let issuer = Curve25519.Signing.PrivateKey()
        let mac = P256.Signing.PrivateKey().publicKey.x963Representation
        let expired = LicensePayload(
            product: LicenseTokenCodec.productIdentifier,
            kind: .master,
            customerReference: "EXPIRED",
            deviceKeyHash: nil,
            issuedAt: Int64(now.timeIntervalSince1970) - 100,
            expiresAt: Int64(now.timeIntervalSince1970) - 1
        )
        let expiredToken = try LicenseTokenCodec.issueLicense(payload: expired, issuerPrivateKey: issuer)
        XCTAssertThrowsError(
            try LicenseTokenCodec.verifyLicense(expiredToken, issuerPublicKey: issuer.publicKey, currentDevicePublicKey: mac, now: now)
        ) { error in
            XCTAssertEqual(error as? LicenseValidationError, .expired)
        }

        let permanent = LicensePayload(
            product: LicenseTokenCodec.productIdentifier,
            kind: .master,
            customerReference: "PERMANENT",
            deviceKeyHash: nil,
            issuedAt: Int64(now.timeIntervalSince1970),
            expiresAt: nil
        )
        let permanentToken = try LicenseTokenCodec.issueLicense(payload: permanent, issuerPrivateKey: issuer)
        XCTAssertNoThrow(
            try LicenseTokenCodec.verifyLicense(
                permanentToken,
                issuerPublicKey: issuer.publicKey,
                currentDevicePublicKey: mac,
                now: now.addingTimeInterval(60 * 60 * 24 * 365 * 20)
            )
        )
    }

    func testExpirationUsesEndOfSelectedLocalDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 9)))
        let selected = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12)))
        let expected = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 23, minute: 59, second: 59)))

        let timestamp = try LicenseExpiration.endOfDayTimestamp(for: selected, now: now, calendar: calendar)
        XCTAssertEqual(timestamp, Int64(expected.timeIntervalSince1970))
    }

    func testTamperedLicenseIsRejected() throws {
        let issuer = Curve25519.Signing.PrivateKey()
        let payload = LicensePayload(
            product: LicenseTokenCodec.productIdentifier,
            kind: .master,
            customerReference: "ORDER",
            deviceKeyHash: nil,
            issuedAt: Int64(now.timeIntervalSince1970),
            expiresAt: nil
        )
        let token = try manuallySignedToken(payload, issuer: issuer)
        let tampered = token + "x"
        XCTAssertThrowsError(
            try LicenseTokenCodec.verifyLicense(
                tampered,
                issuerPublicKey: issuer.publicKey,
                currentDevicePublicKey: Data([1]),
                now: now
            )
        )
    }

    private func manuallySignedToken(
        _ payload: LicensePayload,
        issuer: Curve25519.Signing.PrivateKey
    ) throws -> String {
        let payloadData = try JSONEncoder.sortedLicenseEncoder.encode(payload)
        let signature = try issuer.signature(for: payloadData)
        return ["DNL1", payloadData.base64URLString, signature.base64URLString].joined(separator: ".")
    }
}

final class LicenseServerClientTests: XCTestCase {
    func testMissingServerConfigurationFailsWithoutNetworkRequest() async {
        let client = LicenseServerClient(baseURL: nil)
        do {
            _ = try await client.activate(licenseKey: "DN-PRO-TEST", deviceHash: "device")
            XCTFail("Expected missing server configuration to fail")
        } catch {
            XCTAssertEqual(error as? LicenseServerError, .notConfigured)
        }
    }

    func testOnlyPermanentServerRejectionsClearCachedActivation() {
        XCTAssertTrue(LicenseServerError.rejected(code: "revoked", message: "revoked").isDefinitiveRejection)
        XCTAssertTrue(LicenseServerError.rejected(code: "device_limit", message: "used").isDefinitiveRejection)
        XCTAssertFalse(LicenseServerError.rejected(code: "rate_limited", message: "retry").isDefinitiveRejection)
        XCTAssertFalse(LicenseServerError.transport("offline").isDefinitiveRejection)
    }
}

private extension JSONEncoder {
    static var sortedLicenseEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
