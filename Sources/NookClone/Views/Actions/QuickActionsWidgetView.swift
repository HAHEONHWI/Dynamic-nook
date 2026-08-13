import SwiftUI

struct QuickActionsWidgetView: View {
    let service: QuickActionService
    let settings: SettingsStore
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Quick Actions", systemImage: "bolt.circle.fill").font(.caption.weight(.bold))
            if settings.quickActions.isEmpty { Spacer(); Text("Add apps, URLs, files, or shell commands in Settings.").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity); Spacer() }
            else {
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 6) {
                    ForEach(settings.quickActions.prefix(6)) { action in
                        Button { Task { await service.run(action) } } label: { Label(action.title, systemImage: service.runningID == action.id ? "hourglass" : "bolt.fill").font(.caption2).lineLimit(1).frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    }
                }
            }
            if let error = service.errorMessage { Text(error).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(1) }
        }
    }
}
