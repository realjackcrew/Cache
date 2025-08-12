import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        
        textView.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        textView.textColor = UIColor(red: 0.24, green: 0.25, blue: 0.36, alpha: 1.0)
        textView.backgroundColor = .clear
        textView.autocorrectionType = .default
        textView.spellCheckingType = .yes
        textView.smartDashesType = .yes
        textView.smartQuotesType = .yes
        textView.autocapitalizationType = .none
        textView.smartInsertDeleteType = .yes
        textView.keyboardType = .default
        textView.textContainerInset = .zero
        textView.contentInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isSelectable = true
        textView.isEditable = true
        
        textView.becomeFirstResponder()
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != text {
            uiView.attributedText = text
        }
        if let pending = context.coordinator.pendingSelectedRange {
            uiView.selectedRange = pending
            context.coordinator.pendingSelectedRange = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        weak var textView: UITextView?
        var pendingSelectedRange: NSRange?

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            self.textView = textView
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.attributedText
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if textView.markedTextRange != nil { return true }
            if text == " " {
                let paragraphRange = (textView.text as NSString).paragraphRange(for: range)
                let lineText = (textView.text as NSString).substring(with: NSRange(location: paragraphRange.location, length: range.location - paragraphRange.location))

                if lineText == "*" {
                    applyListStyle(to: textView, at: range, trigger: "*", prefix: "•  ")
                    return false
                }
                
                if lineText == "-" {
                    applyListStyle(to: textView, at: range, trigger: "-", prefix: "–  ")
                    return false
                }

                let topLevelNumberRegex = try! NSRegularExpression(pattern: "^(\\d+)\\.$")
                if topLevelNumberRegex.firstMatch(in: lineText, options: [], range: NSRange(location: 0, length: lineText.utf16.count)) != nil {
                    applyListStyle(to: textView, at: range, trigger: lineText, prefix: "\(lineText) ")
                    return false
                }

            }

            if text == "\n" {
                guard !textView.text.isEmpty else { return true }

                let currentParagraphRange = (textView.text as NSString).paragraphRange(for: range)
                let paragraphText = (textView.text as NSString).substring(with: currentParagraphRange)
                let trimmedLine = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)

                // Remove empty list marker lines (top level only)
                let emptyNumberOnly = try! NSRegularExpression(pattern: #"^\d+\.\s*$"#)
                let emptyBulletOnly = try! NSRegularExpression(pattern: #"^(•|–)\s*$"#)
                if emptyNumberOnly.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) != nil ||
                   emptyBulletOnly.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) != nil {
                    removeListStyle(from: textView, at: currentParagraphRange)
                    return false
                }

                // Continue numbered list (top level)
                let numberPrefixRegex = try! NSRegularExpression(pattern: #"^(\d+)\.\s+"#)
                if let match = numberPrefixRegex.firstMatch(in: paragraphText, options: [], range: NSRange(location: 0, length: paragraphText.utf16.count)),
                   let numberRange = Range(match.range(at: 1), in: paragraphText),
                   let number = Int(paragraphText[numberRange]) {
                    let newPrefix = "\n\(number + 1). "
                    insertText(newPrefix, in: textView, at: range.location)
                    return false
                }

                // Continue bullet/dash list (top level)
                let bulletPrefixRegex = try! NSRegularExpression(pattern: #"^(•|–)\s+"#)
                if let match = bulletPrefixRegex.firstMatch(in: paragraphText, options: [], range: NSRange(location: 0, length: paragraphText.utf16.count)) {
                    let prefix = (paragraphText as NSString).substring(with: match.range)
                    insertText("\n\(prefix)", in: textView, at: range.location)
                    return false
                }
            }

            return true
        }
        
        private func applyListStyle(to textView: UITextView, at range: NSRange, trigger: String, prefix: String) {
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            let paragraphRange = (mutableText.string as NSString).paragraphRange(
                for: NSRange(location: range.location - trigger.count, length: 0)
            )

            let replaceRange = NSRange(location: paragraphRange.location, length: trigger.count)
            mutableText.replaceCharacters(in: replaceRange, with: prefix)

            let newSelection = NSRange(location: paragraphRange.location + prefix.count, length: 0)
            parent.text = mutableText
            textView.selectedRange = newSelection
            pendingSelectedRange = newSelection
        }
        
        private func removeListStyle(from textView: UITextView, at range: NSRange) {
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableText.replaceCharacters(in: range, with: "\n")

            let newSelection = NSRange(location: range.location + 1, length: 0)
            parent.text = mutableText
            textView.selectedRange = newSelection
            pendingSelectedRange = newSelection
        }
        
        private func insertText(_ text: String, in textView: UITextView, at location: Int) {
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            var attributes = textView.typingAttributes

            let paragraphStyle = (attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.headIndent = 0
            attributes[.paragraphStyle] = paragraphStyle

            let attributedString = NSAttributedString(string: text, attributes: attributes)
            mutableText.insert(attributedString, at: location)

            let newSelection = NSRange(location: location + text.count, length: 0)
            parent.text = mutableText
            textView.selectedRange = newSelection
            pendingSelectedRange = newSelection
        }
        

    }
}


