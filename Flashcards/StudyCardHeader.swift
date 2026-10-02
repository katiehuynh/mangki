import SwiftUI

/// Floating top bar for the study screen: progress counter, a color-coded
/// QUESTION / ANSWER label, and a close button. It hovers over the card
/// with a translucent background instead of taking its own band of space.
struct StudyCardHeader: View {
    let counter: String
    let tags: [String]
    let isShowingAnswer: Bool
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(counter)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(isShowingAnswer ? "ANSWER" : "QUESTION")
                .font(.caption.weight(.bold))
                .foregroundStyle(isShowingAnswer
                                 ? .green
                                 : TagStyle.color(for: tags.first ?? "Question"))
            Spacer()
            Button(action: onEnd) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .accessibilityLabel("End session")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}
