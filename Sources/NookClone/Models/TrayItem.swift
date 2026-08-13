import Foundation

struct TrayItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let originalURL: URL
    let displayName: String
    let byteCount: Int64?

    init(id: UUID = UUID(), url: URL, originalURL: URL? = nil) {
        self.id = id
        self.url = url.standardizedFileURL
        self.originalURL = (originalURL ?? url).standardizedFileURL
        self.displayName = url.safeDisplayName
        self.byteCount = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init)
    }

    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    var sizeText: String {
        guard let byteCount else { return "Unknown size" }
        return ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}
