import Foundation
import LicenseCore

struct IssuedLicenseRecord: Decodable, Sendable {
    let id: String
}

enum IssuerServerError: Error, LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case rejected(String)
    case transport

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "Enter a valid HTTPS server URL and administrator token."
        case .invalidResponse: "The license server returned an invalid response."
        case .rejected(let message): message
        case .transport: "Could not connect to the license server."
        }
    }
}

struct IssuerServerClient: Sendable {
    private struct CreateRequest: Encodable {
        let licenseKey: String
        let kind: LicenseKind
        let customerReference: String
        let expiresAt: Int64?
    }

    private struct ErrorEnvelope: Decodable {
        struct Details: Decodable { let message: String }
        let error: Details
    }

    func createLicense(
        serverURL: String,
        adminToken: String,
        licenseKey: String,
        kind: LicenseKind,
        customerReference: String,
        expiresAt: Int64?
    ) async throws -> IssuedLicenseRecord {
        guard let baseURL = URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              baseURL.scheme == "https",
              baseURL.host != nil,
              !adminToken.isEmpty else {
            throw IssuerServerError.invalidConfiguration
        }
        var request = URLRequest(url: baseURL.appending(path: "v1/admin/licenses"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(adminToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            CreateRequest(
                licenseKey: licenseKey,
                kind: kind,
                customerReference: customerReference,
                expiresAt: expiresAt
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw IssuerServerError.transport
        }
        guard let http = response as? HTTPURLResponse else { throw IssuerServerError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
                throw IssuerServerError.rejected(envelope.error.message)
            }
            throw IssuerServerError.invalidResponse
        }
        guard let record = try? JSONDecoder().decode(IssuedLicenseRecord.self, from: data) else {
            throw IssuerServerError.invalidResponse
        }
        return record
    }
}
