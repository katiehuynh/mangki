import SwiftUI
import SwiftData

@main
struct FlashcardsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Deck.self, Flashcard.self, ReviewLog.self])
    }
}
