import SwiftUI

struct ShortcutsWidgetView: View {
    let service: ShortcutService
    let liveActions: LiveActionManager
    let haptics: HapticService
    let hapticsEnabled: Bool
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shortcuts")
                .font(.headline)
            if service.shortcuts.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title2)
                    if let error = service.errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.56))
                    } else {
                        Text("No shortcuts found")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.56))
                    }
                    Button("Reload") { Task { await service.loadShortcuts() } }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 8)], spacing: 8) {
                        ForEach(service.shortcuts) { shortcut in
                            Button {
                                run(shortcut)
                            } label: {
                                HStack {
                                    Image(systemName: service.runningShortcutID == shortcut.id ? "progress.indicator" : "bolt.fill")
                                    Text(shortcut.name).lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 38)
                                .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .disabled(service.runningShortcutID != nil)
                        }
                    }
                }
            }
        }
        .task { await service.loadShortcuts() }
    }

    private func run(_ shortcut: ShortcutItem) {
        Task {
            liveActions.enqueue(
                LiveAction(
                    icon: "bolt.fill",
                    title: "\(settings.localized("Running")) \(shortcut.name)…",
                    duration: 1.4
                )
            )
            do {
                try await service.run(shortcut)
                liveActions.enqueue(
                    LiveAction(
                        icon: "checkmark.circle.fill",
                        title: "\(shortcut.name) \(settings.localized("completed"))"
                    )
                )
                haptics.perform(enabled: hapticsEnabled, pattern: .levelChange)
            } catch {
                liveActions.enqueue(
                    LiveAction(
                        icon: "xmark.circle.fill",
                        title: settings.localized("Shortcut failed"),
                        message: error.localizedDescription,
                        priority: .important
                    )
                )
            }
        }
    }
}
