import SwiftUI

struct SystemMonitorWidgetView: View {
    let service: SystemMonitorService

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("System Monitor", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.caption.weight(.bold))
                Spacer()
                Button { service.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain)
            }
            usageRow("CPU", value: service.snapshot.cpu, detail: percent(service.snapshot.cpu), color: .blue)
            usageRow("RAM", value: service.snapshot.memory, detail: bytes(service.snapshot.memoryUsed), color: .purple)
            usageRow("Disk", value: service.snapshot.disk, detail: bytes(service.snapshot.diskUsed), color: .orange)
            if let errorMessage = service.errorMessage {
                Text(LocalizedStringKey(errorMessage)).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(1)
            }
        }
    }

    private func usageRow(_ title: String, value: Double, detail: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.caption2.weight(.semibold)).frame(width: 28, alignment: .leading)
                Spacer()
                Text(detail).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
            }
            ProgressView(value: value).tint(color).scaleEffect(y: 0.75)
        }
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
    private func bytes(_ value: UInt64) -> String { ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory) }
}
