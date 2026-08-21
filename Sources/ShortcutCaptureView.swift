import AppKit

// ショートカット記録用のキャプチャビュー。ファーストレスポンダーとして
// keyDown と performKeyEquivalent の両方を受けるので、⌘入りの組み合わせも
// メニューのキーイクイバレントに取られず確実に拾える。
final class ShortcutCaptureView: NSView {
    var onKeyEvent: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyEvent?(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, event.window === window else {
            return super.performKeyEquivalent(with: event)
        }
        onKeyEvent?(event)
        return true
    }
}
