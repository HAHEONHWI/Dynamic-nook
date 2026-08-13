import AppKit
import Observation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()
    private(set) var panelController: NookPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateActivationPolicy()
        let controller = NookPanelController(environment: environment)
        panelController = controller
        environment.panelController = controller
        observeDockPreference()
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.mediaStore.shutdown()
        environment.cameraService.stop()
        environment.displayService.shutdown()
        environment.keepAwakeService.shutdown()
        if environment.settings.clearTrayOnQuit {
            environment.trayStore.clear()
        }
        panelController?.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func observeDockPreference() {
        withObservationTracking {
            _ = environment.settings.showDockIcon
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateActivationPolicy()
                self?.observeDockPreference()
            }
        }
    }

    private func updateActivationPolicy() {
        NSApp.setActivationPolicy(environment.settings.showDockIcon ? .regular : .accessory)
    }
}
