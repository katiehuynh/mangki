import SwiftUI
import SwiftData

struct StudyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let title: String
    private let fsrs = FSRS()

    @State private var queue: [Flashcard]

    init(cards: [Flashcard], title: String) {
        self.title = title
        _queue = State(initialValue: cards)
    }
    @State private var showingAnswer = false
    @State private var reviewed = 0

    private var total: Int { reviewed + queue.count }

    var body: some View {
        VStack(spacing: 0) {
            if queue.isEmpty {
                ContentUnavailableView {
                    Label("All done!", systemImage: "checkmark.circle")
                } description: {
                    Text("You reviewed \(reviewed) card\(reviewed == 1 ? "" : "s").")
                } actions: {
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let card = queue.first {
                let shownText = showingAnswer ? card.back : card.front
                let isCodeCard = !card.isHTML && shownText.contains("```")

                ZStack {
                    // The card fills the whole screen (padded just enough
                    // to start below the floating top bar).
                    Group {
                        if card.isHTML {
                            HTMLView(html: shownText) {
                                withAnimation { showingAnswer.toggle() }
                            }
                        } else if isCodeCard {
                            ScrollView {
                                RichCardBody(stored: shownText)
                                    .frame(maxWidth: .infinity, minHeight: 200)
                            }
                        } else {
                            Button {
                                withAnimation { showingAnswer.toggle() }
                            } label: {
                                formattedText(shownText)
                                    .font(.title2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(.plain)
                            .animation(.default, value: showingAnswer)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 52)
                    .padding(.horizontal, 16)

                    // Floating top bar — translucent, takes no layout space.
                    VStack {
                        StudyCardHeader(counter: "\(reviewed + 1)/\(total)",
                                        tags: card.tags,
                                        isShowingAnswer: showingAnswer,
                                        onEnd: { dismiss() })
                        Spacer()
                    }

                    // Floating bottom controls — transparent, no solid band.
                    VStack {
                        Spacer()
                        if showingAnswer {
                            HStack(spacing: 6) {
                                gradeButton("Again", rating: 1, card: card, color: .red)
                                gradeButton("Hard", rating: 2, card: card, color: .orange)
                                gradeButton("Good", rating: 3, card: card, color: .green)
                                gradeButton("Easy", rating: 4, card: card, color: .blue)
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 10)
                        } else if isCodeCard {
                            Button("Reveal answer") {
                                withAnimation { showingAnswer = true }
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.bottom, 12)
                        } else {
                            Text("Tap the card to reveal the answer")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .padding(.bottom, 12)
                        }
                    }
                }
            }
        }
    }

    /// What the button would schedule, previewed before answering (like Anki).
    private func previewInterval(for rating: Int, card: Flashcard) -> String {
        let result = fsrs.reviewCard(stability: card.stability,
                                    difficulty: card.difficulty,
                                    reps: card.reps,
                                    lastReview: card.lastReview,
                                    rating: rating)
        return FSRS.formatInterval(result.interval)
    }

    private func gradeButton(_ title: String, rating: Int, card: Flashcard, color: Color) -> some View {
        Button {
            grade(card, rating)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(previewInterval(for: rating, card: card))
                    .opacity(0.75)
            }
            .font(.subheadline)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    private func grade(_ card: Flashcard, _ rating: Int) {
        let now = Date()
        let wasNew = card.isNew
        let result = fsrs.reviewCard(stability: card.stability,
                                    difficulty: card.difficulty,
                                    reps: card.reps,
                                    lastReview: card.lastReview,
                                    rating: rating,
                                    now: now)

        card.stability = result.stability
        card.difficulty = result.difficulty
        card.lastReview = now
        card.nextReview = now.addingTimeInterval(result.interval)
        card.reps += 1
        if rating == 1 && !wasNew {
            card.lapses += 1
        }

        let log = ReviewLog(grade: rating,
                            retrievability: result.retrievability,
                            deckName: card.deck?.name ?? title,
                            card: card)
        modelContext.insert(log)
        try? modelContext.save()

        reviewed += 1
        showingAnswer = false
        // Failed cards go back to the end of the session queue.
        let current = queue.removeFirst()
        if rating == 1 {
            queue.append(current)
        }
    }
}
