import AppKit
import SwiftUI

@MainActor
final class NookDropHostingView<Content: View>: NSHostingView<Content> {
    var onFileDrag: ((CGPoint?) -> NSDragOperation)?
    var onFileDrop: (([URL], CGPoint) -> Bool)?

    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("NookDropHostingView does not support NSCoder initialization")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard containsFileURLs(sender) else { return [] }
        return onFileDrag?(sender.draggingLocation) ?? .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard containsFileURLs(sender) else { return [] }
        return onFileDrag?(sender.draggingLocation) ?? .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        _ = onFileDrag?(nil)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !fileURLs(from: sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        return onFileDrop?(urls, sender.draggingLocation) ?? false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        _ = onFileDrag?(nil)
    }

    private func containsFileURLs(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }

    private func fileURLs(from sender: NSDraggingInfo) -> [URL] {
        let objects = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) ?? []
        return objects.compactMap { object in
            guard let url = object as? NSURL else { return nil }
            return url as URL
        }
    }
}
