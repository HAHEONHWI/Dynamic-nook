import SwiftUI

struct ClipboardHistoryWidgetView: View {
    let service: ClipboardHistoryService
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Clipboard History", systemImage: "clipboard").font(.caption.weight(.bold))
                Spacer()
                Button { service.clear() } label: { Image(systemName: "trash") }.buttonStyle(.plain)
            }
            if !settings.clipboardHistoryEnabled {
                Spacer(); Text("Clipboard history is off").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity); Spacer()
            } else if service.items.isEmpty {
                Spacer(); Label("Copy something to see it here", systemImage: "doc.on.clipboard").font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity); Spacer()
            } else {
                ForEach(service.items.prefix(3)) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.kind == .image ? "photo" : item.kind == .url ? "link" : "text.alignleft")
                        Text(item.preview).font(.caption2).lineLimit(1)
                        Spacer()
                        Button { service.togglePin(item) } label: { Image(systemName: item.isPinned ? "pin.fill" : "pin") }.buttonStyle(.plain)
                        Button { service.copy(item) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 7).frame(height: 27).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .onAppear { service.isEnabled = settings.clipboardHistoryEnabled; service.poll() }
        .onChange(of: settings.clipboardHistoryEnabled) { _, enabled in service.isEnabled = enabled }
    }
}
