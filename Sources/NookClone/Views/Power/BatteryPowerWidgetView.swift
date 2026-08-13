import SwiftUI

struct BatteryPowerWidgetView: View {
    let service: BatteryPowerService
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Battery & Power", systemImage: "battery.75percent").font(.caption.weight(.bold))
            if let item = service.snapshot {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(item.percent)%").font(.title2.bold().monospacedDigit())
                    Image(systemName: item.isCharging ? "bolt.fill" : item.isOnAC ? "powerplug.fill" : "battery.50percent").foregroundStyle(item.isCharging ? .green : .secondary)
                }
                ProgressView(value: Double(item.percent), total: 100).tint(item.percent < 20 ? .red : .green)
                Text(detail(item)).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            } else {
                Spacer(); Text("Battery information unavailable").font(.caption).foregroundStyle(.secondary); Spacer()
            }
        }
    }
    private func detail(_ item: BatteryPowerSnapshot) -> String {
        var parts = [item.isOnAC ? String(localized: "Power Adapter") : String(localized: "Battery Power")]
        if let minutes = item.timeRemainingMinutes { parts.append("\(minutes / 60)h \(minutes % 60)m") }
        if let cycles = item.cycleCount { parts.append("\(cycles) \(String(localized: "cycles"))") }
        return parts.joined(separator: " · ")
    }
}
