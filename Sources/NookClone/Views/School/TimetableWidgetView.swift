import SwiftUI

struct TimetableWidgetView: View {
    let environment: AppEnvironment
    @State private var selectedWeekday = SchoolWeekday.current()?.rawValue ?? SchoolWeekday.monday.rawValue

    var body: some View {
        GeometryReader { geometry in
            timetableContent(compact: Self.usesCompactLayout(availableWidth: geometry.size.width))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
        .task(id: timetableKey) {
            await refresh()
        }
    }

    @ViewBuilder
    private func timetableContent(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if compact {
                    Image(systemName: "calendar.day.timeline.left")
                        .font(.caption.weight(.bold))
                        .accessibilityLabel("Class Timetable")
                } else {
                    Label("Class Timetable", systemImage: "calendar.day.timeline.left")
                        .font(.caption.weight(.bold))
                }
                Spacer()
                Text("\(environment.settings.schoolGrade)-\(environment.settings.schoolClassNumber)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.blue)
            }
            if compact {
                Picker("Weekday", selection: $selectedWeekday) {
                    weekdayOptions
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            } else {
                Picker("Weekday", selection: $selectedWeekday) {
                    weekdayOptions
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            if environment.schoolTimetableService.isLoading, environment.schoolTimetableService.days.isEmpty {
                Spacer()
                ProgressView().controlSize(.small).frame(maxWidth: .infinity)
                Spacer()
            } else if environment.schoolTimetableService.errorMessage != nil {
                Spacer()
                Label("Could not load timetable", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                Button("Retry") {
                    Task { await refresh() }
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .frame(maxWidth: .infinity)
                Spacer()
            } else if let day = environment.schoolTimetableService.timetable(for: selectedWeekday),
                      !day.periods.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(day.periods) { period in
                            HStack(spacing: 6) {
                                Text("\(period.period)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(period.isChanged ? Color.orange : Color.blue)
                                    .frame(width: 13)
                                Text(period.subject)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(period.isChanged ? Color.orange : Color.white)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                if period.isChanged {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(.orange)
                                        .accessibilityLabel("Changed class")
                                }
                                if let teacher = period.teacher {
                                    Text(teacher)
                                        .font(.system(size: 8))
                                        .foregroundStyle(period.isChanged ? Color.orange.opacity(0.7) : Color.white.opacity(0.42))
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                Spacer()
                Label("No classes", systemImage: "calendar.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var weekdayOptions: some View {
        ForEach(SchoolWeekday.allCases, id: \.rawValue) { weekday in
            Text(LocalizedStringKey(weekday.shortTitle)).tag(weekday.rawValue)
        }
    }

    nonisolated static func usesCompactLayout(availableWidth: CGFloat) -> Bool {
        availableWidth < 120
    }

    private var timetableKey: String {
        "\(environment.settings.schoolGrade)-\(environment.settings.schoolClassNumber)"
    }

    private func refresh() async {
        await environment.schoolTimetableService.refresh(
            grade: environment.settings.schoolGrade,
            classNumber: environment.settings.schoolClassNumber
        )
    }
}
