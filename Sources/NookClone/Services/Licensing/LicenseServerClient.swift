import Foundation

enum LicenseServerError: Error, LocalizedError, Equatable {
    case notConfigured
    case invalidResponse
    case rejected(code: String, message: String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "License server is not configured."
        case .invalidResponse: "The license server returned an invalid response."
        case .rejected(_, let message): message
        case .transport: "Could not connect to the license server."
        }
    }

    var isDefinitiveRejection: Bool {
        guard case .rejected(let code, _) = self else { return false }
        return ["invalid_key", "expired", "revoked", "device_limit", "wrong_product"].contains(code)
    }
}

struct LicenseServerConfiguration {
    private static let productionURL = URL(
        string: "https://dynamic-nook-license.2010haheon.workers.dev"
    )

    static var baseURL: URL? {
        if let override = ProcessInfo.processInfo.environment["DYNAMIC_NOOK_LICENSE_SERVER_URL"],
           let url = validatedURL(override) {
            return url
        }
        guard let value = Bundle.main.object(forInfoDictionaryKey: "DynamicNookLicenseServerURL") as? String else {
            return productionURL
        }
        return validatedURL(value) ?? productionURL
    }

    private static func validatedURL(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https",
              url.host != nil else { return nil }
        return url
    }
}

struct LicenseServerClient: Sendable {
    private struct ActivationRequest: Encodable {
        let licenseKey: String
        let deviceHash: String
    }

    private struct ActivationResponse: Decodable {
        let activationToken: String
    }

    private struct ErrorEnvelope: Decodable {
        struct Details: Decodable {
            let code: String
            let message: String
        }
        let error: Details
    }

    let baseURL: URL?
    let session: URLSession

    init(baseURL: URL? = LicenseServerConfiguration.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func activate(licenseKey: String, deviceHash: String) async throws -> String {
        guard let baseURL else { throw LicenseServerError.notConfigured }
        let endpoint = baseURL.appending(path: "v1/activate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ActivationRequest(licenseKey: licenseKey, deviceHash: deviceHash)
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LicenseServerError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw LicenseServerError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
                throw LicenseServerError.rejected(
                    code: envelope.error.code,
                    message: envelope.error.message
                )
            }
            throw LicenseServerError.invalidResponse
        }
        guard let result = try? JSONDecoder().decode(ActivationResponse.self, from: data),
              !result.activationToken.isEmpty else {
            throw LicenseServerError.invalidResponse
        }
        return result.activationToken
    }
}
