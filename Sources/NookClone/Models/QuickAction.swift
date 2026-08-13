import Foundation

struct QuickAction: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var target: String

    init(id: UUID = UUID(), title: String, target: String) {
        self.id = id
        self.title = title
        self.target = target
    }
}

enum QuickActionTarget: Equatable, Sendable {
    case url(URL)
    case file(URL)
    case shell(String)

    static func parse(_ value: String) -> Self? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("shell:") {
            let command = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            return command.isEmpty ? nil : .shell(command)
        }
        if let url = URL(string: trimmed), let scheme = url.scheme, ["http", "https", "mailto"].contains(scheme.lowercased()) {
            return .url(url)
        }
        let expanded = NSString(string: trimmed).expandingTildeInPath
        return .file(URL(fileURLWithPath: expanded))
    }
}
