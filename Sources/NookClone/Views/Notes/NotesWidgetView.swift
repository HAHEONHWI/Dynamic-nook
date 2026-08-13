import SwiftUI

struct NotesWidgetView: View {
    let store: NotesStore
    let showScrollIndicator: Bool
    @State private var showsMarkdownPreview = false

    var body: some View {
        HStack(spacing: 8) {
            noteEditor
            noteSelector
        }
    }

    private var noteEditor: some View {
        VStack(spacing: 5) {
            if let note = store.selectedNote {
                ZStack(alignment: .topLeading) {
                    if note.text.isEmpty {
                        Text("Write a quick note…")
                            .foregroundStyle(.white.opacity(0.38))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                    if showsMarkdownPreview {
                        ScrollView {
                            Text(markdown(note.text))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                        .scrollIndicators(showScrollIndicator ? .visible : .hidden)
                    } else {
                        TextEditor(text: textBinding)
                            .font(note.isCodeMode ? .system(.body, design: .monospaced) : .body)
                            .fontWeight(note.isBold ? .bold : .regular)
                            .italic(note.isItalic)
                            .underline(note.isUnderlined)
                            .scrollContentBackground(.hidden)
                            .scrollIndicators(showScrollIndicator ? .visible : .hidden)
                            .padding(8)
                    }
                }
                .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                HStack(spacing: 6) {
                    Menu {
                        ForEach(NoteAccent.allCases) { accent in
                            Button {
                                store.updateSelected { $0.accent = accent }
                            } label: {
                                Text(LocalizedStringKey(accent.rawValue.capitalized))
                            }
                        }
                    } label: {
                        Circle()
                            .fill(color(for: note.accent))
                            .frame(width: 18, height: 18)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 22)

                    Spacer()
                    formatButton("curlybraces", selected: note.isCodeMode) {
                        store.updateSelected { $0.isCodeMode.toggle() }
                    }
                    formatButton("text.badge.checkmark", selected: showsMarkdownPreview) {
                        showsMarkdownPreview.toggle()
                    }
                    formatButton("bold", selected: note.isBold) {
                        store.updateSelected { $0.isBold.toggle() }
                    }
                    formatButton("italic", selected: note.isItalic) {
                        store.updateSelected { $0.isItalic.toggle() }
                    }
                    formatButton("underline", selected: note.isUnderlined) {
                        store.updateSelected { $0.isUnderlined.toggle() }
                    }
                }
            }
        }
    }

    private var noteSelector: some View {
        VStack(spacing: 6) {
            ForEach(Array(store.notes.enumerated()), id: \.element.id) { index, note in
                Button {
                    store.select(note)
                } label: {
                    Image(systemName: selectorSymbol(index))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color(for: note.accent))
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(store.selectedNoteID == note.id ? .white.opacity(0.16) : .white.opacity(0.07))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Note \(index + 1)")
            }

            if store.notes.count < NotesStore.maximumNotes {
                Button {
                    store.addNote()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 26)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Note")
            } else {
                Button {
                    store.removeSelected()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 30, height: 26)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove Selected Note")
            }
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { store.selectedNote?.text ?? "" },
            set: { value in store.updateSelected { $0.text = value } }
        )
    }

    private func formatButton(_ symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 22)
                .background(selected ? .white.opacity(0.2) : .white.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func selectorSymbol(_ index: Int) -> String {
        ["circle.fill", "triangle.fill", "square.fill", "diamond.fill"][index % 4]
    }

    private func color(for accent: NoteAccent) -> Color {
        switch accent {
        case .blue: .blue
        case .cyan: .cyan
        case .orange: .orange
        case .pink: .pink
        }
    }

    private func markdown(_ source: String) -> AttributedString {
        (try? AttributedString(markdown: source, options: .init(interpretedSyntax: .full))) ?? AttributedString(source)
    }
}
