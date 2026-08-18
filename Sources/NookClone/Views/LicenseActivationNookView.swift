import SwiftUI

struct LicenseActivationNookView: View {
    let environment: AppEnvironment
    @State private var licenseInput = ""

    var body: some View {
        @Bindable var store = environment.licenseStore

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "key.horizontal.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enter your license key")
                        .font(.title2.bold())
                    Text("Dynamic Nook Pro activation required")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("License key")
                    .font(.subheadline.weight(.semibold))
                TextEditor(text: $licenseInput)
                    .font(.system(.caption, design: .monospaced))
                    .focusEffectDisabled()
                    .frame(minHeight: 62)
                    .scrollContentBackground(.hidden)
                    .padding(5)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                Button {
                    Task {
                        await store.activate(licenseInput)
                        if store.isLicensed { licenseInput = "" }
                    }
                } label: {
                    if store.isActivating {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Activate Dynamic Nook Pro")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isActivating || licenseInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .frame(maxWidth: 680, alignment: .leading)

            if let error = store.errorMessage {
                Label {
                    Text(LocalizedStringKey(error))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

}
