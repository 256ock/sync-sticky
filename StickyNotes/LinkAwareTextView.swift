import AppKit
import SwiftUI

/// プレーンテキストを編集しつつ、本文中のURLを自動検出してCmd+クリックで
/// 既定ブラウザで開けるようにするテキストビュー。
struct LinkAwareTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isRichText = true
        textView.isAutomaticLinkDetectionEnabled = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView

        applyStyle(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // IME変換中(未確定文字入力中)はstring/属性を書き換えない。
        // ここで textStorage を触ると変換中の marked text が壊れ、日本語入力が不安定になる。
        guard !textView.hasMarkedText() else { return }
        if textView.string != text {
            textView.string = text
        }
        applyStyle(to: textView)
    }

    private func applyStyle(to textView: NSTextView) {
        textView.font = font
        textView.typingAttributes = [.font: font, .foregroundColor: textColor]

        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.addAttribute(.font, value: font, range: fullRange)
        storage.addAttribute(.foregroundColor, value: textColor, range: fullRange)
        storage.removeAttribute(.underlineStyle, range: fullRange)
        storage.removeAttribute(.link, range: fullRange)

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let plainText = storage.string
            detector.enumerateMatches(in: plainText, range: fullRange) { match, _, _ in
                guard let match, let url = match.url else { return }
                storage.addAttribute(.link, value: url, range: match.range)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            }
        }
        storage.endEditing()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // 変換中の未確定文字を確定前にバインディングへ伝播させない(確定後に改めて反映される)。
            guard !textView.hasMarkedText() else { return }
            text.wrappedValue = textView.string
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let url: URL?
            if let link = link as? URL {
                url = link
            } else if let link = link as? String {
                url = URL(string: link)
            } else {
                url = nil
            }
            guard let url else { return false }
            NSWorkspace.shared.open(url)
            return true
        }
    }
}
