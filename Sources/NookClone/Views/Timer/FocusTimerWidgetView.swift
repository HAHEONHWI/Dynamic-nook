import SwiftUI

struct FocusTimerWidgetView: View {
    let store: FocusTimerStore
    let settings: SettingsStore
    private let presets = [5, 15, 25, 45]

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Label("Focus Timer", systemImage: "timer")
                    .font(.caption.weight(.bold))
                Spacer()
                Button {
                    store.select(minutes: settings.defaultBreakMinutes, kind: .breakTime)
                } label: {
                    Image(systemName: "cup.and.saucer.fill")
                }
                .buttonStyle(.plain)
                .help("Use break timer")
                Text(stateTitle).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.45))
            }

            ZStack {
                Circle().stroke(.white.opacity(0.08), lineWidth: 6)
                Circle().trim(from: 0, to: store.progress)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(store.clockText).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.7)
            }
            .frame(width: 48, height: 48)

            HStack(spacing: 4) {
                ForEach(presets, id: \.self) { minutes in
                    Button("\(minutes)") { store.select(minutes: minutes) }
                        .buttonStyle(FocusPresetButtonStyle(isSelected: store.selectedMinutes == minutes))
                }
            }

            HStack(spacing: 6) {
                Button(actionTitle, action: primaryAction)
                    .buttonStyle(TimerPrimaryButtonStyle())
                Button { store.reset(defaultMinutes: settings.defaultFocusMinutes) } label: { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(TimerIconButtonStyle())
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            if store.state == .idle, store.selectedMinutes != settings.defaultFocusMinutes {
                store.reset(defaultMinutes: settings.defaultFocusMinutes)
            }
        }
    }

    private var actionTitle: LocalizedStringKey {
        switch store.state { case .running: "Pause"; case .paused: "Resume"; case .idle, .completed: "Start" }
    }

    private var stateTitle: LocalizedStringKey {
        if store.kind == .breakTime, store.state == .idle { return "Break ready" }
        switch store.state {
        case .idle: return "Ready"
        case .running: return store.kind == .breakTime ? "On break" : "Focusing"
        case .paused: return "Paused"
        case .completed: return "Complete"
        }
    }

    private func primaryAction() {
        switch store.state {
        case .running: store.pause()
        case .paused: store.resume()
        case .idle, .completed: store.start()
        }
    }
}

private struct FocusPresetButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 24)
            .contentShape(Capsule())
            .background(
                isSelected ? Color.blue.opacity(configuration.isPressed ? 0.68 : 1) : .white.opacity(configuration.isPressed ? 0.16 : 0.08),
                in: Capsule()
            )
    }
}
