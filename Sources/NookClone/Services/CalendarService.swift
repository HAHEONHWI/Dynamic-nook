import AppKit
import EventKit
import Observation

enum CalendarPermissionState: Sendable {
    case notDetermined
    case denied
    case restricted
    case fullAccess
}

enum CalendarDateWindow {
    static func day(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }
}

@MainActor
@Observable
final class CalendarService {
    private let eventStore = EKEventStore()
    private(set) var permissionState: CalendarPermissionState = .notDetermined
    private(set) var events: [CalendarEventItem] = []
    private(set) var displayedEventDate: Date?
    private(set) var isShowingNearestUpcomingEvents = false
    private(set) var availableCalendars: [CalendarSourceItem] = []
    private(set) var errorMessage: String?

    init() {
        updatePermissionState()
        if permissionState == .fullAccess { refreshAvailableCalendars() }
    }

    func refreshPermission() { updatePermissionState() }

    func requestAccessAndRefresh(
        range: CalendarRange = .today,
        maximum: Int = 6,
        selectedCalendarIdentifiers: [String] = []
    ) async {
        do {
            if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
                _ = try await eventStore.requestFullAccessToEvents()
            }
            updatePermissionState()
            if permissionState == .fullAccess {
                refreshAvailableCalendars()
                refresh(
                    range: range,
                    maximum: maximum,
                    selectedCalendarIdentifiers: selectedCalendarIdentifiers
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            updatePermissionState()
        }
    }

    func requestAccessAndRefresh(
        day: Date,
        maximum: Int = 6,
        selectedCalendarIdentifiers: [String] = []
    ) async {
        do {
            if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
                _ = try await eventStore.requestFullAccessToEvents()
            }
            updatePermissionState()
            if permissionState == .fullAccess {
                refreshAvailableCalendars()
                refresh(
                    day: day,
                    maximum: maximum,
                    selectedCalendarIdentifiers: selectedCalendarIdentifiers
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            updatePermissionState()
        }
    }

    func refresh(
        range: CalendarRange = .today,
        maximum: Int = 6,
        selectedCalendarIdentifiers: [String] = []
    ) {
        updatePermissionState()
        guard permissionState == .fullAccess else {
            events = []
            availableCalendars = []
            return
        }
        refreshAvailableCalendars()
        let window = dateWindow(for: range)
        loadEvents(
            start: window.start,
            end: window.end,
            maximum: maximum,
            selectedCalendarIdentifiers: selectedCalendarIdentifiers
        )
    }

    private func loadEventsForSelectedDay(
        window: DateInterval,
        maximum: Int,
        selectedCalendarIdentifiers: [String]
    ) {
        let calendars = matchingCalendars(selectedCalendarIdentifiers)
        let selectedDayEvents = eventStore.events(matching: eventStore.predicateForEvents(
            withStart: window.start,
            end: window.end,
            calendars: calendars
        ))
        .sorted { $0.startDate < $1.startDate }

        if !selectedDayEvents.isEmpty {
            events = selectedDayEvents.prefix(maximum).map(Self.makeEvent)
            displayedEventDate = window.start
            isShowingNearestUpcomingEvents = false
            errorMessage = nil
            return
        }

        let searchEnd = Calendar.current.date(byAdding: .year, value: 1, to: window.end)
            ?? window.end.addingTimeInterval(31_536_000)
        let futureEvents = eventStore.events(matching: eventStore.predicateForEvents(
            withStart: window.end,
            end: searchEnd,
            calendars: calendars
        ))
        .sorted { $0.startDate < $1.startDate }

        guard let nearest = futureEvents.first else {
            events = []
            displayedEventDate = nil
            isShowingNearestUpcomingEvents = false
            errorMessage = nil
            return
        }

        let nearestDay = CalendarDateWindow.day(containing: nearest.startDate)
        events = futureEvents
            .filter { nearestDay.contains($0.startDate) }
            .prefix(maximum)
            .map(Self.makeEvent)
        displayedEventDate = nearestDay.start
        isShowingNearestUpcomingEvents = true
        errorMessage = nil
    }

    func refresh(
        day: Date,
        maximum: Int = 6,
        selectedCalendarIdentifiers: [String] = []
    ) {
        updatePermissionState()
        guard permissionState == .fullAccess else {
            events = []
            availableCalendars = []
            return
        }
        refreshAvailableCalendars()
        let window = CalendarDateWindow.day(containing: day)
        loadEventsForSelectedDay(
            window: window,
            maximum: maximum,
            selectedCalendarIdentifiers: selectedCalendarIdentifiers
        )
    }

    private func loadEvents(
        start: Date,
        end: Date,
        maximum: Int,
        selectedCalendarIdentifiers: [String]
    ) {
        let calendars = matchingCalendars(selectedCalendarIdentifiers)
        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: calendars
        )
        events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(maximum)
            .map(Self.makeEvent)
        displayedEventDate = start
        isShowingNearestUpcomingEvents = false
        errorMessage = nil
    }

    private func matchingCalendars(_ identifiers: [String]) -> [EKCalendar]? {
        let selected = Set(identifiers)
        return selected.isEmpty
            ? nil
            : eventStore.calendars(for: .event).filter { selected.contains($0.calendarIdentifier) }
    }

    private static func makeEvent(_ event: EKEvent) -> CalendarEventItem {
        CalendarEventItem(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "Untitled Event",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            colorHex: hexColor(event.calendar.cgColor)
        )
    }

    func refreshAvailableCalendars() {
        guard permissionState == .fullAccess else {
            availableCalendars = []
            return
        }
        availableCalendars = eventStore.calendars(for: .event)
            .map {
                CalendarSourceItem(
                    id: $0.calendarIdentifier,
                    title: $0.title,
                    colorHex: Self.hexColor($0.cgColor)
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    private func updatePermissionState() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            permissionState = .notDetermined
        case .denied:
            permissionState = .denied
        case .restricted:
            permissionState = .restricted
        case .fullAccess, .authorized:
            permissionState = .fullAccess
        case .writeOnly:
            permissionState = .denied
        @unknown default:
            permissionState = .denied
        }
    }

    private func dateWindow(for range: CalendarRange) -> (start: Date, end: Date) {
        let now = Date()
        switch range {
        case .today:
            let start = Calendar.current.startOfDay(for: now)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
            return (start, end)
        case .next24Hours:
            return (now, now.addingTimeInterval(86_400))
        case .threeDays:
            let start = Calendar.current.startOfDay(for: now)
            let end = Calendar.current.date(byAdding: .day, value: 3, to: start) ?? start.addingTimeInterval(259_200)
            return (start, end)
        }
    }

    private static func hexColor(_ color: CGColor) -> String {
        guard let components = color.components, components.count >= 3 else { return "#6E8BFF" }
        let red = Int(components[0] * 255)
        let green = Int(components[1] * 255)
        let blue = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
