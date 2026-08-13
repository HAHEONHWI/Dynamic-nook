import SwiftUI

struct SchoolWidgetView: View {
    let environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("School", systemImage: "graduationcap.fill").font(.caption.weight(.bold))
                Spacer()
            }
            if environment.settings.neisSchoolCode.isEmpty {
                Spacer()
                Label("School Not Configured", systemImage: "graduationcap").font(.caption).foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity)
                Button("Open Settings") { environment.openSettings() }.buttonStyle(.plain).font(.caption2).frame(maxWidth: .infinity)
                Spacer()
            } else {
                Text(environment.settings.neisSchoolName).font(.caption2).foregroundStyle(.white.opacity(0.48)).lineLimit(1)
                ForEach(Array(environment.schoolService.upcomingMeals().enumerated()), id: \.offset) { _, slot in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey(slot.period.title)).font(.caption2.weight(.bold)).foregroundStyle(.blue)
                            if !Calendar.current.isDateInToday(slot.date) {
                                Text("Tomorrow").font(.system(size: 8)).foregroundStyle(.white.opacity(0.42))
                            }
                        }
                        Text(slot.meal?.dishes.joined(separator: " · ") ?? String(localized: "No meal information"))
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(slot.meal == nil ? .white.opacity(0.4) : .white).lineLimit(2)
                    }
                }
            }
        }
        .task(id: environment.settings.neisSchoolCode) {
            await environment.schoolService.refresh(apiKey: environment.settings.neisAPIKey, educationOfficeCode: environment.settings.neisEducationOfficeCode, schoolCode: environment.settings.neisSchoolCode)
        }
    }
}
