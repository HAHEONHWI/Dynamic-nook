import CryptoKit
import Foundation
import LicenseCore
import Observation

enum LicenseStatus: Equatable {
    case unlicensed
    case active(LicensePayload)
    case invalid(String)
}

@MainActor
@Observable
final class LicenseStore {
    private(set) var status: LicenseStatus = .unlicensed
    private(set) var errorMessage: String?
    private(set) var isActivating = false
    private(set) var showsActivationSuccess = false

    private let deviceIdentity: DeviceIdentityService
    private let serverClient: LicenseServerClient
    private let tokenAccount = "dynamic-nook-license-v1"
    private let licenseKeyAccount = "dynamic-nook-license-key-v1"
    private var activationSuccessTask: Task<Void, Never>?

    init(
        deviceIdentity: DeviceIdentityService = DeviceIdentityService(),
        serverClient: LicenseServerClient = LicenseServerClient()
    ) {
        self.deviceIdentity = deviceIdentity
        self.serverClient = serverClient
        refresh()
    }

    var isLicensed: Bool {
        if case .active = status { return true }
        return false
    }

    var activeLicense: LicensePayload? {
        if case .active(let payload) = status { return payload }
        return nil
    }

    func refresh(now: Date = Date()) {
        guard let token = KeychainSecretStore.read(account: tokenAccount), !token.isEmpty else {
            status = .unlicensed
            errorMessage = nil
            return
        }
        verify(token, now: now, persist: false)
    }

    func activate(_ input: String, now: Date = Date()) async {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        isActivating = true
        defer { isActivating = false }

        if value.hasPrefix("DNL1.") {
            verify(value, now: now, persist: true)
            return
        }
        await activateOnline(
            value,
            now: now,
            preserveCurrentOnTransportFailure: false,
            showSuccess: true
        )
    }

    func revalidateStoredLicense(now: Date = Date()) async {
        guard let licenseKey = KeychainSecretStore.read(account: licenseKeyAccount),
              !licenseKey.isEmpty,
              !isActivating else { return }
        isActivating = true
        defer { isActivating = false }
        await activateOnline(
            licenseKey,
            now: now,
            preserveCurrentOnTransportFailure: true,
            showSuccess: false
        )
    }

    func deactivate() {
        activationSuccessTask?.cancel()
        activationSuccessTask = nil
        showsActivationSuccess = false
        KeychainSecretStore.delete(account: tokenAccount)
        KeychainSecretStore.delete(account: licenseKeyAccount)
        status = .unlicensed
        errorMessage = nil
    }

    private func verify(_ token: String, now: Date, persist: Bool) {
        do {
            let payload = try verifiedPayload(
                token,
                currentDevicePublicKey: try? deviceIdentity.publicKeyData(),
                now: now
            )
            if persist { KeychainSecretStore.write(token, account: tokenAccount) }
            status = .active(payload)
            errorMessage = nil
            if persist { presentActivationSuccess() }
        } catch {
            let message = error.localizedDescription
            status = .invalid(message)
            errorMessage = message
        }
    }

    private func activateOnline(
        _ licenseKey: String,
        now: Date,
        preserveCurrentOnTransportFailure: Bool,
        showSuccess: Bool
    ) async {
        let previousStatus = status
        do {
            let publicKey = try deviceIdentity.publicKeyData()
            let deviceHash = LicenseTokenCodec.deviceKeyHash(publicKey)
            let token = try await serverClient.activate(
                licenseKey: licenseKey,
                deviceHash: deviceHash
            )
            let payload = try verifiedPayload(
                token,
                currentDevicePublicKey: publicKey,
                now: now
            )
            KeychainSecretStore.write(token, account: tokenAccount)
            KeychainSecretStore.write(normalizedLicenseKey(licenseKey), account: licenseKeyAccount)
            status = .active(payload)
            errorMessage = nil
            if showSuccess { presentActivationSuccess() }
        } catch let error as LicenseServerError {
            if preserveCurrentOnTransportFailure, !error.isDefinitiveRejection {
                status = previousStatus
            } else {
                status = .invalid(error.localizedDescription)
            }
            if error.isDefinitiveRejection {
                KeychainSecretStore.delete(account: tokenAccount)
            }
            errorMessage = error.localizedDescription
        } catch {
            status = .invalid(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func verifiedPayload(
        _ token: String,
        currentDevicePublicKey: Data?,
        now: Date
    ) throws -> LicensePayload {
        guard let publicKeyData = Data(base64URLString: LicenseAuthority.issuerPublicKeyBase64URL) else {
            throw LicenseValidationError.invalidSignature
        }
        let issuerPublicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        return try LicenseTokenCodec.verifyLicense(
            token,
            issuerPublicKey: issuerPublicKey,
            currentDevicePublicKey: currentDevicePublicKey,
            now: now
        )
    }

    private func normalizedLicenseKey(_ value: String) -> String {
        value.uppercased().filter { !$0.isWhitespace }
    }

    private func presentActivationSuccess() {
        activationSuccessTask?.cancel()
        showsActivationSuccess = true
        activationSuccessTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            self?.showsActivationSuccess = false
            self?.activationSuccessTask = nil
        }
    }
}
