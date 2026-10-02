import SwiftUI
import UIKit

/// Offline syntax highlighting for fenced code blocks in cards.
enum CodeHighlighter {
    private static let keywords: [String: Set<String>] = [
        "python": ["def", "class", "return", "if", "else", "for", "while", "in", "import", "from", "try", "except", "True", "False", "None"],
        "swift": ["import", "struct", "class", "enum", "extension", "func", "let", "var", "if", "else", "guard", "for", "while", "return", "try", "true", "false", "nil", "self"],
        "javascript": ["const", "let", "var", "function", "class", "return", "if", "else", "for", "while", "import", "export", "async", "await", "true", "false", "null"],
        "java": ["class", "public", "private", "static", "void", "int", "boolean", "new", "return", "if", "else", "for", "while", "true", "false", "null"],
        "cpp": ["class", "struct", "public", "private", "static", "void", "int", "bool", "auto", "return", "if", "else", "for", "while", "true", "false", "nullptr"],
        "sql": ["SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "CREATE", "TABLE", "JOIN", "ORDER", "GROUP", "BY", "LIMIT", "AND", "OR", "NULL"]
    ]

    static func normalizedLanguage(_ language: String?) -> String {
        switch language?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "py", "python", "python3": return "python"
        case "js", "javascript", "jsx", "ts", "typescript", "tsx": return "javascript"
        case "swift": return "swift"
        case "java", "kotlin": return "java"
        case "c", "cc", "cpp", "c++": return "cpp"
        case "sql": return "sql"
        default: return "plain"
        }
    }

    static func highlight(_ code: String, language: String?) -> AttributedString {
        let language = normalizedLanguage(language)
        let wordList = keywords[language, default: []].map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        // Group 1 = comment, 2 = string, 3 = number, 4 = keyword.
        let pattern = "((?:#|//)[^\\n]*)"
            + "|(\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"|'(?:[^'\\\\]|\\\\.)*')"
            + "|(\\b(?:0[xX][0-9a-fA-F]+|\\d+(?:\\.\\d+)?)\\b)"
            + (wordList.isEmpty ? "" : "|(\\b(?:\(wordList))\\b)")
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return AttributedString(code) }

        let styled = NSMutableAttributedString(string: code, attributes: [.foregroundColor: UIColor.label])
        for match in regex.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
            let color: UIColor
            if match.range(at: 1).location != NSNotFound { color = .systemGreen }
            else if match.range(at: 2).location != NSNotFound { color = .systemRed }
            else if match.range(at: 3).location != NSNotFound { color = .systemBlue }
            else { color = .systemPurple }
            styled.addAttribute(.foregroundColor, value: color, range: match.range)
        }
        return AttributedString(styled)
    }
}

struct CardSegment: Identifiable {
    enum Kind { case text(String), code(language: String?, code: String) }
    let id = UUID()
    let kind: Kind
}

/// Splits stored card text on ``` fences into text and code segments.
///
/// The editor stores HTML, so fences may be separated by <br> or </p><p>
/// instead of literal newlines — those are normalized first. Code content
/// is stripped of tags and unescaped so it renders as plain code.
func parseCardSegments(_ text: String) -> [CardSegment] {
    var normalized = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n",
                                               options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: "</p>\\s*<p[^>]*>",
                                                 with: "\n", options: .regularExpression)
    guard let regex = try? NSRegularExpression(pattern: "```([^\\n<]*)\\n([\\s\\S]*?)(```|$)") else {
        return [.init(kind: .text(text))]
    }
    let source = normalized as NSString
    var last = 0
    var segments: [CardSegment] = []
    for match in regex.matches(in: normalized, range: NSRange(location: 0, length: source.length)) {
        if match.range.location > last {
            segments.append(.init(kind: .text(source.substring(with: NSRange(location: last, length: match.range.location - last)))))
        }
        let language = source.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        let rawCode = source.substring(with: match.range(at: 2)).replacingOccurrences(of: "\\n+$", with: "", options: .regularExpression)
        segments.append(.init(kind: .code(language: language.isEmpty ? nil : language, code: plainCode(rawCode))))
        last = match.range.location + match.range.length
    }
    if last < source.length { segments.append(.init(kind: .text(source.substring(from: last)))) }
    return segments
}

/// Strips HTML tags and unescapes entities inside fenced code.
private func plainCode(_ html: String) -> String {
    var s = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    s = s.replacingOccurrences(of: "&lt;", with: "<")
    s = s.replacingOccurrences(of: "&gt;", with: ">")
    s = s.replacingOccurrences(of: "&quot;", with: "\"")
    s = s.replacingOccurrences(of: "&#39;", with: "'")
    s = s.replacingOccurrences(of: "&nbsp;", with: " ")
    s = s.replacingOccurrences(of: "&amp;", with: "&")  // last: "&amp;lt;" -> "&lt;"
    return s
}

struct CodeBlockView: View {
    let language: String?
    let code: String

    var body: some View {
        let lines = code.components(separatedBy: "\n")
        HStack(alignment: .top, spacing: 10) {
            Text((1...max(1, lines.count)).map(String.init).joined(separator: "\n"))
                .foregroundStyle(.tertiary)
            Text(CodeHighlighter.highlight(code, language: language))
                .textSelection(.enabled)
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contextMenu { Button("Copy code") { UIPasteboard.general.string = code } }
    }
}

struct RichCardBody: View {
    let stored: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(parseCardSegments(stored)) { segment in
                switch segment.kind {
                case .text(let text):
                    // formattedText (not plain Text) so bold, underline, and
                    // text colors from the editor show in answers.
                    formattedText(text)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                case .code(let language, let code):
                    CodeBlockView(language: language, code: code)
                }
            }
        }
    }
}
