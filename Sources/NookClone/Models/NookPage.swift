import Foundation

struct NookPage: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var title: String

    init(id: String = UUID().uuidString, title: String) {
        self.id = id
        self.title = title
    }

    static let nook1 = NookPage(id: "nook1", title: "Nook 1")
    static let nook2 = NookPage(id: "nook2", title: "Nook 2")
    static let nook3 = NookPage(id: "nook3", title: "Nook 3")

    var systemImage: String { "square.grid.2x2.fill" }
}

enum NookOpeningMode: String, CaseIterable, Identifiable, Sendable {
    case rememberLast
    case fixedPage
    var id: String { rawValue }
    var title: String { self == .rememberLast ? "Remember last page" : "Always open selected page" }
}
