import AppKit
import Observation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()
    private(set) var panelController: NookPanelController?
    private var licenseValidationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateActivationPolicy()
        if !environment.licenseStore.isLicensed {
            environment.appStore.nookState = .expanded
        }
        let controller = NookPanelController(environment: environment)
        panelController = controller
        environment.panelController = controller
        observeDockPreference()
        licenseValidationTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await environment.licenseStore.revalidateStoredLicense()
                try? await Task.sleep(for: .seconds(21_600))
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.mediaStore.shutdown()
        environment.cameraService.stop()
        environment.displayService.shutdown()
        environment.keepAwakeService.shutdown()
        licenseValidationTask?.cancel()
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
