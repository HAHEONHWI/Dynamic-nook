import AppKit
import QuickLookUI

@MainActor
final class PreviewService: NSObject, @preconcurrency QLPreviewPanelDataSource {
    private var previewURL: URL?

    func preview(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path), let panel = QLPreviewPanel.shared() else { return }
        previewURL = url
        panel.dataSource = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> any QLPreviewItem {
        (previewURL ?? URL(fileURLWithPath: "/")) as NSURL
    }
}
