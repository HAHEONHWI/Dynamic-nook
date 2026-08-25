import Foundation
import XCTest
@testable import NookClone

@MainActor
final class StoreTests: XCTestCase {
    func testAppStoreCyclesEnabledWidgets() {
        let store = AppStore()
        store.activeWidget = .media
        store.selectAdjacentWidget(offset: 1, enabled: [.media, .calendar, .mirror])
        XCTAssertEqual(store.activeWidget, .calendar)
        store.selectAdjacentWidget(offset: -1, enabled: [.media, .calendar, .mirror])
        XCTAssertEqual(store.activeWidget, .media)
    }

    func testPeekingClickToggleOpensExpandedBar() {
        let store = AppStore()
        store.nookState = .peeking
        store.toggle()
        XCTAssertEqual(store.nookState, .expanded)
    }

    func testCompactMediaIslandCanBeHiddenAndRestored() {
        let store = AppStore()
        store.nookState = .peeking

        store.hideMediaIsland()

        XCTAssertTrue(store.isMediaIslandManuallyHidden)
        XCTAssertEqual(store.nookState, .collapsed)

        store.restoreMediaIsland()

        XCTAssertFalse(store.isMediaIslandManuallyHidden)
    }

    func testFileDragTargetHasSingleSourceOfTruth() {
        let store = AppStore()
        store.fileDropTarget = .tray
        XCTAssertTrue(store.isDraggingFile)
        store.fileDropTarget = .airDrop
        XCTAssertTrue(store.isDraggingFile)
        store.collapse()
        XCTAssertNil(store.fileDropTarget)
        XCTAssertFalse(store.isDraggingFile)
    }

    func testTrayDeduplicatesAndCapsItems() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TrayStore(trayDirectory: directory.appending(path: "tray", directoryHint: .isDirectory))
        let first = directory.appending(path: "first.txt")
        let second = directory.appending(path: "second.txt")
        try Data("one".utf8).write(to: first)
        try Data("two".utf8).write(to: second)

        XCTAssertEqual(store.add(urls: [first, first, second], maximum: 1), 1)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.displayName, "first.txt")
    }

    func testTrayMovesFileAndRestoresOriginalLocation() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TrayStore(trayDirectory: directory.appending(path: "tray", directoryHint: .isDirectory))
        let source = directory.appending(path: "move-me.txt")
        try Data("tray".utf8).write(to: source)

        XCTAssertEqual(store.add(urls: [source], maximum: 2), 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        let item = try XCTUnwrap(store.items.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.url.path))

        store.remove(item)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testSettingsPersist() {
        let suite = "NookCloneTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.expandedWidth = 525
        settings.hoverToOpen = false
        settings.appLanguage = .korean
        settings.showMediaIsland = false
        settings.showMediaStartPreview = false
        settings.showMediaArtworkGradient = false
        settings.minimumNotchWidth = 240
        settings.maximumNotchWidth = 610
        settings.keepAwakeAllowDisplaySleep = false
        settings.keepAwakeAllowClosedDisplaySleep = true
        settings.keepAwakeScreenSaverMinutes = 45
        settings.clipboardHistoryEnabled = false
        settings.developerRepositoryPath = "/tmp/project"
        settings.showCodexUsage = true
        settings.githubUsername = "octocat"
        settings.quickActions = [QuickAction(title: "Docs", target: "https://example.com")]

        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.expandedWidth, 525)
        XCTAssertFalse(restored.hoverToOpen)
        XCTAssertEqual(restored.appLanguage, .korean)
        XCTAssertFalse(restored.showMediaIsland)
        XCTAssertFalse(restored.showMediaStartPreview)
        XCTAssertFalse(restored.showMediaArtworkGradient)
        XCTAssertEqual(restored.minimumNotchWidth, 240)
        XCTAssertEqual(restored.maximumNotchWidth, 610)
        XCTAssertFalse(restored.keepAwakeAllowDisplaySleep)
        XCTAssertTrue(restored.keepAwakeAllowClosedDisplaySleep)
        XCTAssertEqual(restored.keepAwakeScreenSaverMinutes, 45)
        XCTAssertFalse(restored.clipboardHistoryEnabled)
        XCTAssertEqual(restored.developerRepositoryPath, "/tmp/project")
        XCTAssertTrue(restored.showCodexUsage)
        XCTAssertEqual(restored.githubUsername, "octocat")
        XCTAssertEqual(restored.quickActions, settings.quickActions)
    }

    func testHoverDismissDefaultsToSixSeconds() {
        let suite = "NookHoverTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.autoCloseDelay, 6)
    }

    func testMediaPresentationTransitionIgnoresPauseAndResume() {
        let playing = MediaInfo(
            title: "Same Video",
            artist: "Creator",
            duration: 180,
            position: 20,
            isPlaying: true,
            playerName: "Browser",
            playerBundleIdentifier: "com.example.browser",
            artworkData: nil
        )
        var paused = playing
        paused.position = 35
        paused.isPlaying = false
        let identity = MediaPresentationTransition.identity(for: playing)

        XCTAssertEqual(
            MediaPresentationTransition.resolve(previousIdentity: nil, currentIdentity: identity),
            .newMedia
        )
        XCTAssertEqual(
            MediaPresentationTransition.resolve(
                previousIdentity: identity,
                currentIdentity: MediaPresentationTransition.identity(for: paused)
            ),
            .none
        )
        XCTAssertEqual(
            MediaPresentationTransition.resolve(previousIdentity: identity, currentIdentity: nil),
            .ended
        )
    }

    func testMediaPresentationTransitionDetectsNewTrack() {
        XCTAssertEqual(
            MediaPresentationTransition.resolve(
                previousIdentity: "browser\u{1F}First\u{1F}Artist",
                currentIdentity: "browser\u{1F}Second\u{1F}Artist"
            ),
            .newMedia
        )
    }

    func testLanguageFallbackUsesEnglishForUnsupportedSystemLanguage() {
        XCTAssertEqual(AppLanguage.supportedLanguageCode(preferredLanguages: ["ko-KR"]), "ko")
        XCTAssertEqual(AppLanguage.supportedLanguageCode(preferredLanguages: ["en-US"]), "en")
        XCTAssertEqual(AppLanguage.supportedLanguageCode(preferredLanguages: ["ja-JP"]), "en")
        XCTAssertEqual(AppLanguage.supportedLanguageCode(preferredLanguages: []), "en")
    }

    func testLocalizedResourcesContainEnglishAndKorean() {
        XCTAssertEqual(AppLanguage.english.localized("General"), "General")
        XCTAssertEqual(AppLanguage.korean.localized("General"), "일반")
        XCTAssertEqual(AppLanguage.korean.localized("Language"), "언어")
    }

    func testNookOpeningPageCanRememberOrUseFixedPage() {
        let suite = "NookPageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)

        let secondPage = settings.nookPages[1]
        settings.rememberNookPage(secondPage)
        XCTAssertEqual(settings.resolvedOpeningPage, secondPage)

        settings.nookOpeningMode = .fixedPage
        settings.defaultNookPage = secondPage
        XCTAssertEqual(settings.resolvedOpeningPage, secondPage)
    }

    func testWidgetWidthAndOrderPersist() {
        let suite = "NookCloneTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.setWidget(.mirror, enabled: true)
        settings.setWidget(.notes, enabled: true)
        settings.setCellSpan(5, for: .notes)
        settings.moveWidget(.notes, offset: -1)

        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.cellSpan(for: .notes), 5)
        XCTAssertEqual(restored.enabledWidgets, settings.enabledWidgets)
        XCTAssertLessThan(
            restored.enabledWidgets.firstIndex(of: .notes)!,
            restored.enabledWidgets.firstIndex(of: .mirror)!
        )
    }

    func testFreshInstallStartsWithEveryNookWidgetDisabled() {
        let suite = "NookFreshWidgetTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = SettingsStore(defaults: defaults)

        XCTAssertTrue(settings.enabledWidgets.isEmpty)
        XCTAssertTrue(settings.nookPages.allSatisfy { settings.widgets(for: $0).isEmpty })

        settings.setWidget(.weather, enabled: true, page: settings.nookPages[1])
        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.widgets(for: restored.nookPages[1]), [.weather])
        XCTAssertTrue(restored.widgets(for: .nook1).isEmpty)
    }

    func testSchoolTimetableClassSelectionPersists() {
        let suite = "NookSchoolTimetableSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = SettingsStore(defaults: defaults)
        settings.schoolGrade = 2
        settings.schoolClassNumber = 3

        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.schoolGrade, 2)
        XCTAssertEqual(restored.schoolClassNumber, 3)
    }

    func testSchoolTimetableSplitMigrationPlacesTimetableAfterSchool() {
        let suite = "NookSchoolTimetableSplitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(2, forKey: "layoutVersion")
        defaults.set(2, forKey: "productivityWidgetsLayoutVersion")
        defaults.set(1, forKey: "utilityTimerWidgetsLayoutVersion")
        defaults.set(1, forKey: "keepAwakeWidgetLayoutVersion")
        defaults.set(1, forKey: "systemMonitorWidgetLayoutVersion")
        defaults.set(1, forKey: "desktopUtilityWidgetsLayoutVersion")
        defaults.set([WidgetType.notes.rawValue, WidgetType.school.rawValue, WidgetType.weather.rawValue], forKey: "enabledWidgets")
        defaults.set([
            NookPage.nook1.id: [WidgetType.notes.rawValue, WidgetType.school.rawValue, WidgetType.weather.rawValue],
            NookPage.nook2.id: [WidgetType.school.rawValue]
        ], forKey: "widgetLayouts")

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.widgets(for: .nook1), [.notes, .school, .timetable, .weather])
        XCTAssertEqual(settings.widgets(for: .nook2), [.school, .timetable])
        XCTAssertEqual(settings.cellSpan(for: .timetable), 3)
    }

    func testProductivityWidgetMigrationPreservesExistingLayoutAndSettings() {
        let suite = "NookProductivityMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(2, forKey: "layoutVersion")
        defaults.set([WidgetType.notes.rawValue, WidgetType.calendar.rawValue], forKey: "enabledWidgets")
        defaults.set([WidgetType.notes.rawValue: 5], forKey: "widgetCellSpans")
        defaults.set(9, forKey: "maximumReminders")
        defaults.set(["school"], forKey: "selectedReminderListIdentifiers")
        defaults.set(45, forKey: "defaultFocusMinutes")
        defaults.set(10, forKey: "defaultBreakMinutes")
        defaults.set("Daegu", forKey: "manualWeatherLocation")

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(Array(settings.enabledWidgets.prefix(2)), [.notes, .calendar])
        XCTAssertTrue([.reminders, .timer, .weather, .school, .network, .market, .display].allSatisfy(settings.enabledWidgets.contains))
        XCTAssertEqual(settings.cellSpan(for: .notes), 5)
        XCTAssertEqual(settings.cellSpan(for: .reminders), 3)
        XCTAssertEqual(settings.cellSpan(for: .timer), 2)
        XCTAssertEqual(settings.cellSpan(for: .weather), 3)
        XCTAssertEqual(settings.maximumReminders, 9)
        XCTAssertEqual(settings.selectedReminderListIdentifiers, ["school"])
        XCTAssertEqual(settings.defaultFocusMinutes, 45)
        XCTAssertEqual(settings.defaultBreakMinutes, 10)
        XCTAssertEqual(settings.manualWeatherLocation, "Daegu")
    }

    func testNewUtilityWidgetsAppendToExistingPrimaryLayout() {
        let suite = "NookUtilityMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(2, forKey: "layoutVersion")
        defaults.set(2, forKey: "productivityWidgetsLayoutVersion")
        defaults.set([WidgetType.notes.rawValue], forKey: "enabledWidgets")
        defaults.set([NookPage.nook1.id: [WidgetType.notes.rawValue]], forKey: "widgetLayouts")

        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.widgets(for: .nook1), [.notes, .countdown, .stopwatch, .keepAwake, .systemMonitor, .clipboard, .audioControl, .batteryPower, .developer, .quickActions, .windowLayout, .devices])
    }

    func testNotesPersistAndCapAtFour() {
        let suite = "NookCloneNotesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let notes = NotesStore(defaults: defaults)
        for _ in 0..<8 { notes.addNote() }
        notes.updateSelected { $0.text = "Persistent note" }

        XCTAssertEqual(notes.notes.count, 4)
        XCTAssertEqual(NotesStore(defaults: defaults).notes.last?.text, "Persistent note")
    }

    func testLiveActionPriorityAndQueue() async throws {
        let manager = LiveActionManager()
        let normal = LiveAction(icon: "circle", title: "Normal", duration: 0.03)
        let urgent = LiveAction(icon: "exclamationmark", title: "Urgent", duration: 0.03, priority: .critical)
        manager.enqueue(normal)
        manager.enqueue(urgent)
        XCTAssertEqual(manager.currentAction?.title, "Urgent")
        try await Task.sleep(for: .milliseconds(45))
        XCTAssertEqual(manager.currentAction?.title, "Normal")
        manager.clear()
    }
}
