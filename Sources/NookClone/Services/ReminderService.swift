import AppKit
import EventKit
import Observation

enum ReminderPermissionState: Sendable {
    case notDetermined
    case denied
    case restricted
    case fullAccess
}

@MainActor
@Observable
final class ReminderService {
    private let eventStore = EKEventStore()
    private(set) var permissionState: ReminderPermissionState = .notDetermined
    private(set) var reminders: [ReminderItem] = []
    private(set) var availableLists: [ReminderListItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init() {
        updatePermissionState()
        if permissionState == .fullAccess { refreshLists() }
    }

    func refreshPermission() { updatePermissionState() }

    func requestAccessAndRefresh(maximum: Int, selectedListIdentifiers: [String]) async {
        do {
            if EKEventStore.authorizationStatus(for: .reminder) == .notDetermined {
                _ = try await eventStore.requestFullAccessToReminders()
            }
            updatePermissionState()
            if permissionState == .fullAccess {
                await refresh(maximum: maximum, selectedListIdentifiers: selectedListIdentifiers)
            }
        } catch {
            errorMessage = error.localizedDescription
            updatePermissionState()
        }
    }

    func refresh(maximum: Int, selectedListIdentifiers: [String]) async {
        updatePermissionState()
        guard permissionState == .fullAccess else {
            reminders = []
            availableLists = []
            return
        }
        refreshLists()
        isLoading = true
        defer { isLoading = false }
        let calendars = selectedCalendars(selectedListIdentifiers)
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: ReminderDateLogic.displayWindow(now: Date()).end,
            calendars: calendars
        )
        let fetched: [ReminderItem] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { fetched in
                continuation.resume(returning: (fetched ?? []).compactMap(Self.makeItem))
            }
        }
        reminders = ReminderDateLogic.sort(fetched).prefix(maximum).map { $0 }
        errorMessage = nil
    }

    func addToday(title: String, maximum: Int, selectedListIdentifiers: [String]) async -> Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, permissionState == .fullAccess else { return false }
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = clean
        reminder.calendar = selectedCalendars(selectedListIdentifiers)?.first
            ?? eventStore.defaultCalendarForNewReminders()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 23
        components.minute = 59
        reminder.dueDateComponents = components
        do {
            try eventStore.save(reminder, commit: true)
            await refresh(maximum: maximum, selectedListIdentifiers: selectedListIdentifiers)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func complete(_ item: ReminderItem, maximum: Int, selectedListIdentifiers: [String]) async {
        guard let reminder = eventStore.calendarItem(withIdentifier: item.id) as? EKReminder else {
            await refresh(maximum: maximum, selectedListIdentifiers: selectedListIdentifiers)
            return
        }
        reminder.isCompleted = true
        reminder.completionDate = Date()
        do {
            try eventStore.save(reminder, commit: true)
            await refresh(maximum: maximum, selectedListIdentifiers: selectedListIdentifiers)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshLists() {
        availableLists = eventStore.calendars(for: .reminder).map {
            ReminderListItem(id: $0.calendarIdentifier, title: $0.title, colorHex: Self.hexColor($0.cgColor))
        }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func selectedCalendars(_ identifiers: [String]) -> [EKCalendar]? {
        let selected = Set(identifiers)
        return selected.isEmpty ? nil : eventStore.calendars(for: .reminder).filter { selected.contains($0.calendarIdentifier) }
    }

    private func updatePermissionState() {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined: permissionState = .notDetermined
        case .denied, .writeOnly: permissionState = .denied
        case .restricted: permissionState = .restricted
        case .fullAccess, .authorized: permissionState = .fullAccess
        @unknown default: permissionState = .denied
        }
    }

    nonisolated private static func makeItem(_ reminder: EKReminder) -> ReminderItem? {
        guard let dueComponents = reminder.dueDateComponents,
              let dueDate = Calendar.current.date(from: dueComponents) else { return nil }
        return ReminderItem(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "Untitled Reminder",
            dueDate: dueDate,
            listTitle: reminder.calendar.title,
            isOverdue: dueDate < Calendar.current.startOfDay(for: Date())
        )
    }

    private static func hexColor(_ color: CGColor) -> String {
        guard let values = color.components, values.count >= 3 else { return "#6E8BFF" }
        return String(format: "#%02X%02X%02X", Int(values[0] * 255), Int(values[1] * 255), Int(values[2] * 255))
    }
}
