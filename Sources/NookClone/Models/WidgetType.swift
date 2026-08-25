enum WidgetType: String, CaseIterable, Codable, Identifiable, Sendable {
    case media
    case calendar
    case shortcuts
    case mirror
    case notes
    case reminders
    case timer
    case countdown
    case stopwatch
    case weather
    case school
    case timetable
    case network
    case market
    case display
    case keepAwake
    case systemMonitor
    case clipboard
    case audioControl
    case batteryPower
    case developer
    case quickActions
    case windowLayout
    case devices

    var id: String { rawValue }

    var title: String {
        switch self {
        case .media: "Media Player"
        case .calendar: "Calendar"
        case .shortcuts: "Shortcuts"
        case .mirror: "Mirror"
        case .notes: "Notes"
        case .reminders: "Reminders"
        case .timer: "Focus Timer"
        case .countdown: "Timer"
        case .stopwatch: "Stopwatch"
        case .weather: "Weather"
        case .school: "School"
        case .timetable: "Timetable"
        case .network: "Network"
        case .market: "Markets"
        case .display: "Display Control"
        case .keepAwake: "Keep Awake"
        case .systemMonitor: "System Monitor"
        case .clipboard: "Clipboard History"
        case .audioControl: "Audio Control"
        case .batteryPower: "Battery & Power"
        case .developer: "Developer"
        case .quickActions: "Quick Actions"
        case .windowLayout: "Window Layout"
        case .devices: "Connected Devices"
        }
    }

    var systemImage: String {
        switch self {
        case .media: "music.note"
        case .calendar: "calendar"
        case .shortcuts: "square.grid.2x2"
        case .mirror: "camera"
        case .notes: "note.text"
        case .reminders: "checklist"
        case .timer: "timer"
        case .countdown: "hourglass"
        case .stopwatch: "stopwatch"
        case .weather: "cloud.sun.fill"
        case .school: "graduationcap.fill"
        case .timetable: "calendar.day.timeline.left"
        case .network: "wifi"
        case .market: "chart.line.uptrend.xyaxis"
        case .display: "display.2"
        case .keepAwake: "cup.and.saucer.fill"
        case .systemMonitor: "gauge.with.dots.needle.67percent"
        case .clipboard: "clipboard"
        case .audioControl: "speaker.wave.2.fill"
        case .batteryPower: "battery.75percent"
        case .developer: "terminal.fill"
        case .quickActions: "bolt.circle.fill"
        case .windowLayout: "rectangle.split.2x1"
        case .devices: "externaldrive.connected.to.line.below"
        }
    }

    var defaultCellSpan: Int {
        switch self {
        case .calendar, .media, .notes, .reminders, .weather, .school, .timetable, .network, .market, .display,
             .clipboard, .audioControl, .developer, .quickActions, .devices: 3
        case .shortcuts, .mirror, .timer, .countdown, .stopwatch, .keepAwake, .systemMonitor,
             .batteryPower, .windowLayout: 2
        }
    }
}
