import LicenseCore
import SwiftUI

struct LicenseSettingsView: View {
    let environment: AppEnvironment
    @State private var licenseInput = ""

    var body: some View {
        @Bindable var store = environment.licenseStore

        SettingsDetailContainer(title: "License", subtitle: "Activate Dynamic Nook Pro securely") {
            SettingsCard {
                statusView(store)
            }

            SettingsCard {
                Text("Enter license key")
                    .font(.headline)
                TextEditor(text: $licenseInput)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 90)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(.quaternary)
                    }
                Button {
                    Task {
                        await store.activate(licenseInput)
                        if store.isLicensed { licenseInput = "" }
                    }
                } label: {
                    if store.isActivating {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Activate license")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isActivating || licenseInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private func statusView(_ store: LicenseStore) -> some View {
        switch store.status {
        case .unlicensed:
            Label("No active license", systemImage: "key.slash")
                .font(.headline)
        case .invalid(let message):
            Label("License invalid", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text(LocalizedStringKey(message))
                .font(.caption)
                .foregroundStyle(.secondary)
        case .active(let payload):
            Label("License active", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
            LabeledContent("Type", value: payload.kind == .standard ? String(localized: "Standard — one Mac") : String(localized: "Master — any Mac"))
            LabeledContent("Customer", value: payload.customerReference)
            LabeledContent("Expiration") {
                if let date = payload.expirationDate {
                    Text(date.formatted(date: .long, time: .shortened))
                } else {
                    Text("Permanent")
                }
            }
            Button("Deactivate license", role: .destructive) { store.deactivate() }
        }

        if let error = store.errorMessage, case .invalid = store.status {
            Text(LocalizedStringKey(error))
                .font(.caption)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }

}
