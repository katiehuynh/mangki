import Foundation
import SwiftData

@Model
final class Deck {
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Flashcard.deck)
    var cards: [Flashcard] = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }

    /// Cards whose next review is due, oldest first.
    var dueCards: [Flashcard] {
        cards.filter { $0.nextReview <= Date() }
             .sorted { $0.nextReview < $1.nextReview }
    }
}

@Model
final class Flashcard {
    var front: String
    var back: String
    var createdAt: Date
    var nextReview: Date
    var lastReview: Date?

    /// FSRS memory stability: days until recall probability decays to 90%.
    /// 0 means the card is new and hasn't been graded yet.
    var stability: Double
    /// FSRS memory difficulty: 1 (easy) – 10 (hard).
    var difficulty: Double

    var reps: Int
    var lapses: Int

    /// User-defined categories shown as color-coded pills.
    var tags: [String] = []

    /// When true, front/back are HTML and render in a web view.
    var isHTML: Bool = false

    var deck: Deck?

    init(front: String, back: String, deck: Deck? = nil) {
        self.front = front
        self.back = back
        self.createdAt = Date()
        self.nextReview = Date()
        self.lastReview = nil
        self.stability = 0
        self.difficulty = 0
        self.reps = 0
        self.lapses = 0
        self.deck = deck
    }

    var isNew: Bool { reps == 0 }

    /// Predicted probability of recall right now (nil for new cards).
    func currentRetrievability(using fsrs: FSRS = FSRS(), now: Date = Date()) -> Double? {
        guard !isNew, let last = lastReview else { return nil }
        let days = max(0, now.timeIntervalSince(last) / 86400)
        return fsrs.retrievability(daysElapsed: days, stability: stability)
    }
}

/// One recorded answer during a study session. Powers statistics.
@Model
final class ReviewLog {
    var timestamp: Date
    /// 1 = Again, 2 = Hard, 3 = Good, 4 = Easy
    var grade: Int
    /// FSRS-predicted recall probability before this review (nil for first reviews).
    var retrievability: Double?
    /// Denormalized so stats survive card deletion.
    var deckName: String
    var card: Flashcard?

    init(timestamp: Date = Date(), grade: Int, retrievability: Double?,
         deckName: String, card: Flashcard?) {
        self.timestamp = timestamp
        self.grade = grade
        self.retrievability = retrievability
        self.deckName = deckName
        self.card = card
    }

    var passed: Bool { grade >= 3 }
}
