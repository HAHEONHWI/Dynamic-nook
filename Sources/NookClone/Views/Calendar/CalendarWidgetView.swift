import AppKit
import SwiftUI

struct CalendarWidgetView: View {
    let service: CalendarService
    let settings: SettingsStore
    let onDateStripHover: (Bool) -> Void
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var centeredDate: Date? = Calendar.current.startOfDay(for: Date())

    var body: some View {
        Group {
            switch service.permissionState {
            case .fullAccess:
                calendarContent
            case .notDetermined:
                permissionView(title: "Calendar Access Required", button: "Grant Permission") {
                    Task { await requestAndRefresh() }
                }
            case .denied, .restricted:
                permissionView(title: "Calendar Access Denied", button: "Open System Settings") {
                    service.openSystemSettings()
                }
            }
        }
        .task(id: refreshKey) {
            service.refreshPermission()
            if service.permissionState == .fullAccess { refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            service.refreshPermission()
            if service.permissionState == .fullAccess { refresh() }
        }
    }

    private var calendarContent: some View {
        HStack(spacing: 10) {
            dateWheel
                .frame(width: 88)

            Divider()
                .overlay(.white.opacity(0.045))

            selectedDaySchedule
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var dateWheel: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(selectedDate, format: .dateTime.month(.abbreviated))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(selectedDate, format: .dateTime.year())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.38))
                Spacer(minLength: 0)
            }

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(days, id: \.self) { date in
                        dayWheelRow(date)
                            .id(date)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.vertical, 32, for: .scrollContent)
            .scrollPosition(id: $centeredDate, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.22),
                        .init(color: .white, location: 0.78),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
                    .frame(height: 30)
                    .allowsHitTesting(false)
            }
            .onHover(perform: onDateStripHover)
            .onDisappear { onDateStripHover(false) }
            .onChange(of: centeredDate) { _, date in
                guard let date else { return }
                select(date)
            }
        }
    }

    private func dayWheelRow(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let distance = dayDistance(from: selectedDate, to: date)
        let magnitude = min(abs(distance), 3)

        return Button {
            withAnimation(.snappy(duration: 0.28)) {
                centeredDate = Calendar.current.startOfDay(for: date)
                select(date)
            }
        } label: {
            HStack(spacing: 5) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : (isToday ? .blue : .white.opacity(0.72)))
                    .frame(width: 28, alignment: .trailing)
                Text(date, format: .dateTime.weekday(.narrow))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(isSelected ? 0.78 : 0.36))
                Spacer(minLength: 0)
                if isToday {
                    Circle()
                        .fill(.blue)
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                isSelected ? Color.white.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1 : max(0.74, 1 - (Double(magnitude) * 0.11)))
        .opacity(isSelected ? 1 : max(0.18, 0.7 - (Double(magnitude) * 0.17)))
        .rotation3DEffect(
            .degrees(Double(distance) * -18),
            axis: (x: 1, y: 0, z: 0),
            anchor: distance < 0 ? .bottom : .top,
            perspective: 0.55
        )
        .animation(.smooth(duration: 0.24), value: selectedDate)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedDaySchedule: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(service.isShowingNearestUpcomingEvents ? "Next event" : selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Text(service.displayedEventDate ?? selectedDate, format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if Calendar.current.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }

            Divider().overlay(.white.opacity(0.04))

            if service.events.isEmpty {
                Spacer(minLength: 0)
                Label("Nothing scheduled", systemImage: "calendar.badge.checkmark")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.46))
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(service.events) { event in
                            eventRow(event)
                        }
                    }
                }
                .scrollIndicators(settings.showWidgetScrollIndicator ? .visible : .hidden)
            }
        }
        .animation(.easeOut(duration: 0.18), value: selectedDate)
    }

    private func eventRow(_ event: CalendarEventItem) -> some View {
        HStack(spacing: 7) {
            Capsule()
                .fill(Color(hex: event.colorHex))
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if event.isAllDay {
                    Text("All day")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    Text("\(event.startDate.formatted(date: .omitted, time: .shortened))–\(event.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Spacer(minLength: 2)
            if !event.isAllDay, event.startDate > Date() {
                Text(event.startDate, style: .relative)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.36))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 34)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-30...90).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    private var refreshKey: String {
        "\(selectedDate.timeIntervalSinceReferenceDate)-\(settings.maximumCalendarEvents)-\(settings.selectedCalendarIdentifiers.joined(separator: ","))"
    }

    private func select(_ date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        guard !Calendar.current.isDate(normalized, inSameDayAs: selectedDate) else { return }
        selectedDate = normalized
    }

    private func dayDistance(from selectedDate: Date, to date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: selectedDate, to: date).day ?? 0
    }

    private func refresh() {
        service.refresh(
            day: selectedDate,
            maximum: settings.maximumCalendarEvents,
            selectedCalendarIdentifiers: settings.selectedCalendarIdentifiers
        )
    }

    private func requestAndRefresh() async {
        await service.requestAccessAndRefresh(
            day: selectedDate,
            maximum: settings.maximumCalendarEvents,
            selectedCalendarIdentifiers: settings.selectedCalendarIdentifiers
        )
    }

    private func permissionView(
        title: LocalizedStringKey,
        button: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: "calendar.badge.exclamationmark")
            }
            .foregroundStyle(.white)
        } description: {
            Text("Calendar access only affects this widget.")
                .foregroundStyle(.white.opacity(0.58))
        } actions: {
            Button(action: action) { Text(button) }.buttonStyle(.bordered)
        }
    }
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(clean, radix: 16) ?? 0x6E8BFF
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
