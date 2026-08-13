import SwiftUI

struct SchoolSettingsView: View {
    let environment: AppEnvironment
    @State private var schoolQuery = ""

    var body: some View {
        @Bindable var settings = environment.settings

        SettingsDetailContainer(title: "School", subtitle: "NEIS meals and academic schedule") {
            SettingsCard {
                SecureField("NEIS API key (optional)", text: $settings.neisAPIKey)
                Text("The API key is stored in macOS Keychain, not in source code or UserDefaults.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link("Get a NEIS API key", destination: URL(string: "https://open.neis.go.kr/portal/guide/actKeyPage.do")!)
                    .font(.caption)
            }

            SettingsCard {
                HStack {
                    TextField("School name", text: $schoolQuery)
                        .onSubmit { search() }
                    Button("Search") { search() }
                        .disabled(schoolQuery.trimmingCharacters(in: .whitespaces).count < 2)
                }
                if environment.schoolService.isLoading { ProgressView().controlSize(.small) }
                ForEach(environment.schoolService.searchResults.prefix(12)) { school in
                    Button {
                        settings.neisEducationOfficeCode = school.educationOfficeCode
                        settings.neisSchoolCode = school.schoolCode
                        settings.neisSchoolName = school.name
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(school.name)
                                Text(school.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if settings.neisSchoolCode == school.schoolCode {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }

            if !settings.neisSchoolName.isEmpty {
                SettingsCard {
                    LabeledContent("Selected school", value: settings.neisSchoolName)
                    LabeledContent("Education office code", value: settings.neisEducationOfficeCode)
                    LabeledContent("School code", value: settings.neisSchoolCode)
                }
            }

            if let error = environment.schoolService.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func search() {
        Task {
            await environment.schoolService.searchSchools(
                name: schoolQuery,
                apiKey: environment.settings.neisAPIKey
            )
        }
    }
}
