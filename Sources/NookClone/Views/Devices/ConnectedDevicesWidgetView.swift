import SwiftUI

struct ConnectedDevicesWidgetView: View {
    let service: DeviceStatusService
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Label("Connected Devices", systemImage: "externaldrive.connected.to.line.below").font(.caption.weight(.bold)); Spacer(); if service.isLoading { ProgressView().controlSize(.mini) }; Button { Task { await service.refresh() } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain) }
            if service.devices.isEmpty, !service.isLoading { Spacer(); Text("No connected devices").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity); Spacer() }
            else { ForEach(service.devices.prefix(4)) { item in HStack { Image(systemName: icon(for: item.kind)); Text(item.name).font(.caption2).lineLimit(1); Spacer(); Text(item.detail ?? item.kind).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1) }.frame(height: 24) } }
            if let error = service.errorMessage { Text(LocalizedStringKey(error)).font(.system(size: 9)).foregroundStyle(.orange) }
        }.task { await service.refresh() }
    }

    private func icon(for kind: String) -> String {
        switch kind { case "Bluetooth": "wave.3.right"; case "External Disk": "externaldrive.fill"; default: "cable.connector" }
    }
}
