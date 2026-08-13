import AppKit
import CryptoKit
import Observation

struct ClipboardHistoryItem: Identifiable, Equatable, Sendable {
    enum Kind: Sendable { case text, url, image }
    let id: String
    let kind: Kind
    let preview: String
    let data: Data?
    let createdAt: Date
    var isPinned: Bool
}

@MainActor
@Observable
final class ClipboardHistoryService {
    private(set) var items: [ClipboardHistoryItem] = []
    private var lastChangeCount = NSPasteboard.general.changeCount
    @ObservationIgnored private var monitor: Task<Void, Never>?
    var isEnabled = true

    init(startMonitoring: Bool = true) {
        if startMonitoring {
            monitor = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(750))
                    self?.poll()
                }
            }
        }
    }

    deinit { monitor?.cancel() }

    func poll() {
        guard isEnabled else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !looksSensitive(trimmed) else { return }
            insert(kind: URL(string: trimmed)?.scheme != nil ? .url : .text, preview: trimmed, data: nil)
        } else if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            insert(kind: .image, preview: String(localized: "Image"), data: data)
        }
    }

    func copy(_ item: ClipboardHistoryItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if item.kind == .image, let data = item.data, let image = NSImage(data: data) { pasteboard.writeObjects([image]) }
        else { pasteboard.setString(item.preview, forType: .string) }
        lastChangeCount = pasteboard.changeCount
    }

    func togglePin(_ item: ClipboardHistoryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        items.sort { $0.isPinned != $1.isPinned ? $0.isPinned : $0.createdAt > $1.createdAt }
    }

    func clear() { items.removeAll { !$0.isPinned } }

    private func insert(kind: ClipboardHistoryItem.Kind, preview: String, data: Data?) {
        let digest = SHA256.hash(data: data ?? Data(preview.utf8)).map { String(format: "%02x", $0) }.joined()
        items.removeAll { $0.id == digest }
        items.insert(ClipboardHistoryItem(id: digest, kind: kind, preview: String(preview.prefix(500)), data: data, createdAt: .now, isPinned: false), at: 0)
        if items.count > 20 { items.removeLast(items.count - 20) }
    }

    private func looksSensitive(_ string: String) -> Bool {
        if string.count > 2000 { return true }
        let patterns = [#"-----BEGIN .*PRIVATE KEY-----"#, #"(?i)password\s*[:=]"#, #"(?i)token\s*[:=]"#]
        return patterns.contains { string.range(of: $0, options: .regularExpression) != nil }
    }
}
