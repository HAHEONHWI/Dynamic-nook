import Foundation

enum NoteAccent: String, CaseIterable, Codable, Identifiable, Sendable {
    case blue
    case cyan
    case orange
    case pink

    var id: String { rawValue }
}

struct NoteItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var text: String
    var accent: NoteAccent
    var isBold: Bool
    var isItalic: Bool
    var isUnderlined: Bool
    var isCodeMode: Bool

    init(
        id: UUID = UUID(),
        text: String = "",
        accent: NoteAccent = .blue,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderlined: Bool = false,
        isCodeMode: Bool = false
    ) {
        self.id = id
        self.text = text
        self.accent = accent
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.isCodeMode = isCodeMode
    }
}
