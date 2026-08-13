import Foundation

struct ShortcutItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String

    init(name: String) {
        self.id = name
        self.name = name
    }
}
