import Foundation
import Observation

enum DisplayPreference: String, CaseIterable, Identifiable, Sendable {
    case main
    case underPointer
    case builtIn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: "Main Display"
        case .underPointer: "Display under Pointer"
        case .builtIn: "Built-in Display"
        }
    }
}

@MainActor
@Observable
final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults

    var appLanguage: AppLanguage { didSet { save(appLanguage.rawValue, "appLanguage") } }
    var hoverToOpen: Bool { didSet { save(hoverToOpen, "hoverToOpen") } }
    var launchAtLogin: Bool { didSet { save(launchAtLogin, "launchAtLogin") } }
    var hoverDelay: Double { didSet { save(hoverDelay, "hoverDelay") } }
    var clickToOpen: Bool { didSet { save(clickToOpen, "clickToOpen") } }
    var swipeToOpen: Bool { didSet { save(swipeToOpen, "swipeToOpen") } }
    var swipeDownToOpen: Bool { didSet { save(swipeDownToOpen, "swipeDownToOpen") } }
    var swipeUpToClose: Bool { didSet { save(swipeUpToClose, "swipeUpToClose") } }
    var swipeBetweenWidgets: Bool { didSet { save(swipeBetweenWidgets, "swipeBetweenWidgets") } }
    var autoClose: Bool { didSet { save(autoClose, "autoClose") } }
    var closeOnOutsideClick: Bool { didSet { save(closeOnOutsideClick, "closeOnOutsideClick") } }
    var autoCloseDelay: Double { didSet { save(autoCloseDelay, "autoCloseDelay") } }
    var showMenuBarIcon: Bool { didSet { save(showMenuBarIcon, "showMenuBarIcon") } }
    var showDockIcon: Bool { didSet { save(showDockIcon, "showDockIcon") } }
    var enableHaptics: Bool { didSet { save(enableHaptics, "enableHaptics") } }
    var virtualNotchWidth: Double { didSet { save(virtualNotchWidth, "virtualNotchWidth") } }
    var minimumNotchWidth: Double { didSet { save(minimumNotchWidth, "minimumNotchWidth") } }
    var maximumNotchWidth: Double { didSet { save(maximumNotchWidth, "maximumNotchWidth") } }
    var expandedWidth: Double { didSet { save(expandedWidth, "expandedWidth") } }
    var expandedHeight: Double { didSet { save(expandedHeight, "expandedHeight") } }
    var cornerRadius: Double { didSet { save(cornerRadius, "cornerRadius") } }
    var opacity: Double { didSet { save(opacity, "opacity") } }
    var animationSpeed: Double { didSet { save(animationSpeed, "animationSpeed") } }
    var shadowEnabled: Bool { didSet { save(shadowEnabled, "shadowEnabled") } }
    var compactMode: Bool { didSet { save(compactMode, "compactMode") } }
    var maximumTrayItems: Int { didSet { save(maximumTrayItems, "maximumTrayItems") } }
    var clearTrayOnQuit: Bool { didSet { save(clearTrayOnQuit, "clearTrayOnQuit") } }
    var enableAirDrop: Bool { didSet { save(enableAirDrop, "enableAirDrop") } }
    var showThumbnails: Bool { didSet { save(showThumbnails, "showThumbnails") } }
    var automaticallySwitchToTray: Bool { didSet { save(automaticallySwitchToTray, "automaticallySwitchToTray") } }
    var showMediaIsland: Bool { didSet { save(showMediaIsland, "showMediaIsland") } }
    var showMediaStartPreview: Bool { didSet { save(showMediaStartPreview, "showMediaStartPreview") } }
    var showMediaArtworkGradient: Bool { didSet { save(showMediaArtworkGradient, "showMediaArtworkGradient") } }
    var enabledWidgets: [WidgetType] { didSet { saveWidgets() } }
    var nookPages: [NookPage] { didSet { saveNookPages() } }
    var widgetLayouts: [String: [String]] { didSet { save(widgetLayouts, "widgetLayouts") } }
    var widgetCellSpans: [WidgetType: Int] { didSet { saveWidgetCellSpans() } }
    var showWidgetScrollIndicator: Bool { didSet { save(showWidgetScrollIndicator, "showWidgetScrollIndicator") } }
    var calendarRange: CalendarRange { didSet { save(calendarRange.rawValue, "calendarRange") } }
    var maximumCalendarEvents: Int { didSet { save(maximumCalendarEvents, "maximumCalendarEvents") } }
    var selectedCalendarIdentifiers: [String] { didSet { save(selectedCalendarIdentifiers, "selectedCalendarIdentifiers") } }
    var displayPreference: DisplayPreference { didSet { save(displayPreference.rawValue, "displayPreference") } }
    var nookOpeningMode: NookOpeningMode { didSet { save(nookOpeningMode.rawValue, "nookOpeningMode") } }
    var defaultNookPage: NookPage { didSet { save(defaultNookPage.id, "defaultNookPage") } }
    var lastNookPage: NookPage { didSet { save(lastNookPage.id, "lastNookPage") } }
    var neisAPIKey: String { didSet { KeychainSecretStore.write(neisAPIKey, account: "neis-api-key") } }
    var neisEducationOfficeCode: String { didSet { save(neisEducationOfficeCode, "neisEducationOfficeCode") } }
    var neisSchoolCode: String { didSet { save(neisSchoolCode, "neisSchoolCode") } }
    var neisSchoolName: String { didSet { save(neisSchoolName, "neisSchoolName") } }
    var schoolGrade: Int { didSet { save(schoolGrade, "schoolGrade") } }
    var schoolClassNumber: Int { didSet { save(schoolClassNumber, "schoolClassNumber") } }
    var maximumReminders: Int { didSet { save(maximumReminders, "maximumReminders") } }
    var selectedReminderListIdentifiers: [String] { didSet { save(selectedReminderListIdentifiers, "selectedReminderListIdentifiers") } }
    var defaultFocusMinutes: Int { didSet { save(defaultFocusMinutes, "defaultFocusMinutes") } }
    var defaultBreakMinutes: Int { didSet { save(defaultBreakMinutes, "defaultBreakMinutes") } }
    var manualWeatherLocation: String { didSet { save(manualWeatherLocation, "manualWeatherLocation") } }
    var allowNetworkDetails: Bool { didSet { save(allowNetworkDetails, "allowNetworkDetails") } }
    var allowMarketData: Bool { didSet { save(allowMarketData, "allowMarketData") } }
    var marketItems: [MarketItem] { didSet { saveMarketItems() } }
    var keepAwakeAllowDisplaySleep: Bool { didSet { save(keepAwakeAllowDisplaySleep, "keepAwakeAllowDisplaySleep") } }
    var keepAwakeAllowClosedDisplaySleep: Bool { didSet { save(keepAwakeAllowClosedDisplaySleep, "keepAwakeAllowClosedDisplaySleep") } }
    var keepAwakeScreenSaverMinutes: Int { didSet { save(keepAwakeScreenSaverMinutes, "keepAwakeScreenSaverMinutes") } }
    var clipboardHistoryEnabled: Bool { didSet { save(clipboardHistoryEnabled, "clipboardHistoryEnabled") } }
    var developerRepositoryPath: String { didSet { save(developerRepositoryPath, "developerRepositoryPath") } }
    var githubUsername: String { didSet { save(githubUsername, "githubUsername") } }
    var showCodexUsage: Bool { didSet { save(showCodexUsage, "showCodexUsage") } }
    var quickActions: [QuickAction] { didSet { saveQuickActions() } }

    init(defaults: UserDefaults = .standard) {
        let isFreshWidgetConfiguration = defaults.object(forKey: "enabledWidgets") == nil
            && defaults.object(forKey: "widgetLayouts") == nil
            && defaults.object(forKey: "additionalWidgetLayouts") == nil
            && defaults.object(forKey: "layoutVersion") == nil
        self.defaults = defaults
        defaults.register(defaults: [
            "appLanguage": AppLanguage.system.rawValue,
            "hoverToOpen": true,
            "launchAtLogin": false,
            "hoverDelay": 0.2,
            "clickToOpen": true,
            "swipeToOpen": true,
            "swipeDownToOpen": true,
            "swipeUpToClose": true,
            "swipeBetweenWidgets": true,
            "autoClose": true,
            "closeOnOutsideClick": true,
            "autoCloseDelay": 6.0,
            "showMenuBarIcon": true,
            "showDockIcon": false,
            "enableHaptics": true,
            "virtualNotchWidth": 190.0,
            "minimumNotchWidth": 220.0,
            "maximumNotchWidth": 520.0,
            "expandedWidth": 1120.0,
            "expandedHeight": 280.0,
            "cornerRadius": 30.0,
            "opacity": 0.98,
            "animationSpeed": 1.0,
            "shadowEnabled": true,
            "compactMode": false,
            "maximumTrayItems": 12,
            "clearTrayOnQuit": true,
            "enableAirDrop": true,
            "showThumbnails": true,
            "automaticallySwitchToTray": true,
            "showMediaIsland": true,
            "showMediaStartPreview": true,
            "showMediaArtworkGradient": true,
            "enabledWidgets": [String](),
            "nookPages": (try? JSONEncoder().encode([NookPage.nook1, .nook2, .nook3])) ?? Data(),
            "widgetLayouts": [String: [String]](),
            "showWidgetScrollIndicator": false,
            "calendarRange": CalendarRange.today.rawValue,
            "maximumCalendarEvents": 6,
            "selectedCalendarIdentifiers": [String](),
            "displayPreference": DisplayPreference.underPointer.rawValue,
            "nookOpeningMode": NookOpeningMode.rememberLast.rawValue,
            "defaultNookPage": NookPage.nook1.id,
            "lastNookPage": NookPage.nook1.id,
            "neisEducationOfficeCode": "",
            "neisSchoolCode": "",
            "neisSchoolName": "",
            "schoolGrade": 1,
            "schoolClassNumber": 1,
            "maximumReminders": 6,
            "selectedReminderListIdentifiers": [String](),
            "defaultFocusMinutes": 25,
            "defaultBreakMinutes": 5,
            "manualWeatherLocation": "",
            "allowNetworkDetails": false,
            "allowMarketData": false,
            "marketItems": ["fx:USD-KRW", "stock:AAPL"]
            ,"keepAwakeAllowDisplaySleep": false
            ,"keepAwakeAllowClosedDisplaySleep": false
            ,"keepAwakeScreenSaverMinutes": 0
            ,"clipboardHistoryEnabled": true
            ,"developerRepositoryPath": ""
            ,"githubUsername": ""
            ,"showCodexUsage": false
            ,"quickActions": Data()
        ])

        appLanguage = AppLanguage(rawValue: defaults.string(forKey: "appLanguage") ?? "") ?? .system
        hoverToOpen = defaults.bool(forKey: "hoverToOpen")
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        hoverDelay = defaults.double(forKey: "hoverDelay")
        clickToOpen = defaults.bool(forKey: "clickToOpen")
        swipeToOpen = defaults.bool(forKey: "swipeToOpen")
        swipeDownToOpen = defaults.bool(forKey: "swipeDownToOpen")
        swipeUpToClose = defaults.bool(forKey: "swipeUpToClose")
        swipeBetweenWidgets = defaults.bool(forKey: "swipeBetweenWidgets")
        autoClose = defaults.bool(forKey: "autoClose")
        closeOnOutsideClick = defaults.bool(forKey: "closeOnOutsideClick")
        autoCloseDelay = defaults.double(forKey: "autoCloseDelay")
        showMenuBarIcon = defaults.bool(forKey: "showMenuBarIcon")
        showDockIcon = defaults.bool(forKey: "showDockIcon")
        enableHaptics = defaults.bool(forKey: "enableHaptics")
        virtualNotchWidth = defaults.double(forKey: "virtualNotchWidth")
        minimumNotchWidth = defaults.double(forKey: "minimumNotchWidth")
        maximumNotchWidth = defaults.double(forKey: "maximumNotchWidth")
        expandedWidth = defaults.double(forKey: "expandedWidth")
        expandedHeight = defaults.double(forKey: "expandedHeight")
        cornerRadius = defaults.double(forKey: "cornerRadius")
        opacity = defaults.double(forKey: "opacity")
        animationSpeed = defaults.double(forKey: "animationSpeed")
        shadowEnabled = defaults.bool(forKey: "shadowEnabled")
        compactMode = defaults.bool(forKey: "compactMode")
        maximumTrayItems = defaults.integer(forKey: "maximumTrayItems")
        clearTrayOnQuit = defaults.bool(forKey: "clearTrayOnQuit")
        enableAirDrop = defaults.bool(forKey: "enableAirDrop")
        showThumbnails = defaults.bool(forKey: "showThumbnails")
        automaticallySwitchToTray = defaults.bool(forKey: "automaticallySwitchToTray")
        showMediaIsland = defaults.bool(forKey: "showMediaIsland")
        showMediaStartPreview = defaults.bool(forKey: "showMediaStartPreview")
        showMediaArtworkGradient = defaults.bool(forKey: "showMediaArtworkGradient")
        let rawWidgets = defaults.stringArray(forKey: "enabledWidgets") ?? []
        enabledWidgets = rawWidgets.compactMap(WidgetType.init(rawValue:))
        let storedNookPages = (try? defaults.data(forKey: "nookPages").flatMap { try JSONDecoder().decode([NookPage].self, from: $0) }) ?? [.nook1, .nook2, .nook3]
        nookPages = storedNookPages
        widgetLayouts = defaults.dictionary(forKey: "widgetLayouts") as? [String: [String]]
            ?? defaults.dictionary(forKey: "additionalWidgetLayouts") as? [String: [String]]
            ?? [:]
        let storedSpans = defaults.dictionary(forKey: "widgetCellSpans") ?? [:]
        widgetCellSpans = Dictionary(uniqueKeysWithValues: WidgetType.allCases.map { widget in
            let value = (storedSpans[widget.rawValue] as? NSNumber)?.intValue ?? widget.defaultCellSpan
            return (widget, min(max(value, 1), 6))
        })
        showWidgetScrollIndicator = defaults.bool(forKey: "showWidgetScrollIndicator")
        calendarRange = CalendarRange(rawValue: defaults.string(forKey: "calendarRange") ?? "") ?? .today
        maximumCalendarEvents = defaults.integer(forKey: "maximumCalendarEvents")
        selectedCalendarIdentifiers = defaults.stringArray(forKey: "selectedCalendarIdentifiers") ?? []
        displayPreference = DisplayPreference(rawValue: defaults.string(forKey: "displayPreference") ?? "") ?? .underPointer
        nookOpeningMode = NookOpeningMode(rawValue: defaults.string(forKey: "nookOpeningMode") ?? "") ?? .rememberLast
        let restoredDefaultPage = storedNookPages.first(where: { $0.id == defaults.string(forKey: "defaultNookPage") }) ?? .nook1
        defaultNookPage = restoredDefaultPage
        lastNookPage = storedNookPages.first(where: { $0.id == defaults.string(forKey: "lastNookPage") }) ?? restoredDefaultPage
        neisAPIKey = KeychainSecretStore.read(account: "neis-api-key") ?? ""
        neisEducationOfficeCode = defaults.string(forKey: "neisEducationOfficeCode") ?? ""
        neisSchoolCode = defaults.string(forKey: "neisSchoolCode") ?? ""
        neisSchoolName = defaults.string(forKey: "neisSchoolName") ?? ""
        schoolGrade = min(max(defaults.integer(forKey: "schoolGrade"), 1), 3)
        schoolClassNumber = min(max(defaults.integer(forKey: "schoolClassNumber"), 1), 4)
        maximumReminders = defaults.integer(forKey: "maximumReminders")
        selectedReminderListIdentifiers = defaults.stringArray(forKey: "selectedReminderListIdentifiers") ?? []
        defaultFocusMinutes = defaults.integer(forKey: "defaultFocusMinutes")
        defaultBreakMinutes = defaults.integer(forKey: "defaultBreakMinutes")
        manualWeatherLocation = defaults.string(forKey: "manualWeatherLocation") ?? ""
        allowNetworkDetails = defaults.bool(forKey: "allowNetworkDetails")
        allowMarketData = defaults.bool(forKey: "allowMarketData")
        marketItems = (defaults.stringArray(forKey: "marketItems") ?? []).compactMap(MarketItem.init(storageValue:))
        keepAwakeAllowDisplaySleep = defaults.bool(forKey: "keepAwakeAllowDisplaySleep")
        keepAwakeAllowClosedDisplaySleep = defaults.bool(forKey: "keepAwakeAllowClosedDisplaySleep")
        keepAwakeScreenSaverMinutes = defaults.integer(forKey: "keepAwakeScreenSaverMinutes")
        clipboardHistoryEnabled = defaults.bool(forKey: "clipboardHistoryEnabled")
        developerRepositoryPath = defaults.string(forKey: "developerRepositoryPath") ?? ""
        githubUsername = defaults.string(forKey: "githubUsername") ?? ""
        showCodexUsage = defaults.bool(forKey: "showCodexUsage")
        quickActions = (try? defaults.data(forKey: "quickActions").flatMap { try JSONDecoder().decode([QuickAction].self, from: $0) }) ?? []

        if defaults.integer(forKey: "layoutVersion") < 2 {
            expandedWidth = 1120
            expandedHeight = 220
            enabledWidgets = WidgetType.allCases
            defaults.set(2, forKey: "layoutVersion")
        }

        if defaults.integer(forKey: "hoverDismissVersion") < 1 {
            autoCloseDelay = 6
            defaults.set(1, forKey: "hoverDismissVersion")
        }

        if defaults.integer(forKey: "calendarWheelLayoutVersion") < 1 {
            if (widgetCellSpans[.calendar] ?? 2) <= 2 {
                widgetCellSpans[.calendar] = 3
            }
            defaults.set(1, forKey: "calendarWheelLayoutVersion")
        }

        if defaults.integer(forKey: "timerLayoutHeightVersion") < 1 {
            if expandedHeight <= 220 { expandedHeight = 280 }
            defaults.set(1, forKey: "timerLayoutHeightVersion")
        }

        if defaults.integer(forKey: "productivityWidgetsLayoutVersion") < 2 {
            for widget in [WidgetType.reminders, .timer, .countdown, .stopwatch, .weather, .school, .network, .market, .display] where !enabledWidgets.contains(widget) {
                enabledWidgets.append(widget)
            }
            defaults.set(2, forKey: "productivityWidgetsLayoutVersion")
        }

        if defaults.integer(forKey: "utilityTimerWidgetsLayoutVersion") < 1 {
            for widget in [WidgetType.countdown, .stopwatch] where !enabledWidgets.contains(widget) {
                enabledWidgets.append(widget)
            }
            appendWidgetsToPrimaryLayoutIfPresent([.countdown, .stopwatch])
            defaults.set(1, forKey: "utilityTimerWidgetsLayoutVersion")
        }

        if defaults.integer(forKey: "keepAwakeWidgetLayoutVersion") < 1 {
            if !enabledWidgets.contains(.keepAwake) { enabledWidgets.append(.keepAwake) }
            appendWidgetsToPrimaryLayoutIfPresent([.keepAwake])
            defaults.set(1, forKey: "keepAwakeWidgetLayoutVersion")
        }

        if defaults.integer(forKey: "keepAwakeDisplaySleepDefaultVersion") < 1 {
            keepAwakeAllowDisplaySleep = false
            defaults.set(1, forKey: "keepAwakeDisplaySleepDefaultVersion")
        }

        if defaults.integer(forKey: "systemMonitorWidgetLayoutVersion") < 1 {
            if !enabledWidgets.contains(.systemMonitor) { enabledWidgets.append(.systemMonitor) }
            appendWidgetsToPrimaryLayoutIfPresent([.systemMonitor])
            defaults.set(1, forKey: "systemMonitorWidgetLayoutVersion")
        }

        if defaults.integer(forKey: "desktopUtilityWidgetsLayoutVersion") < 1 {
            let additions: [WidgetType] = [.clipboard, .audioControl, .batteryPower, .developer, .quickActions, .windowLayout, .devices]
            for widget in additions where !enabledWidgets.contains(widget) { enabledWidgets.append(widget) }
            appendWidgetsToPrimaryLayoutIfPresent(additions)
            defaults.set(1, forKey: "desktopUtilityWidgetsLayoutVersion")
        }

        if defaults.integer(forKey: "schoolTimetableSplitVersion") < 1 {
            if let schoolIndex = enabledWidgets.firstIndex(of: .school),
               !enabledWidgets.contains(.timetable) {
                enabledWidgets.insert(.timetable, at: schoolIndex + 1)
            }
            for pageID in Array(widgetLayouts.keys) {
                guard var layout = widgetLayouts[pageID],
                      let schoolIndex = layout.firstIndex(of: WidgetType.school.rawValue),
                      !layout.contains(WidgetType.timetable.rawValue) else { continue }
                layout.insert(WidgetType.timetable.rawValue, at: schoolIndex + 1)
                widgetLayouts[pageID] = layout
            }
            defaults.set(1, forKey: "schoolTimetableSplitVersion")
        }

        if isFreshWidgetConfiguration {
            enabledWidgets = []
            widgetLayouts = Dictionary(uniqueKeysWithValues: nookPages.map { ($0.id, []) })
        }
    }

    private func appendWidgetsToPrimaryLayoutIfPresent(_ widgets: [WidgetType]) {
        guard var layout = widgetLayouts[NookPage.nook1.id] else { return }
        for widget in widgets where !layout.contains(widget.rawValue) { layout.append(widget.rawValue) }
        widgetLayouts[NookPage.nook1.id] = layout
    }

    func widgets(for page: NookPage) -> [WidgetType] {
        let stored = widgetLayouts[page.id] ?? (page.id == NookPage.nook1.id ? enabledWidgets.map(\.rawValue) : [])
        return stored.compactMap(WidgetType.init(rawValue:))
    }

    func setWidget(_ widget: WidgetType, enabled: Bool, page: NookPage = .nook1) {
        var widgets = widgets(for: page)
        if enabled, !widgets.contains(widget) { widgets.append(widget) }
        if !enabled { widgets.removeAll { $0 == widget } }
        setWidgets(widgets, for: page)
    }

    func moveWidget(_ widget: WidgetType, offset: Int, page: NookPage = .nook1) {
        var widgets = widgets(for: page)
        guard let index = widgets.firstIndex(of: widget) else { return }
        let destination = index + offset
        guard widgets.indices.contains(destination) else { return }
        widgets.swapAt(index, destination)
        setWidgets(widgets, for: page)
    }

    private func setWidgets(_ widgets: [WidgetType], for page: NookPage) {
        widgetLayouts[page.id] = widgets.map(\.rawValue)
        if page.id == NookPage.nook1.id { enabledWidgets = widgets }
    }

    func cellSpan(for widget: WidgetType) -> Int {
        widgetCellSpans[widget] ?? widget.defaultCellSpan
    }

    var resolvedOpeningPage: NookPage {
        nookOpeningMode == .rememberLast ? lastNookPage : defaultNookPage
    }

    func rememberNookPage(_ page: NookPage) {
        lastNookPage = page
    }

    func addNookPage() -> NookPage {
        let page = NookPage(title: "Nook \(nookPages.count + 1)")
        nookPages.append(page)
        return page
    }

    func removeNookPage(_ page: NookPage) {
        guard nookPages.count > 1 else { return }
        nookPages.removeAll { $0.id == page.id }
        widgetLayouts[page.id] = nil
        if defaultNookPage.id == page.id { defaultNookPage = nookPages[0] }
        if lastNookPage.id == page.id { lastNookPage = nookPages[0] }
    }

    func setCellSpan(_ span: Int, for widget: WidgetType) {
        widgetCellSpans[widget] = min(max(span, 1), 6)
    }


    func setCalendar(_ identifier: String, enabled: Bool, availableIdentifiers: [String]) {
        if selectedCalendarIdentifiers.isEmpty, !enabled {
            selectedCalendarIdentifiers = availableIdentifiers.filter { $0 != identifier }
        } else if enabled, !selectedCalendarIdentifiers.contains(identifier) {
            selectedCalendarIdentifiers.append(identifier)
        } else if !enabled {
            selectedCalendarIdentifiers.removeAll { $0 == identifier }
        }

        if Set(selectedCalendarIdentifiers) == Set(availableIdentifiers) {
            selectedCalendarIdentifiers = []
        }
    }

    func reset() {
        appLanguage = .system
        hoverToOpen = true
        launchAtLogin = false
        hoverDelay = 0.2
        clickToOpen = true
        swipeToOpen = true
        swipeDownToOpen = true
        swipeUpToClose = true
        swipeBetweenWidgets = true
        autoClose = true
        closeOnOutsideClick = true
        autoCloseDelay = 6
        showMenuBarIcon = true
        showDockIcon = false
        enableHaptics = true
        virtualNotchWidth = 190
        minimumNotchWidth = 220
        maximumNotchWidth = 520
        expandedWidth = 1120
        expandedHeight = 280
        cornerRadius = 30
        opacity = 0.98
        animationSpeed = 1
        shadowEnabled = true
        compactMode = false
        maximumTrayItems = 12
        clearTrayOnQuit = true
        enableAirDrop = true
        showThumbnails = true
        automaticallySwitchToTray = true
        showMediaIsland = true
        showMediaStartPreview = true
        showMediaArtworkGradient = true
        enabledWidgets = WidgetType.allCases
        widgetLayouts = [:]
        widgetCellSpans = Dictionary(uniqueKeysWithValues: WidgetType.allCases.map { ($0, $0.defaultCellSpan) })
        showWidgetScrollIndicator = false
        calendarRange = .today
        maximumCalendarEvents = 6
        selectedCalendarIdentifiers = []
        displayPreference = .underPointer
        nookOpeningMode = .rememberLast
        nookPages = [.nook1, .nook2, .nook3]
        widgetLayouts = [:]
        defaultNookPage = .nook1
        lastNookPage = .nook1
        neisAPIKey = ""
        neisEducationOfficeCode = ""
        neisSchoolCode = ""
        neisSchoolName = ""
        schoolGrade = 1
        schoolClassNumber = 1
        maximumReminders = 6
        selectedReminderListIdentifiers = []
        defaultFocusMinutes = 25
        defaultBreakMinutes = 5
        manualWeatherLocation = ""
        allowNetworkDetails = false
        allowMarketData = false
        marketItems = [.currency(base: "USD", quote: "KRW"), .stock(symbol: "AAPL")]
        keepAwakeAllowDisplaySleep = false
        keepAwakeAllowClosedDisplaySleep = false
        keepAwakeScreenSaverMinutes = 0
        clipboardHistoryEnabled = true
        developerRepositoryPath = ""
        githubUsername = ""
        showCodexUsage = false
        quickActions = []
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }

    func localized(_ key: String) -> String {
        appLanguage.localized(key)
    }

    private func saveWidgets() {
        defaults.set(enabledWidgets.map(\.rawValue), forKey: "enabledWidgets")
    }

    private func saveNookPages() {
        defaults.set(try? JSONEncoder().encode(nookPages), forKey: "nookPages")
    }

    private func saveMarketItems() {
        defaults.set(marketItems.map(\.storageValue), forKey: "marketItems")
    }

    private func saveQuickActions() {
        defaults.set(try? JSONEncoder().encode(quickActions), forKey: "quickActions")
    }

    private func saveWidgetCellSpans() {
        defaults.set(
            Dictionary(uniqueKeysWithValues: widgetCellSpans.map { ($0.key.rawValue, $0.value) }),
            forKey: "widgetCellSpans"
        )
    }
}
