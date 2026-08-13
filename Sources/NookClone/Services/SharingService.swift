import AppKit
import Foundation

@MainActor
final class SharingService {
    var canAirDrop: Bool {
        NSSharingService(named: .sendViaAirDrop) != nil
    }

    func shareViaAirDrop(urls: [URL]) {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        service.perform(withItems: urls)
    }

    func share(urls: [URL]) {
        guard !urls.isEmpty else { return }
        let picker = NSSharingServicePicker(items: urls)
        guard let window = NSApp.keyWindow ?? NSApp.windows.first, let view = window.contentView else { return }
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
}
