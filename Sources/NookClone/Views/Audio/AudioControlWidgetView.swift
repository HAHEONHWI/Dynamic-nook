import SwiftUI

struct AudioControlWidgetView: View {
    let service: AudioControlService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Audio Control", systemImage: "speaker.wave.2.fill").font(.caption.weight(.bold))
                Spacer()
                Button { service.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain)
            }
            Picker("", selection: Binding(get: { service.selectedDeviceID }, set: { service.select($0) })) {
                ForEach(service.devices) { Text($0.name).tag($0.id) }
            }.labelsHidden().controlSize(.small)
            HStack {
                Button { service.toggleMute() } label: { Image(systemName: service.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") }.buttonStyle(.plain)
                Slider(value: Binding(get: { service.volume }, set: { service.setVolume($0) }), in: 0...1)
                Text("\(Int(service.volume * 100))").font(.system(size: 9, design: .monospaced)).frame(width: 24)
            }
            if let error = service.errorMessage { Text(LocalizedStringKey(error)).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(1) }
        }
    }
}
