import AppKit
import SwiftUI

struct WidgetSettingsView: View {
    let environment: AppEnvironment
    @State private var selectedWidget: WidgetType = .calendar
    @State private var selectedPage: NookPage = .nook1
    @State private var stockCode = ""
    @State private var quickActionTitle = ""
    @State private var quickActionTarget = ""

    var body: some View {
        HStack(spacing: 0) {
            widgetList
                .frame(width: 260)
            Divider()
            widgetDetail
        }
        .navigationTitle(environment.settings.localized("Widgets"))
    }

    private var widgetList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(orderedWidgets) { widget in
                    widgetRow(widget)
                }
            }
            .padding(14)
        }
        .background(.quaternary.opacity(0.28))
    }

    private func widgetRow(_ widget: WidgetType) -> some View {
        let enabled = environment.settings.widgets(for: selectedPage).contains(widget)
        return HStack(spacing: 11) {
            Image(systemName: widget.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(widget.title)).fontWeight(.semibold)
                Text("\(environment.settings.cellSpan(for: widget)) \(environment.settings.localized("cells"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(
                "",
                isOn: Binding(
                    get: { enabled },
                    set: { environment.settings.setWidget(widget, enabled: $0, page: selectedPage) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selectedWidget == widget ? Color.accentColor.opacity(0.55) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedWidget = widget }
    }

    private var widgetDetail: some View {
        @Bindable var settings = environment.settings

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Widget Layout").font(.title2.bold())
                Text("Enable, resize, and reorder cells in the wide Nook bar.")
                    .foregroundStyle(.secondary)

                Picker("Nook board", selection: $selectedPage) {
                    ForEach(environment.settings.nookPages) { page in
                        Text(page.title).tag(page)
                    }
                }
                HStack {
                    Button("Add Nook") { selectedPage = environment.settings.addNookPage() }
                    Button("Delete Nook", role: .destructive) { environment.settings.removeNookPage(selectedPage); selectedPage = environment.settings.nookPages[0] }
                        .disabled(environment.settings.nookPages.count == 1)
                }

                layoutPreview

                SettingsCard {
                    LabeledContent("Width") {
                        Slider(
                            value: Binding(
                                get: { Double(settings.cellSpan(for: selectedWidget)) },
                                set: { settings.setCellSpan(Int($0.rounded()), for: selectedWidget) }
                            ),
                            in: 1...6,
                            step: 1
                        )
                        .frame(width: 240)
                        Text("\(settings.cellSpan(for: selectedWidget)) \(settings.localized("cells"))")
                            .monospacedDigit()
                    }

                    HStack {
                        Button("Move Left", systemImage: "arrow.left") {
                            settings.moveWidget(selectedWidget, offset: -1, page: selectedPage)
                        }
                        Button("Move Right", systemImage: "arrow.right") {
                            settings.moveWidget(selectedWidget, offset: 1, page: selectedPage)
                        }
                        Spacer()
                        Toggle("Show scroll indicator", isOn: $settings.showWidgetScrollIndicator)
                    }
                    .disabled(!settings.widgets(for: selectedPage).contains(selectedWidget))
                }

                selectedWidgetSettings
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var layoutPreview: some View {
        let widgets = environment.settings.widgets(for: selectedPage)
        return ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 8) {
                ForEach(widgets) { widget in
                    Button {
                        selectedWidget = widget
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: widget.systemImage)
                            Text(LocalizedStringKey(widget.title)).lineLimit(1)
                        }
                        .font(.caption.weight(.semibold))
                        .frame(width: max(150, 74 * CGFloat(environment.settings.cellSpan(for: widget))), height: 76)
                        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 13))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(selectedWidget == widget ? Color.accentColor : .clear, lineWidth: 3)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 7)
        }
        .scrollIndicators(.visible)
        .frame(height: 91)
        .padding(10)
        .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var selectedWidgetSettings: some View {
        switch selectedWidget {
        case .calendar:
            calendarSettings
        case .notes:
            notesSettings
        case .media:
            @Bindable var settings = environment.settings
            SettingsCard {
                Label("System Now Playing", systemImage: "waveform")
                Toggle("Show Media Island", isOn: $settings.showMediaIsland)
                Toggle("Show controls for 3 seconds when new media starts", isOn: $settings.showMediaStartPreview)
                    .disabled(!settings.showMediaIsland)
                Toggle("Use artwork color gradient", isOn: $settings.showMediaArtworkGradient)
                    .disabled(!settings.showMediaIsland)
                Text("Show compact controls around the notch while media is playing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Artwork, playback controls, progress, and compact Media Island are automatic.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .shortcuts:
            SettingsCard {
                Label("Shortcuts", systemImage: "bolt.fill")
                Text("Available shortcuts load from the macOS Shortcuts app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .mirror:
            SettingsCard {
                Label("Mirror", systemImage: "camera")
                Text("Camera starts only while the Mirror cell is visible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .reminders:
            reminderSettings
        case .timer:
            timerSettings
        case .countdown:
            SettingsCard {
                Text("Timer").font(.headline)
                Text("A standalone countdown timer with 1, 5, and 10 minute presets.").font(.caption).foregroundStyle(.secondary)
            }
        case .stopwatch:
            SettingsCard {
                Text("Stopwatch").font(.headline)
                Text("A standalone elapsed-time stopwatch.").font(.caption).foregroundStyle(.secondary)
            }
        case .weather:
            weatherSettings
        case .school:
            schoolWidgetSettings
        case .timetable:
            timetableWidgetSettings
        case .network:
            networkSettings
        case .market:
            marketSettings
        case .display:
            SettingsCard {
                Text("Display Control").font(.headline)
                Text("Adjust connected displays from this widget.").font(.caption).foregroundStyle(.secondary)
            }
        case .keepAwake:
            keepAwakeSettings
        case .systemMonitor:
            SettingsCard {
                Text("System Monitor").font(.headline)
                Text("Shows live CPU, memory, and disk usage.").font(.caption).foregroundStyle(.secondary)
            }
        case .clipboard:
            @Bindable var settings = environment.settings
            SettingsCard {
                Text("Clipboard History").font(.headline)
                Toggle("Enable Clipboard History", isOn: $settings.clipboardHistoryEnabled)
                Text("Keeps up to 20 recent text, link, and image entries in memory. Password-like content is excluded.").font(.caption).foregroundStyle(.secondary)
            }
        case .audioControl:
            SettingsCard { Text("Audio Control").font(.headline); Text("Switch output devices and control their main volume.").font(.caption).foregroundStyle(.secondary); Button("Open Sound Settings") { environment.audioControlService.openSoundSettings() } }
        case .batteryPower:
            SettingsCard { Text("Battery & Power").font(.headline); Text("Shows charge, power source, remaining time, cycles, and battery health when macOS provides them.").font(.caption).foregroundStyle(.secondary) }
        case .developer:
            developerSettings
        case .quickActions:
            quickActionSettings
        case .windowLayout:
            SettingsCard { Text("Window Layout").font(.headline); Text("Moves the frontmost app window using Accessibility access.").font(.caption).foregroundStyle(.secondary); Button("Grant Accessibility Permission") { environment.windowLayoutService.requestPermission() } }
        case .devices:
            SettingsCard { Text("Connected Devices").font(.headline); Text("Shows connected Bluetooth and USB devices reported by macOS.").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private var developerSettings: some View {
        @Bindable var settings = environment.settings
        return SettingsCard {
            Text("Developer").font(.headline)
            TextField("Git repository path", text: $settings.developerRepositoryPath)
            Button("Choose Folder") {
                let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
                if panel.runModal() == .OK { settings.developerRepositoryPath = panel.url?.path ?? "" }
            }
            Divider()
            TextField("GitHub username", text: $settings.githubUsername)
            Text("Leave blank to detect the owner from the repository's origin remote. Public profile data only; no token is stored.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Toggle("Show local Codex token usage", isOn: $settings.showCodexUsage)
            Text("Reads local Codex session logs only to extract usage metadata. Prompt content is never displayed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var quickActionSettings: some View {
        @Bindable var settings = environment.settings
        return SettingsCard {
            Text("Quick Actions").font(.headline)
            Text("Use a URL, file path, app path, or shell:command target.").font(.caption).foregroundStyle(.secondary)
            ForEach(settings.quickActions) { action in
                HStack { VStack(alignment: .leading) { Text(action.title); Text(action.target).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); Button(role: .destructive) { settings.quickActions.removeAll { $0.id == action.id } } label: { Image(systemName: "minus.circle") } }
            }
            TextField("Action name", text: $quickActionTitle)
            TextField("URL, path, or shell:command", text: $quickActionTarget)
            Button("Add Quick Action") {
                let title = quickActionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let target = quickActionTarget.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, QuickActionTarget.parse(target) != nil else { return }
                settings.quickActions.append(QuickAction(title: title, target: target)); quickActionTitle = ""; quickActionTarget = ""
            }.disabled(quickActionTitle.isEmpty || quickActionTarget.isEmpty)
        }
    }

    private var reminderSettings: some View {
        @Bindable var settings = environment.settings
        let lists = environment.reminderService.availableLists
        let identifiers = lists.map(\.id)
        return SettingsCard {
            Text("Reminders Details").font(.headline)
            Stepper("\(settings.localized("Maximum reminders")): \(settings.maximumReminders)", value: $settings.maximumReminders, in: 1...12)
            if environment.reminderService.permissionState == .fullAccess {
                ForEach(lists) { list in
                    Toggle(list.title, isOn: Binding(
                        get: { settings.selectedReminderListIdentifiers.isEmpty || settings.selectedReminderListIdentifiers.contains(list.id) },
                        set: { enabled in
                            var selected = settings.selectedReminderListIdentifiers.isEmpty ? identifiers : settings.selectedReminderListIdentifiers
                            if enabled { if !selected.contains(list.id) { selected.append(list.id) } }
                            else { selected.removeAll { $0 == list.id } }
                            settings.selectedReminderListIdentifiers = Set(selected) == Set(identifiers) ? [] : selected
                        }
                    ))
                }
            } else {
                Button("Grant Reminders Access") {
                    Task { await environment.reminderService.requestAccessAndRefresh(maximum: settings.maximumReminders, selectedListIdentifiers: settings.selectedReminderListIdentifiers) }
                }
            }
        }
    }

    private var timerSettings: some View {
        @Bindable var settings = environment.settings
        return SettingsCard {
            Text("Focus Timer Details").font(.headline)
            Stepper("\(settings.localized("Default focus")): \(settings.defaultFocusMinutes) min", value: $settings.defaultFocusMinutes, in: 5...120, step: 5)
            Stepper("\(settings.localized("Default break")): \(settings.defaultBreakMinutes) min", value: $settings.defaultBreakMinutes, in: 1...30)
        }
    }

    private var keepAwakeSettings: some View {
        @Bindable var settings = environment.settings
        return SettingsCard {
            Text("Keep Awake").font(.headline)
            Text("Prevents the Mac from sleeping for a selected duration.").font(.caption).foregroundStyle(.secondary)

            if environment.keepAwakeService.isActive {
                Divider()
                Text("Current Session Details").font(.subheadline.weight(.semibold))
                LabeledContent("Time Remaining", value: environment.keepAwakeService.remainingText)
                Text("Manual Activation").font(.caption).foregroundStyle(.secondary)
            }

            Toggle("Allow display sleep", isOn: keepAwakeBinding(
                get: { settings.keepAwakeAllowDisplaySleep },
                set: { settings.keepAwakeAllowDisplaySleep = $0 }
            ))
            Toggle("Allow system sleep when display is closed", isOn: keepAwakeBinding(
                get: { settings.keepAwakeAllowClosedDisplaySleep },
                set: { settings.keepAwakeAllowClosedDisplaySleep = $0 }
            ))
            if !settings.keepAwakeAllowClosedDisplaySleep {
                Label("Administrator permission is requested when the session starts.", systemImage: "lock.shield")
                    .font(.caption2).foregroundStyle(.orange)
            }
            Picker("Allow screen saver after inactivity", selection: keepAwakeBinding(
                get: { settings.keepAwakeScreenSaverMinutes },
                set: { settings.keepAwakeScreenSaverMinutes = $0 }
            )) {
                Text("Off").tag(0)
                ForEach([15, 30, 45, 60], id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }

            if environment.keepAwakeService.isActive {
                Button("End Current Session", role: .destructive) { environment.keepAwakeService.stop() }
                    .frame(maxWidth: .infinity)
            }
            Text("Closed-display prevention is restored automatically when the session or app ends.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func keepAwakeBinding<Value: Sendable>(
        get: @escaping @MainActor @Sendable () -> Value,
        set: @escaping @MainActor @Sendable (Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: get,
            set: { value in
                set(value)
                environment.keepAwakeService.updateConfiguration(
                    allowDisplaySleep: environment.settings.keepAwakeAllowDisplaySleep,
                    allowClosedDisplaySleep: environment.settings.keepAwakeAllowClosedDisplaySleep,
                    screenSaverMinutes: environment.settings.keepAwakeScreenSaverMinutes
                )
            }
        )
    }

    private var weatherSettings: some View {
        @Bindable var settings = environment.settings
        return SettingsCard {
            Text("Weather Details").font(.headline)
            TextField("Manual location", text: $settings.manualWeatherLocation)
            Text("Used when location access is unavailable.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var schoolWidgetSettings: some View {
        SettingsCard {
            Text("School Widget").font(.headline)
            Text("School widget uses NEIS school, meal, and schedule settings.").font(.caption).foregroundStyle(.secondary)
            Button("Open School Settings") { environment.openSettings(.school) }
        }
    }

    private var timetableWidgetSettings: some View {
        SettingsCard {
            Text("Timetable Widget").font(.headline)
            Text("Timetable widget uses DGSW grade and class settings.").font(.caption).foregroundStyle(.secondary)
            Button("Open School Settings") { environment.openSettings(.school) }
        }
    }

    private var networkSettings: some View {
        @Bindable var settings = environment.settings
        return SettingsCard {
            Text("Network Privacy").font(.headline)
            Toggle("Allow Network Details", isOn: $settings.allowNetworkDetails)
            Text("When enabled, nook3h calls api.ipify.org to show public IP. Wi-Fi name and VPN state stay local. Link speed is shown only when macOS provides it.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var marketSettings: some View {
        @Bindable var settings = environment.settings
        return SettingsCard {
            Text("Market Data Policy").font(.headline)
            Toggle("Allow Market Data", isOn: $settings.allowMarketData)
            Text("Currency uses Frankfurter. Stocks use Yahoo Finance chart data. Quotes may be delayed; no trading functions.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(settings.marketItems) { item in
                HStack {
                    Text(item.title)
                    Spacer()
                    Button(role: .destructive) { settings.marketItems.removeAll { $0 == item } } label: { Image(systemName: "minus.circle") }
                }
            }
            HStack {
                Button("Add USD/KRW") { addMarketItem(.currency(base: "USD", quote: "KRW")) }
                Button("Add AAPL") { addMarketItem(.stock(symbol: "AAPL")) }
            }
            HStack {
                TextField("Stock ticker or KRX code", text: $stockCode)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addStockCode)
                Button("Add Stock", action: addStockCode)
                    .disabled(stockCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func addMarketItem(_ item: MarketItem) {
        if !environment.settings.marketItems.contains(item) { environment.settings.marketItems.append(item) }
    }

    private func addStockCode() {
        let code = stockCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        addMarketItem(.stock(symbol: code))
        stockCode = ""
    }

    private var calendarSettings: some View {
        @Bindable var settings = environment.settings
        let calendars = environment.calendarService.availableCalendars
        let identifiers = calendars.map(\.id)

        return SettingsCard {
            Text("Calendar Details").font(.headline)
            Picker("Range", selection: $settings.calendarRange) {
                ForEach(CalendarRange.allCases) { range in
                    Text(LocalizedStringKey(range.title)).tag(range)
                }
            }
            Stepper(
                "\(settings.localized("Maximum events")): \(settings.maximumCalendarEvents)",
                value: $settings.maximumCalendarEvents,
                in: 1...12
            )

            if environment.calendarService.permissionState == .fullAccess {
                Divider()
                Text("Calendars").font(.subheadline.weight(.semibold))
                ForEach(calendars) { calendar in
                    Toggle(
                        isOn: Binding(
                            get: {
                                settings.selectedCalendarIdentifiers.isEmpty ||
                                    settings.selectedCalendarIdentifiers.contains(calendar.id)
                            },
                            set: {
                                settings.setCalendar(calendar.id, enabled: $0, availableIdentifiers: identifiers)
                            }
                        )
                    ) {
                        Label {
                            Text(calendar.title)
                        } icon: {
                            Circle().fill(Color(hex: calendar.colorHex)).frame(width: 9, height: 9)
                        }
                    }
                }
            } else {
                Button("Grant Calendar Access") {
                    Task {
                        await environment.calendarService.requestAccessAndRefresh(
                            range: settings.calendarRange,
                            maximum: settings.maximumCalendarEvents,
                            selectedCalendarIdentifiers: settings.selectedCalendarIdentifiers
                        )
                    }
                }
            }
        }
    }

    private var notesSettings: some View {
        SettingsCard {
            Text("Notes Details").font(.headline)
            Toggle(
                "Code mode for selected note",
                isOn: Binding(
                    get: { environment.notesStore.selectedNote?.isCodeMode ?? false },
                    set: { value in environment.notesStore.updateSelected { $0.isCodeMode = value } }
                )
            )
            Text("Up to four notes. Color, bold, italic, underline, and code style persist automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var orderedWidgets: [WidgetType] {
        environment.settings.widgets(for: selectedPage) + WidgetType.allCases.filter {
            !environment.settings.widgets(for: selectedPage).contains($0)
        }
    }
}
