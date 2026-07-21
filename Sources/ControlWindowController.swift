import AppKit

final class ControlWindowController: NSObject {
    private let toggleAction: () -> Void
    private let refreshAction: () -> Void
    private let statusLabel = NSTextField(labelWithString: "状態を確認中…")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let powerLabel = NSTextField(labelWithString: "")
    private let toggleButton = NSButton(title: "切り替え", target: nil, action: #selector(togglePressed))
    private let refreshButton = NSButton(title: "状態を更新", target: nil, action: #selector(refreshPressed))
    private lazy var window = makeWindow()

    init(toggleAction: @escaping () -> Void, refreshAction: @escaping () -> Void) {
        self.toggleAction = toggleAction
        self.refreshAction = refreshAction
        super.init()
        toggleButton.target = self
        refreshButton.target = self
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func update(_ state: PowerState) {
        powerLabel.stringValue = state.onACPower ? "電源: AC Power" : "電源: Battery Power"

        switch state.mode {
        case .on:
            statusLabel.stringValue = state.onACPower ? "AI ON" : "AI ON（バッテリー注意）"
            statusLabel.textColor = state.onACPower ? .systemGreen : .systemOrange
            detailLabel.stringValue = state.onACPower
                ? "蓋を閉じてもMacのスリープを禁止しています。終了後はOFFへ戻してください。"
                : "スリープ禁止のままバッテリー駆動中です。電源をつなぐか、OFFへ戻してください。"
            toggleButton.title = "通常スリープに戻す（OFF）"
            toggleButton.isEnabled = true
        case .off:
            statusLabel.stringValue = "AI OFF"
            statusLabel.textColor = .labelColor
            detailLabel.stringValue = "普通のmacOSスリープ設定です。蓋を閉じると通常どおりスリープできます。"
            toggleButton.title = state.onACPower ? "AI稼働モードにする（ON）" : "AC電源接続後にON"
            toggleButton.isEnabled = state.onACPower
        }
    }

    @objc private func togglePressed() {
        toggleAction()
    }

    @objc private func refreshPressed() {
        refreshAction()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 310),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AI Shell Switch"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()

        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56)
        ])

        let titleLabel = NSTextField(labelWithString: "AI Shell Switch")
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)

        let subtitleLabel = NSTextField(labelWithString: "蓋を閉じている間のAI稼働を、安全に切り替えます")
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.font = .systemFont(ofSize: 12)

        let headingStack = NSStackView(views: [titleLabel, subtitleLabel])
        headingStack.orientation = .vertical
        headingStack.alignment = .leading
        headingStack.spacing = 4

        let headerStack = NSStackView(views: [iconView, headingStack])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 14

        statusLabel.font = .systemFont(ofSize: 19, weight: .semibold)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 3
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        powerLabel.font = .systemFont(ofSize: 12, weight: .medium)

        toggleButton.bezelStyle = .rounded
        toggleButton.controlSize = .large
        refreshButton.bezelStyle = .rounded
        refreshButton.controlSize = .large

        let buttonStack = NSStackView(views: [toggleButton, refreshButton])
        buttonStack.orientation = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 10

        let footerLabel = NSTextField(labelWithString: "⌃⌥A: 操作画面を開く / ON中は緊急OFF")
        footerLabel.textColor = .tertiaryLabelColor
        footerLabel.font = .systemFont(ofSize: 11)
        footerLabel.alignment = .center

        let contentStack = NSStackView(views: [
            headerStack,
            statusLabel,
            detailLabel,
            powerLabel,
            buttonStack,
            footerLabel
        ])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(contentStack)
        window.contentView = contentView

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -18),
            headerStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            detailLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            powerLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            buttonStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            footerLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor)
        ])

        return window
    }
}
