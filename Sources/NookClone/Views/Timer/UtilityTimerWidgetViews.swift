import SwiftUI

struct CountdownTimerWidgetView: View {
    let store: UtilityTimerStore

    var body: some View {
        VStack(spacing: 10) {
            Label("Timer", systemImage: "hourglass").font(.caption.weight(.bold))
            Text(store.clockText).font(.system(size: 27, weight: .bold, design: .rounded)).monospacedDigit()
            HStack(spacing: 5) {
                ForEach([1, 5, 10], id: \.self) { minutes in
                    Button("\(minutes)m") { store.setMinutes(minutes) }
                        .buttonStyle(TimerPresetButtonStyle())
                }
            }
            controls
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button(store.isRunning ? "Pause" : "Start") { store.startPause() }
                .buttonStyle(TimerPrimaryButtonStyle())
            Button { store.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                .buttonStyle(TimerIconButtonStyle())
        }
    }
}

struct StopwatchWidgetView: View {
    let store: UtilityTimerStore

    var body: some View {
        VStack(spacing: 12) {
            Label("Stopwatch", systemImage: "stopwatch").font(.caption.weight(.bold))
            Text(store.clockText).font(.system(size: 27, weight: .bold, design: .rounded)).monospacedDigit()
            HStack(spacing: 8) {
                Button(store.isRunning ? "Pause" : "Start") { store.startPause() }
                    .buttonStyle(TimerPrimaryButtonStyle())
                Button { store.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(TimerIconButtonStyle())
            }
        }
    }
}

struct TimerPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 30)
            .contentShape(Capsule())
            .background(configuration.isPressed ? Color.blue.opacity(0.65) : Color.blue, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct TimerIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 30)
            .contentShape(Circle())
            .background(.white.opacity(configuration.isPressed ? 0.16 : 0.08), in: Circle())
    }
}

struct TimerPresetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .frame(minHeight: 25)
            .contentShape(Capsule())
            .background(.white.opacity(configuration.isPressed ? 0.16 : 0.08), in: Capsule())
    }
}
