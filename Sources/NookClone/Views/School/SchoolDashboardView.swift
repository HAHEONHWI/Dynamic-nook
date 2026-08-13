import SwiftUI

struct SchoolDashboardView: View {
    let environment: AppEnvironment

    var body: some View {
        Group {
            if environment.settings.neisSchoolCode.isEmpty {
                ContentUnavailableView {
                    Label("School Not Configured", systemImage: "graduationcap")
                        .foregroundStyle(.white)
                } description: {
                    Text("Search and select your school in Settings.")
                        .foregroundStyle(.white.opacity(0.5))
                } actions: {
                    Button("Open Settings") { environment.openSettings() }
                }
            } else {
                schoolContent
            }
        }
        .task(id: refreshKey) {
            await environment.schoolService.refresh(
                apiKey: environment.settings.neisAPIKey,
                educationOfficeCode: environment.settings.neisEducationOfficeCode,
                schoolCode: environment.settings.neisSchoolCode
            )
        }
    }

    private var schoolContent: some View {
        HStack(spacing: 10) {
            mealCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().overlay(.white.opacity(0.08))
            scheduleCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var mealCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Today's Meal", systemImage: "fork.knife")
                    .font(.headline)
            }
            Text(environment.settings.neisSchoolName)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.42))

            ForEach(Array(environment.schoolService.upcomingMeals().enumerated()), id: \.offset) { _, slot in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(LocalizedStringKey(slot.period.title)).font(.caption2.weight(.bold)).foregroundStyle(.blue)
                        if !Calendar.current.isDateInToday(slot.date) { Text("Tomorrow").font(.system(size: 9)).foregroundStyle(.secondary) }
                    }
                    Text(slot.meal?.dishes.joined(separator: "  ·  ") ?? String(localized: "No meal information"))
                        .font(.caption.weight(.medium)).lineLimit(2)
                }
            }
        }
        .padding(10)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("School Schedule", systemImage: "calendar.badge.clock")
                .font(.headline)
            if environment.schoolService.schedules.isEmpty {
                Spacer()
                Label("No upcoming school events", systemImage: "calendar.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.46))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(environment.schoolService.schedules) { item in
                            HStack(spacing: 8) {
                                Text(item.date, format: .dateTime.month().day())
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.blue)
                                    .frame(width: 38)
                                Text(item.title).font(.caption.weight(.semibold)).lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 30)
                            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(10)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var refreshKey: String {
        "\(environment.settings.neisEducationOfficeCode)-\(environment.settings.neisSchoolCode)-\(Calendar.current.startOfDay(for: Date()).timeIntervalSinceReferenceDate)"
    }

}
