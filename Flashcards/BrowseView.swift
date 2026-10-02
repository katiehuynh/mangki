import SwiftUI
import SwiftData

struct BrowseView: View {
    @Query(sort: \Flashcard.createdAt, order: .reverse) private var cards: [Flashcard]
    @State private var query = ""

    private var filteredCards: [Flashcard] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return cards }
        return cards.filter {
            plainText(from: $0.front).localizedCaseInsensitiveContains(query)
                || plainText(from: $0.back).localizedCaseInsensitiveContains(query)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        List {
            ForEach(filteredCards) { card in
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(plainText(from: card.front).prefix(120)))
                        .font(.headline)
                        .lineLimit(2)
                    Text(card.deck?.name ?? "No deck")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TagPills(tags: card.tags)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Browse")
        .searchable(text: $query, prompt: "Search cards and tags")
    }
}
