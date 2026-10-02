import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \Deck.createdAt) private var decks: [Deck]
    @Query(sort: \ReviewLog.timestamp, order: .reverse) private var logs: [ReviewLog]

    private let calendar = Calendar.current

    var body: some View {
        List {
            Section("Overview") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statTile("Due now", value: "\(dueCount)", icon: "alarm", color: .orange)
                    statTile("Reviews today", value: "\(reviewsToday)", icon: "checkmark.circle", color: .green)
                    statTile("Recall · 30 days", value: recallText, icon: "brain.head.profile", color: .blue)
                    statTile("Day streak", value: "\(streak)", icon: "flame", color: .red)
                }
                .padding(.vertical, 4)
            }

            Section("Due forecast · next 14 days") {
                if forecast.allSatisfy({ $0.count == 0 }) {
                    Text("Nothing scheduled yet — study some cards first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(forecast) { bucket in
                        BarMark(
                            x: .value("Day", bucket.label),
                            y: .value("Due", bucket.count)
                        )
                    }
                    .frame(height: 150)
                }
            }

            Section("Reviews · last 14 days") {
                if activity.allSatisfy({ $0.count == 0 }) {
                    Text("No reviews yet — your activity will show up here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(activity) { bucket in
                        BarMark(
                            x: .value("Day", bucket.label),
                            y: .value("Reviews", bucket.count)
                        )
                        .foregroundStyle(.green)
                    }
                    .frame(height: 150)
                }
            }

            Section("Decks") {
                ForEach(decks) { deck in
                    HStack {
                        Text(deck.name)
                        Spacer()
                        Text("\(deck.dueCards.count) due · \(deck.cards.count) total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("About") {
                Text("Scheduling uses FSRS-6: each card tracks memory stability and difficulty instead of an ease factor, targeting 90% recall.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Statistics")
    }

    // MARK: - Tiles

    private func statTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computations

    private var dueCount: Int {
        decks.reduce(0) { $0 + $1.dueCards.count }
    }

    private var reviewsToday: Int {
        let today = calendar.startOfDay(for: Date())
        return logs.filter { $0.timestamp >= today }.count
    }

    private var recallText: String {
        let cutoff = Date().addingTimeInterval(-30 * 86400)
        let recent = logs.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return "—" }
        let rate = Double(recent.filter(\.passed).count) / Double(recent.count)
        return String(format: "%.0f%%", rate * 100)
    }

    private var streak: Int {
        let days = Set(logs.map { calendar.startOfDay(for: $0.timestamp) })
        guard !days.isEmpty else { return 0 }
        var day = calendar.startOfDay(for: Date())
        // A streak is alive if today or yesterday has reviews.
        if !days.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while days.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    private struct DayBucket: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
    }

    private var forecast: [DayBucket] {
        let today = calendar.startOfDay(for: Date())
        var counts = Array(repeating: 0, count: 14)
        for deck in decks {
            for card in deck.cards {
                let dueDay = calendar.startOfDay(for: card.nextReview)
                let offset = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
                counts[min(13, max(0, offset))] += 1
            }
        }
        return counts.enumerated().map { index, count in
            let date = calendar.date(byAdding: .day, value: index, to: today)!
            return DayBucket(label: "\(calendar.component(.day, from: date))", count: count)
        }
    }

    private var activity: [DayBucket] {
        let today = calendar.startOfDay(for: Date())
        var counts = Array(repeating: 0, count: 14)
        for log in logs {
            let day = calendar.startOfDay(for: log.timestamp)
            let offset = calendar.dateComponents([.day], from: day, to: today).day ?? -1
            if offset >= 0 && offset < 14 {
                counts[13 - offset] += 1
            }
        }
        return counts.enumerated().map { index, count in
            let date = calendar.date(byAdding: .day, value: index - 13, to: today)!
            return DayBucket(label: "\(calendar.component(.day, from: date))", count: count)
        }
    }
}
