import SwiftUI

struct ExpandedNookView: View {
    let environment: AppEnvironment

    var body: some View {
        VStack(spacing: 7) {
            nookHeader
            dashboard
        }
        .foregroundStyle(.white)
    }

    private var nookHeader: some View {
        HStack(spacing: 5) {
            ForEach(environment.settings.nookPages) { page in
                Button {
                    environment.appStore.selectPage(page)
                    environment.settings.rememberNookPage(page)
                } label: {
                    Label(LocalizedStringKey(page.title), systemImage: page.systemImage)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .background(
                            .white.opacity(environment.appStore.activePage == page ? 0.14 : 0),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(environment.appStore.activePage == page ? 1 : 0.45))
            }

            Button {
                let page = environment.settings.addNookPage()
                environment.appStore.selectPage(page)
            } label: { Image(systemName: "plus") }
            .buttonStyle(NookIconButtonStyle())

            Button {
                environment.appStore.openTray()
            } label: {
                Label("Tray", systemImage: "tray.full")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .frame(height: 25)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.45))
            .accessibilityLabel("Open File Tray")

            Spacer()

            Button {
                environment.openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(NookIconButtonStyle())
            .accessibilityLabel("Open Settings")
        }
    }

    private var dashboard: some View {
        widgetDashboard(for: environment.appStore.activePage)
    }

    private func widgetDashboard(for page: NookPage) -> some View {
        GeometryReader { geometry in
            let widgets = environment.settings.widgets(for: page)
            let totalSpans = max(1, widgets.reduce(0) { $0 + environment.settings.cellSpan(for: $1) })
            let spacing = CGFloat(max(0, widgets.count - 1)) * 10
            let unitWidth = min(150, max(86, (geometry.size.width - spacing) / CGFloat(totalSpans)))

            if widgets.isEmpty {
                ContentUnavailableView {
                    Label("No Widgets Enabled", systemImage: "rectangle.3.group")
                        .foregroundStyle(.white)
                } description: {
                    Text("Enable widgets in Settings.")
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: environment.settings.showWidgetScrollIndicator) {
                        HStack(spacing: 10) {
                            ForEach(widgets) { widget in
                                widgetCell(widget)
                                    .frame(width: widgetWidth(widget, unitWidth: unitWidth))
                                    .frame(maxHeight: .infinity)
                                    .id(widget)

                                if widget != widgets.last {
                                    Divider().overlay(.white.opacity(0.1))
                                }
                            }
                        }
                        .frame(minWidth: geometry.size.width, maxHeight: .infinity, alignment: .leading)
                    }
                    .onChange(of: environment.appStore.activeWidget) { _, widget in
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            proxy.scrollTo(widget, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func widgetWidth(_ widget: WidgetType, unitWidth: CGFloat) -> CGFloat {
        let configuredWidth = unitWidth * CGFloat(environment.settings.cellSpan(for: widget))
        return widget == .calendar ? max(260, configuredWidth) : configuredWidth
    }

    @ViewBuilder
    private func widgetCell(_ widget: WidgetType) -> some View {
        Group {
            switch widget {
            case .media:
                MediaWidgetView(store: environment.mediaStore)
            case .calendar:
                CalendarWidgetView(
                    service: environment.calendarService,
                    settings: environment.settings,
                    onDateStripHover: { environment.appStore.isPointerOverCalendarDates = $0 }
                )
            case .shortcuts:
                ShortcutsWidgetView(
                    service: environment.shortcutService,
                    liveActions: environment.liveActions,
                    haptics: environment.haptics,
                    hapticsEnabled: environment.settings.enableHaptics,
                    settings: environment.settings
                )
            case .mirror:
                MirrorWidgetView(service: environment.cameraService)
            case .notes:
                NotesWidgetView(
                    store: environment.notesStore,
                    showScrollIndicator: environment.settings.showWidgetScrollIndicator
                )
            case .reminders:
                RemindersWidgetView(service: environment.reminderService, settings: environment.settings)
            case .timer:
                FocusTimerWidgetView(store: environment.focusTimerStore, settings: environment.settings)
            case .countdown:
                CountdownTimerWidgetView(store: environment.countdownTimerStore)
            case .stopwatch:
                StopwatchWidgetView(store: environment.stopwatchStore)
            case .weather:
                WeatherWidgetView(service: environment.weatherService, settings: environment.settings)
            case .school:
                SchoolWidgetView(environment: environment)
            case .network:
                NetworkWidgetView(service: environment.networkService, settings: environment.settings)
            case .market:
                MarketWidgetView(service: environment.marketService, settings: environment.settings)
            case .display:
                DisplayDashboardView(service: environment.displayService, settings: environment.settings)
            case .keepAwake:
                KeepAwakeWidgetView(service: environment.keepAwakeService, settings: environment.settings)
            case .systemMonitor:
                SystemMonitorWidgetView(service: environment.systemMonitorService)
            case .clipboard:
                ClipboardHistoryWidgetView(service: environment.clipboardService, settings: environment.settings)
            case .audioControl:
                AudioControlWidgetView(service: environment.audioControlService)
            case .batteryPower:
                BatteryPowerWidgetView(service: environment.batteryPowerService)
            case .developer:
                DeveloperWidgetView(service: environment.developerService, settings: environment.settings)
            case .quickActions:
                QuickActionsWidgetView(service: environment.quickActionService, settings: environment.settings)
            case .windowLayout:
                WindowLayoutWidgetView(service: environment.windowLayoutService)
            case .devices:
                ConnectedDevicesWidgetView(service: environment.deviceStatusService)
            }
        }
        .padding(8)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct NookIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 24)
            .background(Capsule().fill(.white.opacity(configuration.isPressed ? 0.22 : 0.1)))
            .foregroundStyle(.white.opacity(0.9))
    }
}
