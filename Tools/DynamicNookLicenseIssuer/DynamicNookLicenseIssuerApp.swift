import SwiftUI

@main
struct DynamicNookLicenseIssuerApp: App {
    @State private var store = IssuerStore()

    var body: some Scene {
        WindowGroup("Dynamic Nook License Issuer") {
            IssuerView(store: store)
        }
        .defaultSize(width: 760, height: 760)
    }
}
