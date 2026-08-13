import SwiftUI

struct NetworkWidgetView: View {
    let service: NetworkService
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Network", systemImage: "wifi").font(.caption.weight(.bold))
                Spacer()
                if service.isLoading { ProgressView().controlSize(.mini) }
                Button { Task { await service.refresh(force: true) } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain)
            }
            if !settings.allowNetworkDetails {
                Spacer()
                Label("Network data is off", systemImage: "lock.shield").font(.caption).foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity)
                Button("Allow Network Details") { settings.allowNetworkDetails = true }.buttonStyle(.plain).font(.caption2).frame(maxWidth: .infinity)
                Spacer()
            } else if let snapshot = service.snapshot {
                networkDetails(snapshot)
            } else {
                Spacer(); Label("Network unavailable", systemImage: "wifi.exclamationmark").font(.caption).foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity); Spacer()
            }
            if let error = service.errorMessage { Text(LocalizedStringKey(error)).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(1) }
        }
        .task(id: settings.allowNetworkDetails) {
            if settings.allowNetworkDetails { await service.refresh() }
        }
    }

    private func networkDetails(_ snapshot: NetworkSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(snapshot.ssid ?? "Wi-Fi name unavailable", systemImage: "wifi").font(.caption.weight(.semibold)).lineLimit(1)
            HStack {
                Label(snapshot.publicIP ?? "Public IP unavailable", systemImage: "globe").lineLimit(1)
                Spacer()
                Label(snapshot.isVPNConnected ? "VPN connected" : "VPN off", systemImage: snapshot.isVPNConnected ? "lock.fill" : "lock.open")
            }.font(.system(size: 9)).foregroundStyle(.white.opacity(0.52))
            HStack(spacing: 7) {
                metric("arrow.down", snapshot.downloadMbps)
                metric("arrow.up", snapshot.uploadMbps)
            }
        }
    }

    private func metric(_ icon: String, _ value: Double?) -> some View {
        Label(value.map { String(format: "%.1f Mbps", $0) } ?? "Speed unavailable", systemImage: icon)
            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
    }
}
