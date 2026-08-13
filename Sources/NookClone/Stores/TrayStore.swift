import Foundation
import Observation

@MainActor
@Observable
final class TrayStore {
    private(set) var items: [TrayItem] = []
    private let trayDirectory: URL

    init(trayDirectory: URL? = nil) {
        self.trayDirectory = trayDirectory ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appending(path: "nook3h/Tray", directoryHint: .isDirectory)
    }

    @discardableResult
    func add(urls: [URL], maximum: Int) -> Int {
        let valid = urls
            .map(\.standardizedFileURL)
            .filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }

        var added = 0
        for url in valid where !items.contains(where: { $0.originalURL == url }) {
            guard items.count < maximum else { break }
            if let storedURL = moveToTray(url) {
                items.append(TrayItem(url: storedURL, originalURL: url))
                added += 1
            }
        }
        return added
    }

    func remove(_ item: TrayItem) {
        restore(item)
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        for item in items { try? FileManager.default.removeItem(at: item.url) }
        items.removeAll()
    }

    private func moveToTray(_ source: URL) -> URL? {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: trayDirectory, withIntermediateDirectories: true)
            var destination = trayDirectory.appending(path: source.lastPathComponent)
            var sequence = 2
            while fileManager.fileExists(atPath: destination.path) {
                let stem = source.deletingPathExtension().lastPathComponent
                let ext = source.pathExtension
                destination = trayDirectory.appending(path: ext.isEmpty ? "\(stem) \(sequence)" : "\(stem) \(sequence).\(ext)")
                sequence += 1
            }
            try fileManager.moveItem(at: source, to: destination)
            return destination
        } catch { return nil }
    }

    private func restore(_ item: TrayItem) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: item.url.path) else { return }
        guard !fileManager.fileExists(atPath: item.originalURL.path) else { return }
        try? fileManager.createDirectory(at: item.originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fileManager.moveItem(at: item.url, to: item.originalURL)
    }
}
