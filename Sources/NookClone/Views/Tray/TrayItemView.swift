import AppKit
import SwiftUI

struct TrayItemView: View {
    let item: TrayItem
    let environment: AppEnvironment

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if environment.settings.showThumbnails {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "doc.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.blue)
                    }
                }
                .frame(width: 52, height: 52)
                .opacity(item.exists ? 1 : 0.35)
                Button {
                    environment.trayStore.remove(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(item.displayName)")
                .offset(x: 7, y: -7)
            }
            Text(item.displayName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(item.exists ? item.sizeText : environment.settings.localized("Missing"))
                .font(.caption2)
                .foregroundStyle(item.exists ? .white.opacity(0.45) : .red.opacity(0.85))
        }
        .frame(width: 92)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(count: 2) { open() }
        .draggable(item.url)
        .contextMenu {
            Button("Open", action: open).disabled(!item.exists)
            Button("Quick Look") { environment.previewService.preview(item.url) }.disabled(!item.exists)
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }.disabled(!item.exists)
            Divider()
            Button("Share") { environment.sharingService.share(urls: [item.url]) }.disabled(!item.exists)
            Button("AirDrop") { environment.sharingService.shareViaAirDrop(urls: [item.url]) }
                .disabled(!item.exists || !environment.settings.enableAirDrop || !environment.sharingService.canAirDrop)
            Divider()
                Button("Restore to Original Location") { environment.trayStore.remove(item) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName), \(item.sizeText)")
    }

    private func open() {
        guard item.exists else { return }
        NSWorkspace.shared.open(item.url)
    }
}
