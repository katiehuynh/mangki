import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Import file format
//
// {
//   "version": 1,
//   "decks": [
//     { "name": "01. Arrays & Hashing",
//       "cards": [ { "front": "<html>", "back": "<html>" } ] }
//   ]
// }
//
// Convert .apkg files to this format with tools/apkg_to_json.py — iOS has no
// built-in zip support, so .apkg files can't be imported on-device directly.

struct ImportedCard: Decodable {
    let front: String
    let back: String
    let tags: [String]?
}

struct ImportedDeck: Decodable {
    let name: String
    let cards: [ImportedCard]
}

struct ImportFile: Decodable {
    let version: Int
    let decks: [ImportedDeck]
}

// MARK: - Import

enum DeckImportError: LocalizedError {
    case unreadable
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "Couldn't read the selected file."
        case .invalidFormat:
            return "This isn't a Flashcards deck file (expected JSON with version, decks, and cards)."
        }
    }
}

/// Imports decks from a JSON deck file. Cards are marked as HTML so they
/// render with formatting in study mode. Returns (deckCount, cardCount).
@discardableResult
func importDeckFile(from url: URL, into context: ModelContext) throws -> (decks: Int, cards: Int) {
    let needsAccess = url.startAccessingSecurityScopedResource()
    defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

    guard let data = try? Data(contentsOf: url) else {
        throw DeckImportError.unreadable
    }
    return try importDeckData(data, into: context)
}

@discardableResult
func importDeckData(_ data: Data, into context: ModelContext) throws -> (decks: Int, cards: Int) {
    guard let file = try? JSONDecoder().decode(ImportFile.self, from: data),
          file.version == 1 else {
        throw DeckImportError.invalidFormat
    }

    var cardCount = 0
    for imported in file.decks {
        let deck = Deck(name: imported.name)
        context.insert(deck)
        for c in imported.cards {
            let card = Flashcard(front: c.front, back: c.back, deck: deck)
            card.tags = TagStyle.clean(c.tags ?? [])
            card.isHTML = true
            context.insert(card)
            cardCount += 1
        }
    }
    try context.save()
    return (file.decks.count, cardCount)
}

/// Imports the supplied NeetCode 150 deck from the app bundle.
@discardableResult
func importBundledNeetCodeDeck(into context: ModelContext) throws -> (decks: Int, cards: Int) {
    guard let url = Bundle.main.url(forResource: "NeetCodeDeck", withExtension: "json"),
          let data = try? Data(contentsOf: url) else {
        throw DeckImportError.unreadable
    }
    return try importDeckData(data, into: context)
}

// MARK: - Helpers

/// Rough HTML -> plain text, for list previews.
func plainText(from html: String) -> String {
    let withoutTags = html.replacingOccurrences(of: "<[^>]+>", with: " ",
                                                options: .regularExpression)
    let collapsed = withoutTags.replacingOccurrences(of: "\\s+", with: " ",
                                                     options: .regularExpression)
    return collapsed
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&middot;", with: "·")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Document picker

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController,
                                context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}
