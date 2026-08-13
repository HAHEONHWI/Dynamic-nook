import AppKit
import SwiftUI

@main
struct NookCloneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(
            "Dynamic Nook",
            systemImage: "rectangle.topthird.inset.filled",
            isInserted: Binding(
                get: { appDelegate.environment.settings.showMenuBarIcon },
                set: { appDelegate.environment.settings.showMenuBarIcon = $0 }
            )
        ) {
            MenuBarContentView(environment: appDelegate.environment)
                .environment(\.locale, appDelegate.environment.settings.appLanguage.locale)
        }

        Settings {
            SettingsRootView(environment: appDelegate.environment)
                .environment(\.locale, appDelegate.environment.settings.appLanguage.locale)
        }
        .commands {
            CommandMenu("Nook") {
                Button {
                    appDelegate.panelController?.open()
                } label: {
                    Text(appDelegate.environment.settings.localized("Open Nook"))
                }
                    .keyboardShortcut("n", modifiers: [.command, .option])
                Button {
                    appDelegate.panelController?.openTray()
                } label: {
                    Text(appDelegate.environment.settings.localized("Open Tray"))
                }
                    .keyboardShortcut("t", modifiers: [.command, .option])
                Button {
                    appDelegate.panelController?.collapse()
                } label: {
                    Text(appDelegate.environment.settings.localized("Close Nook"))
                }
                    .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}

private struct MenuBarContentView: View {
    let environment: AppEnvironment

    var body: some View {
        Button(environment.settings.localized("Open Nook")) { environment.panelController?.open() }
        Button(environment.settings.localized("Open Tray")) { environment.panelController?.openTray() }
        Toggle(
            environment.settings.localized("Show Media Island"),
            isOn: Bindable(environment.settings).showMediaIsland
        )
        SettingsLink { Text(environment.settings.localized("Settings…")) }
        Divider()
        Button(environment.settings.localized("Clear Tray")) { environment.trayStore.clear() }
            .disabled(environment.trayStore.items.isEmpty)
        Divider()
        Button(environment.settings.localized("Quit nook3h")) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
