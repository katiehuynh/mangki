import SwiftUI
import UIKit

func attributedFromStored(_ stored: String) -> NSAttributedString {
    guard let data = stored.data(using: .utf8),
          let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
          ),
          attributed.length > 0 else {
        return NSAttributedString(string: stored)
    }
    return attributed
}

func storedFromAttributed(_ attributed: NSAttributedString) -> String {
    guard let data = try? attributed.data(
        from: NSRange(location: 0, length: attributed.length),
        documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
    ), let html = String(data: data, encoding: .utf8) else {
        return attributed.string
    }
    return html
}

func formattedText(_ stored: String) -> Text {
    Text(AttributedString(attributedFromStored(stored)))
}

struct RichTextEditor: UIViewRepresentable {
    @Binding var attributed: NSAttributedString

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.attributedText = attributed
        textView.inputAccessoryView = Self.toolbar(for: context.coordinator)
        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if !textView.attributedText.isEqual(to: attributed) {
            textView.attributedText = attributed
        }
    }

    private static func toolbar(for coordinator: Coordinator) -> UIToolbar {
        let bold = UIBarButtonItem(title: "B", style: .plain, target: coordinator, action: #selector(Coordinator.toggleBold))
        bold.setTitleTextAttributes([.font: UIFont.boldSystemFont(ofSize: 17)], for: .normal)

        let colors: [(String, UIColor)] = [
            ("Red", .systemRed), ("Orange", .systemOrange), ("Green", .systemGreen),
            ("Blue", .systemBlue), ("Purple", .systemPurple), ("Default", .label)
        ]
        let colorMenu = UIMenu(title: "Text color", children: colors.map { name, color in
            UIAction(title: name) { _ in coordinator.apply(color: color) }
        })
        let color = UIBarButtonItem(title: "A", menu: colorMenu)
        let code = UIBarButtonItem(title: "{ }", style: .plain, target: coordinator, action: #selector(Coordinator.insertCodeBlock))
        let space = UIBarButtonItem(systemItem: .flexibleSpace)
        let done = UIBarButtonItem(title: "Done", style: .done, target: coordinator, action: #selector(Coordinator.dismissKeyboard))

        let toolbar = UIToolbar()
        toolbar.items = [bold, color, code, space, done]
        toolbar.sizeToFit()
        return toolbar
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: RichTextEditor
        weak var textView: UITextView?

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.attributed = textView.attributedText
        }

        @objc func dismissKeyboard() {
            textView?.resignFirstResponder()
        }

        @objc func toggleBold() {
            guard let textView else { return }
            let range = textView.selectedRange
            if range.length == 0 {
                var attributes = textView.typingAttributes
                let font = (attributes[.font] as? UIFont) ?? .preferredFont(forTextStyle: .body)
                var traits = font.fontDescriptor.symbolicTraits
                traits.formSymmetricDifference(.traitBold)
                if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                    attributes[.font] = UIFont(descriptor: descriptor, size: font.pointSize)
                    textView.typingAttributes = attributes
                }
                return
            }

            textView.textStorage.enumerateAttribute(.font, in: range) { value, range, _ in
                let font = (value as? UIFont) ?? .preferredFont(forTextStyle: .body)
                var traits = font.fontDescriptor.symbolicTraits
                traits.formSymmetricDifference(.traitBold)
                if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                    textView.textStorage.addAttribute(.font, value: UIFont(descriptor: descriptor, size: font.pointSize), range: range)
                }
            }
            parent.attributed = textView.attributedText
        }

        func apply(color: UIColor) {
            guard let textView else { return }
            let range = textView.selectedRange
            if range.length == 0 {
                textView.typingAttributes[.foregroundColor] = color
            } else {
                textView.textStorage.addAttribute(.foregroundColor, value: color, range: range)
                parent.attributed = textView.attributedText
            }
        }

        @objc func insertCodeBlock() {
            guard let textView, let selection = textView.selectedTextRange else { return }
            let fence = "\n```python\n\n```\n"
            let startOffset = textView.offset(from: textView.beginningOfDocument,
                                              to: selection.start)
            textView.replace(selection, withText: fence)
            // Place the cursor on the blank line inside the fence.
            let innerOffset = "\n```python\n".count
            if let position = textView.position(from: textView.beginningOfDocument,
                                                offset: startOffset + innerOffset),
               let cursor = textView.textRange(from: position, to: position) {
                textView.selectedTextRange = cursor
            }
            parent.attributed = textView.attributedText
        }
    }
}
