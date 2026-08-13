import SwiftUI

struct DisplayDashboardView: View {
    let service: DisplayService
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Display Control")
                    .font(.headline)
                Text("DDC/CI")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.blue)
                Spacer()
                Button {
                    service.refreshManagedDisplays()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(NookIconButtonStyle())
            }

            if service.managedDisplays.isEmpty {
                ContentUnavailableView("No Displays", systemImage: "display.trianglebadge.exclamationmark")
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 9) {
                        ForEach(service.managedDisplays) { display in
                            displayCard(display)
                                .frame(width: 300)
                        }
                    }
                }
                .scrollIndicators(settings.showWidgetScrollIndicator ? .visible : .hidden)
            }

            if let error = service.lastControlError {
                Text(LocalizedStringKey(error))
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func displayCard(_ display: ManagedDisplay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 0) {
                    Text(display.name).font(.caption.weight(.bold)).lineLimit(1)
                    Text(display.supportsDDC ? "DDC/CI connected" : (display.isBuiltIn ? "Built-in display" : "DDC/CI unavailable"))
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.42))
                }
                Spacer()
                Picker("", selection: Binding(
                    get: { display.currentModeID },
                    set: { service.setMode($0, for: display.id) }
                )) {
                    ForEach(display.modes.prefix(20)) { mode in
                        Text(mode.title).tag(mode.id)
                    }
                }
                .labelsHidden()
                .frame(width: 125)
            }

            controlRow(
                icon: "sun.max.fill",
                value: Binding(
                    get: { service.managedDisplays.first(where: { $0.id == display.id })?.brightness ?? display.brightness },
                    set: { service.setBrightness($0, for: display.id) }
                ),
                enabled: display.supportsBrightness
            )
            controlRow(
                icon: "circle.lefthalf.filled",
                value: Binding(
                    get: { service.managedDisplays.first(where: { $0.id == display.id })?.contrast ?? display.contrast },
                    set: { service.setContrast($0, for: display.id) }
                ),
                enabled: display.supportsDDC
            )
        }
        .padding(10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func controlRow(icon: String, value: Binding<Double>, enabled: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).frame(width: 14).foregroundStyle(.white.opacity(enabled ? 0.75 : 0.24))
            Slider(value: value, in: 0...1)
                .disabled(!enabled)
            Text("\(Int(value.wrappedValue * 100))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 24, alignment: .trailing)
        }
    }
}
