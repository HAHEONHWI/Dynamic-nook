import AppKit
import CoreWLAN
import Foundation
import NetworkExtension
import Observation

@MainActor
@Observable
final class NetworkService {
    private(set) var snapshot: NetworkSnapshot?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func refresh(force: Bool = false) async {
        if !force, let snapshot, NetworkCachePolicy.isValid(fetchedAt: snapshot.fetchedAt) { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let publicIP = try await fetchPublicIP()
            let linkRate = CWWiFiClient.shared().interface()?.transmitRate()
            snapshot = NetworkSnapshot(
                ssid: currentSSID(),
                downloadMbps: linkRate,
                uploadMbps: nil,
                publicIP: publicIP,
                isVPNConnected: isVPNConnected(),
                fetchedAt: Date()
            )
            errorMessage = nil
        } catch {
            errorMessage = "Network details could not be refreshed."
        }
    }

    private func fetchPublicIP() async throws -> String {
        let url = URL(string: "https://api.ipify.org?format=json")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(IPResponse.self, from: data).ip
    }

    private func currentSSID() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }

    private func isVPNConnected() -> Bool {
        NEVPNManager.shared().connection.status == .connected ||
            ProcessInfo.processInfo.environment.keys.contains { $0.hasPrefix("VPN_") }
    }
}

private struct IPResponse: Decodable {
    let ip: String
}
