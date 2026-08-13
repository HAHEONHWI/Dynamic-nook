import Foundation
import Observation

@MainActor
@Observable
final class NotesStore {
    static let maximumNotes = 4

    @ObservationIgnored private let defaults: UserDefaults
    private(set) var notes: [NoteItem]
    var selectedNoteID: UUID?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "notes"),
           let decoded = try? JSONDecoder().decode([NoteItem].self, from: data),
           !decoded.isEmpty {
            notes = Array(decoded.prefix(Self.maximumNotes)).map { note in
                var migrated = note
                if migrated.text == "Write a quick note…" { migrated.text = "" }
                return migrated
            }
        } else {
            notes = [NoteItem()]
        }
        selectedNoteID = notes.first?.id
    }

    var selectedNote: NoteItem? {
        guard let selectedNoteID else { return notes.first }
        return notes.first(where: { $0.id == selectedNoteID }) ?? notes.first
    }

    func addNote() {
        guard notes.count < Self.maximumNotes else { return }
        let accent = NoteAccent.allCases[notes.count % NoteAccent.allCases.count]
        let note = NoteItem(accent: accent)
        notes.append(note)
        selectedNoteID = note.id
        save()
    }

    func select(_ note: NoteItem) {
        selectedNoteID = note.id
    }

    func updateSelected(_ update: (inout NoteItem) -> Void) {
        guard let selectedNote,
              let index = notes.firstIndex(where: { $0.id == selectedNote.id }) else { return }
        update(&notes[index])
        save()
    }

    func removeSelected() {
        guard notes.count > 1, let selectedNote else { return }
        notes.removeAll { $0.id == selectedNote.id }
        selectedNoteID = notes.first?.id
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: "notes")
    }
}
