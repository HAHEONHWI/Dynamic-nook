import SwiftUI

struct RemindersWidgetView: View {
    let service: ReminderService
    let settings: SettingsStore
    @State private var newTitle = ""

    var body: some View {
        Group {
            switch service.permissionState {
            case .fullAccess: content
            case .notDetermined: permissionState("Reminders Access Required", button: "Grant Permission") {
                Task { await service.requestAccessAndRefresh(maximum: settings.maximumReminders, selectedListIdentifiers: settings.selectedReminderListIdentifiers) }
            }
            case .denied, .restricted: permissionState("Reminders Access Denied", button: "Open System Settings") {
                service.openSystemSettings()
            }
            }
        }
        .task(id: refreshKey) {
            if service.permissionState == .fullAccess {
                await service.refresh(maximum: settings.maximumReminders, selectedListIdentifiers: settings.selectedReminderListIdentifiers)
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Today & Overdue", systemImage: "checklist")
                    .font(.caption.weight(.bold))
                Spacer()
                if service.isLoading { ProgressView().controlSize(.mini) }
            }
            HStack(spacing: 5) {
                TextField("Add a reminder…", text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .frame(height: 27)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .onSubmit { add() }
                Button(action: add) { Image(systemName: "plus").frame(width: 24, height: 24) }
                    .buttonStyle(.plain)
                    .background(.blue, in: Circle())
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if service.reminders.isEmpty, !service.isLoading {
                Spacer(minLength: 0)
                Label("No reminders due", systemImage: "checkmark.circle")
                    .font(.caption2).foregroundStyle(.white.opacity(0.46)).frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(service.reminders) { item in
                            HStack(spacing: 7) {
                                Button {
                                    Task { await service.complete(item, maximum: settings.maximumReminders, selectedListIdentifiers: settings.selectedReminderListIdentifiers) }
                                } label: { Image(systemName: "circle").foregroundStyle(item.isOverdue ? .red : .blue) }
                                .buttonStyle(.plain)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title).font(.caption.weight(.semibold)).lineLimit(1)
                                    if item.isOverdue {
                                        Text("Overdue").font(.system(size: 9)).foregroundStyle(.red).lineLimit(1)
                                    } else {
                                        Text(item.listTitle).font(.system(size: 9)).foregroundStyle(.white.opacity(0.42)).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 7).frame(height: 31)
                            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }.scrollIndicators(settings.showWidgetScrollIndicator ? .visible : .hidden)
            }
            if let error = service.errorMessage { Text(LocalizedStringKey(error)).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(1) }
        }
    }

    private func add() {
        let title = newTitle
        newTitle = ""
        Task { _ = await service.addToday(title: title, maximum: settings.maximumReminders, selectedListIdentifiers: settings.selectedReminderListIdentifiers) }
    }

    private var refreshKey: String { "\(settings.maximumReminders)-\(settings.selectedReminderListIdentifiers.joined(separator: ","))" }

    private func permissionState(_ title: LocalizedStringKey, button: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        ContentUnavailableView { Label(title, systemImage: "checklist") } actions: { Button(button, action: action) }
    }
}
