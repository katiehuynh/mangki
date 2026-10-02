import SwiftUI

enum TagStyle {
    // All readable as small text on light and dark backgrounds
    // (no yellow — it washes out on white).
    private static let palette: [Color] = [
        .red, .orange, .green, .mint, .teal, .blue, .indigo, .purple, .pink, .brown
    ]

    /// Deterministic color per tag (djb2 over the lowercased name, so a tag
    /// always gets the same color on every launch and every device).
    static func color(for tag: String) -> Color {
        var hash = 5381
        for scalar in tag.lowercased().unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return palette[(hash & 0x7FFF_FFFF) % palette.count]
    }

    /// Trims, drops empties, and dedups (case-insensitive), preserving order.
    static func clean(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.localizedLowercase).inserted }
    }

    static func tags(from text: String) -> [String] {
        clean(text.split(separator: ",").map(String.init))
    }
}

struct TagPills: View {
    let tags: [String]

    var body: some View {
        let clean = TagStyle.clean(tags)
        if !clean.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(clean, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(TagStyle.color(for: tag))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(TagStyle.color(for: tag).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var points: [CGPoint] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: proposal.width ?? x, height: y + lineHeight), points)
    }
}
