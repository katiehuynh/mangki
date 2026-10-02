import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.createdAt) private var decks: [Deck]

    @State private var showingAddDeck = false
    @State private var newDeckName = ""
    @State private var showingImporter = false
    @State private var importMessage: String?
    @AppStorage("hasImportedNeetCode150") private var hasImportedNeetCode150 = false

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    ContentUnavailableView {
                        Label("No decks yet", systemImage: "rectangle.stack")
                    } description: {
                        Text("Create a deck to start studying.")
                    } actions: {
                        Button("Add Sample Deck") { addSampleDeck() }
                        Button("Create Deck") { showingAddDeck = true }
                    }
                } else {
                    List {
                        ForEach(decks) { deck in
                            NavigationLink {
                                DeckDetailView(deck: deck)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(TagStyle.color(for: deck.name))
                                        .frame(width: 10, height: 10)
                                    Text(deck.name)
                                    Spacer()
                                    Text("\(deck.dueCards.count) due")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteDecks)
                    }
                }
            }
            .navigationTitle("Decks")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        StatsView()
                    } label: {
                        Label("Statistics", systemImage: "chart.bar")
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    NavigationLink {
                        BrowseView()
                    } label: {
                        Label("Browse", systemImage: "magnifyingglass")
                    }
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Decks", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        showingAddDeck = true
                    } label: {
                        Label("Add Deck", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImporter) {
                DocumentPicker { url in
                    showingImporter = false
                    doImport(from: url)
                }
            }
            .alert("Import Decks",
                   isPresented: Binding(get: { importMessage != nil },
                                        set: { if !$0 { importMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMessage ?? "")
            }
            .alert("New Deck", isPresented: $showingAddDeck) {
                TextField("Deck name", text: $newDeckName)
                Button("Cancel", role: .cancel) { newDeckName = "" }
                Button("Create") { createDeck() }
                    .disabled(newDeckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .task {
                importBundledNeetCodeDeckIfNeeded()
            }
        }
    }

    private func doImport(from url: URL) {
        do {
            let (decks, cards) = try importDeckFile(from: url, into: modelContext)
            importMessage = "Imported \(cards) cards into \(decks) decks."
        } catch {
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func importBundledNeetCodeDeckIfNeeded() {
        guard !hasImportedNeetCode150 else { return }
        do {
            _ = try importBundledNeetCodeDeck(into: modelContext)
            hasImportedNeetCode150 = true
        } catch {
            // Keep the app usable and retry on a future launch if the resource
            // could not be read.
        }
    }

    private func createDeck() {
        let name = newDeckName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        modelContext.insert(Deck(name: name))
        newDeckName = ""
    }

    private func deleteDecks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(decks[index])
        }
    }

    private func addSampleDeck() {
        let deck = Deck(name: "Sample Deck")
        let samples = [
            ("What is the capital of France?", "Paris"),
            ("What does CPU stand for?", "Central Processing Unit"),
            ("What is 7 × 8?", "56"),
        ]
        for (front, back) in samples {
            modelContext.insert(Flashcard(front: front, back: back, deck: deck))
        }
        modelContext.insert(deck)
    }
}
