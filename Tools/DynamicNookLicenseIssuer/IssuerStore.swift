import AppKit
import CryptoKit
import Foundation
import LicenseCore
import Observation
import Security

@MainActor
@Observable
final class IssuerStore {
    var kind: LicenseKind = .standard
    var customerReference = ""
    var serverURL = IssuerConfigurationStore.serverURL {
        didSet { IssuerConfigurationStore.serverURL = serverURL }
    }
    var adminToken = IssuerConfigurationStore.adminToken {
        didSet { IssuerConfigurationStore.adminToken = adminToken }
    }
    var hasExpiration = false
    var expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var generatedLicense = ""
    var errorMessage: String?
    private(set) var isGenerating = false
    private(set) var generatedLicenseID = ""
    private(set) var issuerPublicKey = ""
    private let privateKey: Curve25519.Signing.PrivateKey?

    init() {
        do {
            let key = try IssuerKeyStore.loadOrCreate()
            let publicKey = key.publicKey.rawRepresentation.base64URLString
            guard publicKey == LicenseAuthority.issuerPublicKeyBase64URL else {
                throw IssuerError.wrongIssuerKey
            }
            privateKey = key
            issuerPublicKey = publicKey
        } catch {
            privateKey = nil
            errorMessage = error.localizedDescription
        }
    }

    var expirationSummary: String {
        guard hasExpiration else { return String(localized: "Permanent") }
        return expirationDate.formatted(date: .long, time: .omitted)
    }

    func generate() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        do {
            guard privateKey != nil else { throw IssuerError.keychain(errSecInternalError) }
            let reference = customerReference.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reference.isEmpty else { throw IssuerError.missingCustomerReference }

            let expiresAt = try resolvedExpirationTimestamp()
            let licenseKey = try makeLicenseKey()
            let record = try await IssuerServerClient().createLicense(
                serverURL: serverURL,
                adminToken: adminToken,
                licenseKey: licenseKey,
                kind: kind,
                customerReference: reference,
                expiresAt: expiresAt
            )
            generatedLicense = licenseKey
            generatedLicenseID = record.id
            errorMessage = nil
        } catch {
            generatedLicense = ""
            generatedLicenseID = ""
            errorMessage = error.localizedDescription
        }
    }

    func copyLicense() {
        guard !generatedLicense.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedLicense, forType: .string)
    }

    func copyPublicKey() {
        guard !issuerPublicKey.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(issuerPublicKey, forType: .string)
    }

    private func resolvedExpirationTimestamp() throws -> Int64? {
        guard hasExpiration else { return nil }
        return try LicenseExpiration.endOfDayTimestamp(for: expirationDate)
    }

    private func makeLicenseKey() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw IssuerError.randomGenerationFailed
        }
        let hex = bytes.map { String(format: "%02X", $0) }.joined()
        let groups = stride(from: 0, to: hex.count, by: 4).map { offset -> String in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: min(4, hex.count - offset))
            return String(hex[start..<end])
        }
        return "DN-PRO-" + groups.joined(separator: "-")
    }
}
