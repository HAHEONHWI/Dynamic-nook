import AppKit
import SwiftUI

@MainActor
final class AppEnvironment {
    private var settingsWindowController: NSWindowController?
    let settingsNavigation = SettingsNavigation()
    let appStore = AppStore()
    let settings = SettingsStore()
    let licenseStore = LicenseStore()
    let trayStore = TrayStore()
    let notesStore = NotesStore()
    let liveActions = LiveActionManager()
    let displayService = DisplayService()
    let keepAwakeService = KeepAwakeService()
    let systemMonitorService = SystemMonitorService()
    let clipboardService = ClipboardHistoryService()
    let audioControlService = AudioControlService()
    let batteryPowerService = BatteryPowerService()
    let developerService = DeveloperService()
    let quickActionService = QuickActionService()
    let windowLayoutService = WindowLayoutService()
    let automationPermissionService = AutomationPermissionService()
    let deviceStatusService = DeviceStatusService()
    let schoolService = SchoolService()
    let schoolTimetableService = SchoolTimetableService()
    let calendarService = CalendarService()
    let reminderService = ReminderService()
    let shortcutService = ShortcutService()
    let mediaStore = MediaStore(provider: SystemMediaService())
    let cameraService = CameraService()
    let sharingService = SharingService()
    let haptics = HapticService()
    let timerAlert = TimerAlertService()
    let focusTimerStore = FocusTimerStore()
    let countdownTimerStore = UtilityTimerStore(mode: .countdown)
    let stopwatchStore = UtilityTimerStore(mode: .stopwatch)
    let weatherService = WeatherService()
    let networkService = NetworkService()
    let marketService = MarketService()
    let launchAtLogin = LaunchAtLoginService()
    let previewService = PreviewService()
    let notchSizeHighlight = NotchSizeHighlightController()

    init() {
        appStore.activePage = settings.resolvedOpeningPage
        focusTimerStore.onCompletion = { [weak self] in
            guard let self else { return }
            liveActions.enqueue(LiveAction(icon: "timer", title: settings.localized("Focus complete"), priority: .important))
            timerAlert.play()
            haptics.perform(enabled: settings.enableHaptics, pattern: .levelChange)
        }
        countdownTimerStore.onCompletion = { [weak self] in
            guard let self else { return }
            liveActions.enqueue(LiveAction(icon: "timer", title: settings.localized("Countdown complete"), priority: .important))
            timerAlert.play()
            haptics.perform(enabled: settings.enableHaptics, pattern: .levelChange)
        }
    }

    func openSettings(_ category: SettingsCategory? = nil) {
        if let category {
            settingsNavigation.selection = category
        }
        if settingsWindowController == nil {
            let rootView = SettingsRootView(environment: self)
                .environment(\.locale, settings.appLanguage.locale)
            let controller = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: controller)
            window.title = "Dynamic Nook Settings"
            window.setContentSize(NSSize(width: 940, height: 590))
            window.styleMask = NSWindow.StyleMask([.titled, .closable, .miniaturizable, .resizable])
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    weak var panelController: NookPanelController?

}
