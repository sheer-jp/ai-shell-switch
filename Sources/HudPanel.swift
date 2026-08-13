import AppKit

// ショートカット操作向けの通知パネル。nonactivatingPanelなので
// アプリをアクティブにせずに表示でき、全スペース・フルスクリーン上でも
// 最前面に出る。ダイアログと違い、埋もれて気づけないことがない。
final class HudPanel {
    private let panel: NSPanel
    private let label: NSTextField
    private var hideTimer: Timer?

    init() {
        label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: effect.topAnchor, constant: 13),
            label.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -13)
        ])

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 46),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.contentView = effect
    }

    func show(_ message: String, for seconds: TimeInterval) {
        hideTimer?.invalidate()
        label.stringValue = message
        panel.contentView?.layoutSubtreeIfNeeded()
        let size = panel.contentView?.fittingSize ?? NSSize(width: 360, height: 46)

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        panel.setFrame(
            NSRect(
                x: visible.midX - size.width / 2,
                y: visible.maxY - size.height - 56,
                width: size.width,
                height: size.height
            ),
            display: true
        )
        panel.orderFrontRegardless()

        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        panel.orderOut(nil)
    }
}
