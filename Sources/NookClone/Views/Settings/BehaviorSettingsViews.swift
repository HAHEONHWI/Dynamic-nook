import SwiftUI

struct TraySettingsView: View {
    let environment: AppEnvironment

    var body: some View {
        @Bindable var settings = environment.settings

        SettingsDetailContainer(title: "File Tray", subtitle: "Temporary file shelf and sharing") {
            SettingsCard {
                Stepper("Maximum items: \(settings.maximumTrayItems)", value: $settings.maximumTrayItems, in: 1...50)
                Toggle("Clear when app quits", isOn: $settings.clearTrayOnQuit)
                Toggle("Show file icons", isOn: $settings.showThumbnails)
                Toggle("Switch to Tray while dragging", isOn: $settings.automaticallySwitchToTray)
                Toggle("Enable AirDrop", isOn: $settings.enableAirDrop)
            }
            Button("Clear Tray", role: .destructive) { environment.trayStore.clear() }
                .disabled(environment.trayStore.items.isEmpty)
        }
    }
}

struct GestureSettingsView: View {
    let settings: SettingsStore

    var body: some View {
        @Bindable var settings = settings

        SettingsDetailContainer(title: "Gestures", subtitle: "Hover, click, and two-finger trackpad input") {
            SettingsCard {
                Toggle("Hover to peek", isOn: $settings.hoverToOpen)
                LabeledContent("Hover delay") {
                    Slider(value: $settings.hoverDelay, in: 0...0.5, step: 0.1).frame(width: 220)
                    Text("\(settings.hoverDelay, specifier: "%.1f") s").monospacedDigit()
                }
                Toggle("Click to open or close", isOn: $settings.clickToOpen)
            }
            SettingsCard {
                Toggle("Two-finger scroll down to open", isOn: $settings.swipeDownToOpen)
                Toggle("Two-finger scroll up to close", isOn: $settings.swipeUpToClose)
                Toggle("Two-finger scroll left/right between widgets", isOn: $settings.swipeBetweenWidgets)
                Toggle("Haptic feedback", isOn: $settings.enableHaptics)
            }
            Text("Hover shows a preview. Click or scroll down while previewing opens the full bar immediately.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct DisplaySettingsView: View {
    let environment: AppEnvironment

    var body: some View {
        @Bindable var settings = environment.settings

        SettingsDetailContainer(title: "Display", subtitle: "Choose where Nook appears") {
            SettingsCard {
                Picker("Display", selection: $settings.displayPreference) {
                    ForEach(DisplayPreference.allCases) { preference in
                        Text(LocalizedStringKey(preference.title)).tag(preference)
                    }
                }
                Text("Expanded width is automatically clamped to the selected display.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(environment.displayService.managedDisplays) { display in
                SettingsCard {
                    HStack {
                        Label(display.name, systemImage: display.isBuiltIn ? "laptopcomputer" : "display")
                            .font(.headline)
                        Spacer()
                        Text(display.supportsDDC ? "DDC/CI connected" : (display.isBuiltIn ? "Built-in display" : "DDC/CI unavailable"))
                            .font(.caption)
                            .foregroundStyle(display.supportsDDC ? .blue : .secondary)
                    }

                    Picker("Resolution and refresh rate", selection: Binding(
                        get: { display.currentModeID },
                        set: { environment.displayService.setMode($0, for: display.id) }
                    )) {
                        ForEach(display.modes) { mode in
                            Text(mode.title).tag(mode.id)
                        }
                    }

                    LabeledContent("Brightness") {
                        Slider(value: Binding(
                            get: {
                                environment.displayService.managedDisplays
                                    .first(where: { $0.id == display.id })?.brightness ?? display.brightness
                            },
                            set: { environment.displayService.setBrightness($0, for: display.id) }
                        ), in: 0...1)
                        .frame(width: 300)
                        .disabled(!display.supportsBrightness)
                    }

                    LabeledContent("Contrast") {
                        Slider(value: Binding(
                            get: {
                                environment.displayService.managedDisplays
                                    .first(where: { $0.id == display.id })?.contrast ?? display.contrast
                            },
                            set: { environment.displayService.setContrast($0, for: display.id) }
                        ), in: 0...1)
                        .frame(width: 300)
                        .disabled(!display.supportsDDC)
                    }
                }
            }

            if let error = environment.displayService.lastControlError {
                Text(LocalizedStringKey(error))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear { environment.displayService.refreshManagedDisplays() }
    }
}
