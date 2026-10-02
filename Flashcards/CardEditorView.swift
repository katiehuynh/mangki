import SwiftUI
import SwiftData

struct CardEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private enum Mode {
        case create(Deck)
        case edit(Flashcard)
    }

    private let mode: Mode
    @State private var front: NSAttributedString
    @State private var back: NSAttributedString
    @State private var tagText: String

    init(deck: Deck) {
        mode = .create(deck)
        _front = State(initialValue: NSAttributedString(string: ""))
        _back = State(initialValue: NSAttributedString(string: ""))
        _tagText = State(initialValue: "")
    }

    init(card: Flashcard) {
        mode = .edit(card)
        _front = State(initialValue: attributedFromStored(card.front))
        _back = State(initialValue: attributedFromStored(card.back))
        _tagText = State(initialValue: card.tags.joined(separator: ", "))
    }

    private var canEditContent: Bool {
        if case .edit(let card) = mode {
            return !card.isHTML
        }
        return true
    }

    private var isValid: Bool {
        !front.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !back.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            CardEditorContentSection(
                title: "Front",
                attributed: $front,
                isEditable: canEditContent
            )
            CardEditorContentSection(
                title: "Back",
                attributed: $back,
                isEditable: canEditContent
            )

            Section("Tags") {
                TextField("Algorithms, Arrays, Review", text: $tagText)
                    .textInputAutocapitalization(.words)
                TagPills(tags: TagStyle.tags(from: tagText))
                Text("Separate tags with commas. Each tag gets a consistent color.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if canEditContent {
                Section("Formatting") {
                    Text("Select text, then use the keyboard’s A menu to emphasize key details with color. Use { } to insert a code block.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Card" : "New Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add") { save() }
                    .disabled(!isValid)
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func save() {
        switch mode {
        case .create(let deck):
            let card = Flashcard(
                front: storedFromAttributed(front),
                back: storedFromAttributed(back),
                deck: deck
            )
            card.tags = TagStyle.tags(from: tagText)
            modelContext.insert(card)
        case .edit(let card):
            if canEditContent {
                card.front = storedFromAttributed(front)
                card.back = storedFromAttributed(back)
            }
            card.tags = TagStyle.tags(from: tagText)
        }
        try? modelContext.save()
        dismiss()
    }
}

private struct CardEditorContentSection: View {
    let title: LocalizedStringKey
    @Binding var attributed: NSAttributedString
    let isEditable: Bool

    var body: some View {
        Section(title) {
            if isEditable {
                RichTextEditor(attributed: $attributed)
                    .frame(minHeight: 130)
            } else {
                Text("Imported HTML content can’t be edited here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
