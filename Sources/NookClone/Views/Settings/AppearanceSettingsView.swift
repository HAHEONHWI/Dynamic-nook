import SwiftUI

struct AppearanceSettingsView: View {
    let settings: SettingsStore

    var body: some View {
        @Bindable var settings = settings

        SettingsDetailContainer(title: "Appearance", subtitle: "Wide Nook proportions and motion") {
            SettingsCard {
                slider("Virtual notch width", value: $settings.virtualNotchWidth, range: 150...260, suffix: "pt")
                slider("Minimum notch width", value: $settings.minimumNotchWidth, range: 180...360, suffix: "pt")
                slider("Maximum notch width", value: $settings.maximumNotchWidth, range: 360...720, suffix: "pt")
                Text("The Media Island grows within this range based on playback state and title length.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                slider("Expanded width", value: $settings.expandedWidth, range: 760...1400, suffix: "pt")
                slider("Expanded height", value: $settings.expandedHeight, range: 180...300, suffix: "pt")
                slider("Corner radius", value: $settings.cornerRadius, range: 18...42, suffix: "pt")
            }

            SettingsCard {
                slider("Opacity", value: $settings.opacity, range: 0.75...1, step: 0.01, suffix: "")
                slider("Animation speed", value: $settings.animationSpeed, range: 0.65...1.5, step: 0.05, suffix: "×")
                Toggle("Shadow", isOn: $settings.shadowEnabled)
                Toggle("Compact spacing", isOn: $settings.compactMode)
            }
        }
    }

    private func slider(
        _ title: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        suffix: String
    ) -> some View {
        LabeledContent {
            Slider(value: value, in: range, step: step).frame(width: 250)
            Text("\(value.wrappedValue, specifier: step < 1 ? "%.2f" : "%.0f")\(suffix)")
                .frame(width: 65, alignment: .trailing)
                .monospacedDigit()
        } label: {
            Text(title)
        }
    }
}
