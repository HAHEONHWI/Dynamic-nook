import SwiftUI

struct GeneralSettingsView: View {
    let environment: AppEnvironment

    var body: some View {
        @Bindable var settings = environment.settings

        SettingsDetailContainer(title: "General", subtitle: "Startup and window behavior") {
            SettingsCard {
                Picker("Language", selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(settings.localized(language.titleKey)).tag(language)
                    }
                }
                Text("Uses Korean when the system language is Korean. Unsupported languages use English.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingsCard {
                Picker("Nook opening page", selection: $settings.nookOpeningMode) {
                    ForEach(NookOpeningMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.title)).tag(mode)
                    }
                }
                if settings.nookOpeningMode == .fixedPage {
                    Picker("Main page", selection: $settings.defaultNookPage) {
                    ForEach(settings.nookPages) { page in
                        Label(page.title, systemImage: page.systemImage).tag(page)
                        }
                    }
                }
            }

            SettingsCard {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { enabled in
                            if environment.launchAtLogin.setEnabled(enabled) {
                                settings.launchAtLogin = enabled
                            }
                        }
                    )
                )
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                Toggle("Show Dock icon", isOn: $settings.showDockIcon)
                Toggle("Show Media Island", isOn: $settings.showMediaIsland)
                Toggle("Show controls for 3 seconds when new media starts", isOn: $settings.showMediaStartPreview)
                    .disabled(!settings.showMediaIsland)
                Toggle("Use artwork color gradient", isOn: $settings.showMediaArtworkGradient)
                    .disabled(!settings.showMediaIsland)
            }

            SettingsCard {
                Toggle("Close when clicking outside", isOn: $settings.closeOnOutsideClick)
                Toggle("Close when pointer leaves", isOn: $settings.autoClose)
                LabeledContent("Close delay") {
                    Slider(value: $settings.autoCloseDelay, in: 3...10, step: 0.5)
                        .frame(width: 220)
                    Text("\(settings.autoCloseDelay, specifier: "%.1f") s")
                        .monospacedDigit()
                }
            }

            if let error = environment.launchAtLogin.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }
}
