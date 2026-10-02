import SwiftUI
import SwiftData

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: Deck

    @State private var showingAddCard = false
    @State private var showingStudyAllCards = false
    @State private var cardToStudy: Flashcard?
    @State private var cardToEdit: Flashcard?

    private var sortedCards: [Flashcard] {
        deck.cards.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                Button {
                    cardToStudy = nil
                    showingStudyAllCards = true
                } label: {
                    HStack {
                        Label("Study Now", systemImage: "play.fill")
                        Spacer()
                        Text("\(deck.dueCards.count) due")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(deck.dueCards.isEmpty)
            }

            Section("Cards (\(deck.cards.count))") {
                ForEach(sortedCards) { card in
                    Button {
                        cardToStudy = card
                    } label: {
                        CardRow(card: card)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            cardToEdit = card
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)

                        Button("Forget", systemImage: "arrow.counterclockwise") {
                            card.stability = 0
                            card.difficulty = 0
                            card.reps = 0
                            card.lapses = 0
                            card.lastReview = nil
                            card.nextReview = Date()
                            try? modelContext.save()
                        }
                        .tint(.orange)

                        Button(role: .destructive) {
                            modelContext.delete(card)
                            try? modelContext.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Section {
                Text("Tap a card to review it. Swipe left to edit, reset its schedule, or delete it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            Button {
                showingAddCard = true
            } label: {
                Label("Add Card", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddCard) {
            NavigationStack { CardEditorView(deck: deck) }
        }
        .sheet(item: $cardToEdit) { card in
            NavigationStack { CardEditorView(card: card) }
        }
        .fullScreenCover(item: $cardToStudy) { card in
            StudyView(cards: [card], title: deck.name)
        }
        .fullScreenCover(isPresented: $showingStudyAllCards) {
            StudyView(cards: deck.dueCards, title: deck.name)
        }
    }

}

private struct CardRow: View {
    let card: Flashcard

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(plainText(from: card.front).prefix(120)))
                .font(.headline)
                .lineLimit(2)
            Text(String(plainText(from: card.back).prefix(120)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            TagPills(tags: card.tags)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .leading) {
            if let tag = card.tags.first {
                Capsule()
                    .fill(TagStyle.color(for: tag))
                    .frame(width: 4)
            }
        }
        .padding(.leading, card.tags.isEmpty ? 0 : 10)
    }
}
