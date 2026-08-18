import SwiftUI

struct AppearanceSettingsView: View {
    let environment: AppEnvironment

    private var settings: SettingsStore { environment.settings }

    var body: some View {
        @Bindable var settings = settings

        SettingsDetailContainer(title: "Appearance", subtitle: "Wide Nook proportions and motion") {
            SettingsCard {
                NookSizePreview(
                    virtualWidth: settings.virtualNotchWidth,
                    minimumWidth: settings.minimumNotchWidth,
                    maximumWidth: settings.maximumNotchWidth,
                    expandedWidth: settings.expandedWidth,
                    expandedHeight: settings.expandedHeight,
                    cornerRadius: settings.cornerRadius,
                    opacity: settings.opacity
                )
            }

            SettingsCard {
                slider("Virtual notch width", value: $settings.virtualNotchWidth, range: 150...260, suffix: "pt", highlight: .virtual)
                slider("Minimum notch width", value: $settings.minimumNotchWidth, range: 180...360, suffix: "pt", highlight: .mediaMinimum)
                slider("Maximum notch width", value: $settings.maximumNotchWidth, range: 360...720, suffix: "pt", highlight: .mediaMaximum)
                Text("The Media Island grows within this range based on playback state and title length.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("The highlighted overlay on your display shows the actual size while you drag.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                slider("Expanded width", value: $settings.expandedWidth, range: 760...1400, suffix: "pt", highlight: .expandedWidth)
                slider("Expanded height", value: $settings.expandedHeight, range: 180...300, suffix: "pt", highlight: .expandedHeight)
                slider("Corner radius", value: $settings.cornerRadius, range: 18...42, suffix: "pt", highlight: .cornerRadius)
            }

            SettingsCard {
                slider("Opacity", value: $settings.opacity, range: 0.75...1, step: 0.01, suffix: "")
                slider("Animation speed", value: $settings.animationSpeed, range: 0.65...1.5, step: 0.05, suffix: "×")
                Toggle("Shadow", isOn: $settings.shadowEnabled)
                Toggle("Compact spacing", isOn: $settings.compactMode)
            }
        }
        .onDisappear {
            environment.notchSizeHighlight.hide(after: .zero)
        }
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        suffix: String,
        highlight: NotchSizeHighlightKind? = nil
    ) -> some View {
        LabeledContent {
            Slider(
                value: Binding(
                    get: { value.wrappedValue },
                    set: { newValue in
                        value.wrappedValue = newValue
                        if let highlight {
                            showHighlight(highlight, title: title)
                        }
                    }
                ),
                in: range,
                step: step,
                onEditingChanged: { editing in
                    guard let highlight else { return }
                    if editing {
                        showHighlight(highlight, title: title)
                    } else {
                        environment.notchSizeHighlight.hide()
                    }
                }
            )
            .frame(width: 250)
            Text("\(value.wrappedValue, specifier: step < 1 ? "%.2f" : "%.0f")\(suffix)")
                .frame(width: 65, alignment: .trailing)
                .monospacedDigit()
        } label: {
            Text(LocalizedStringKey(title))
        }
    }

    private func showHighlight(_ kind: NotchSizeHighlightKind, title: String) {
        environment.notchSizeHighlight.show(
            kind: kind,
            title: settings.localized(title),
            settings: settings,
            displayService: environment.displayService
        )
    }
}
