import LicenseCore
import SwiftUI

struct IssuerView: View {
    @Bindable var store: IssuerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dynamic Nook License Issuer")
                        .font(.title.bold())
                    Text("Private administrator tool. Never distribute this app or its Keychain data.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("License") {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("License server URL", text: $store.serverURL)
                        SecureField("Administrator token", text: $store.adminToken)

                        Picker("License type", selection: $store.kind) {
                            Text("Standard — one Mac").tag(LicenseKind.standard)
                            Text("Master — any Mac").tag(LicenseKind.master)
                        }
                        .pickerStyle(.segmented)

                        LabeledContent("Plan", value: "Dynamic Nook Pro")

                        TextField("Customer or order reference", text: $store.customerReference)

                        Text("Standard keys activate one Mac. Master keys can activate any Mac.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(8)
                }

                GroupBox("Expiration") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Set expiration date", isOn: $store.hasExpiration)
                        if store.hasExpiration {
                            DatePicker(
                                "Expiration date",
                                selection: $store.expirationDate,
                                in: Calendar.current.startOfDay(for: Date())...,
                                displayedComponents: .date
                            )
                        }
                        LabeledContent("Result") {
                            Text(store.expirationSummary).fontWeight(.semibold)
                        }
                        Text("The license remains valid through 11:59:59 PM on the selected local date.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }

                Button {
                    Task { await store.generate() }
                } label: {
                    if store.isGenerating {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Generate license")
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.isGenerating)

                if let errorMessage = store.errorMessage {
                    Label {
                        Text(LocalizedStringKey(errorMessage))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                if !store.generatedLicense.isEmpty {
                    GroupBox("Generated license") {
                        VStack(alignment: .trailing, spacing: 8) {
                            TextEditor(text: .constant(store.generatedLicense))
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 105)
                            Button("Copy license") { store.copyLicense() }
                            LabeledContent("Server ID", value: store.generatedLicenseID)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }
                }

                GroupBox("Issuer public key") {
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(store.issuerPublicKey)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Copy public key") { store.copyPublicKey() }
                    }
                    .padding(8)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 680, minHeight: 650)
    }
}
