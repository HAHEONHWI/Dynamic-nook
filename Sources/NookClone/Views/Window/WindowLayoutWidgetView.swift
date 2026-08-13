import SwiftUI

struct WindowLayoutWidgetView: View {
    let service: WindowLayoutService
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Window Layout", systemImage: "rectangle.split.2x1").font(.caption.weight(.bold))
            if service.isAccessibilityTrusted {
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 7) {
                    ForEach(WindowPlacement.allCases) { placement in
                        Button { service.arrange(placement) } label: { Label(LocalizedStringKey(placement.title), systemImage: placement.image).font(.caption2).frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    }
                }
            } else {
                Text("Accessibility permission is required.").font(.caption2).foregroundStyle(.secondary)
                Button("Grant Permission") { service.requestPermission() }.buttonStyle(.borderedProminent).controlSize(.small)
            }
            if let error = service.errorMessage { Text(LocalizedStringKey(error)).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(1) }
        }.onAppear { service.refreshPermission() }
    }
}
