import SwiftUI

struct KeepAwakeWidgetView: View {
    let service: KeepAwakeService
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Keep Awake", systemImage: "cup.and.saucer.fill")
                .font(.caption.weight(.bold))
            Spacer(minLength: 0)
            if service.isActive {
                HStack {
                    Image(systemName: "bolt.fill").foregroundStyle(.yellow)
                    Text(service.remainingText).font(.title3.monospacedDigit().weight(.bold)).lineLimit(1)
                }
                Button("Allow Sleep") { service.stop() }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            } else {
                Text("Prevent this Mac and display from sleeping.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.48)).lineLimit(2)
                HStack(spacing: 5) {
                    durationButton("30m", minutes: 30)
                    durationButton("1h", minutes: 60)
                    durationButton("2h", minutes: 120)
                    durationButton("∞", minutes: nil)
                }
            }
            if let errorMessage = service.errorMessage {
                Text(LocalizedStringKey(errorMessage)).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(1)
            }
        }
    }

    private func durationButton(_ title: String, minutes: Int?) -> some View {
        Button(title) {
            service.start(
                minutes: minutes,
                allowDisplaySleep: settings.keepAwakeAllowDisplaySleep,
                allowClosedDisplaySleep: settings.keepAwakeAllowClosedDisplaySleep,
                screenSaverMinutes: settings.keepAwakeScreenSaverMinutes
            )
        }
            .buttonStyle(.bordered).controlSize(.mini)
    }
}
