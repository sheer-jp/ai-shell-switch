import AppKit

// 設定ウィンドウは実際のロジックを持たない。ショートカット変更・
// ログイン時起動・パスワード省略の各操作はすべてAppDelegateが所有し、
// このコントローラはクロージャ経由でそれらを呼び出すだけの薄い表示層。
final class SettingsWindowController: NSObject {
    private let currentShortcutLabel: () -> String
    private let changeShortcutAction: () -> Void
    private let resetShortcutAction: () -> Void
    private let isLoginItemEnabled: () -> Bool
    private let toggleLoginItemAction: () -> Void
    private let isPrivilegeInstalled: () -> Bool
    private let togglePrivilegeAction: () -> Void

    private let shortcutValueLabel = NSTextField(labelWithString: "")
    private let changeShortcutButton = NSButton(
        title: "ショートカットを変更…",
        target: nil,
        action: #selector(changeShortcutPressed)
    )
    private let resetShortcutButton = NSButton(
        title: "既定に戻す",
        target: nil,
        action: #selector(resetShortcutPressed)
    )
    private let loginItemCheckbox = NSButton(
        checkboxWithTitle: "ログイン時にも起動",
        target: nil,
        action: #selector(loginItemPressed)
    )
    private let privilegeCheckbox = NSButton(
        checkboxWithTitle: "ON/OFF切り替えのパスワード省略",
        target: nil,
        action: #selector(privilegePressed)
    )
    private lazy var window = makeWindow()

    init(
        currentShortcutLabel: @escaping () -> String,
        changeShortcutAction: @escaping () -> Void,
        resetShortcutAction: @escaping () -> Void,
        isLoginItemEnabled: @escaping () -> Bool,
        toggleLoginItemAction: @escaping () -> Void,
        isPrivilegeInstalled: @escaping () -> Bool,
        togglePrivilegeAction: @escaping () -> Void
    ) {
        self.currentShortcutLabel = currentShortcutLabel
        self.changeShortcutAction = changeShortcutAction
        self.resetShortcutAction = resetShortcutAction
        self.isLoginItemEnabled = isLoginItemEnabled
        self.toggleLoginItemAction = toggleLoginItemAction
        self.isPrivilegeInstalled = isPrivilegeInstalled
        self.togglePrivilegeAction = togglePrivilegeAction
        super.init()
        changeShortcutButton.target = self
        resetShortcutButton.target = self
        loginItemCheckbox.target = self
        privilegeCheckbox.target = self
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        refreshAll()
        window.makeKeyAndOrderFront(nil)
    }

    // AppDelegate.refreshShortcutLabels() から、ショートカットが変わるたびに呼ばれる。
    func updateShortcutLabel(_ label: String) {
        shortcutValueLabel.stringValue = label
    }

    // AppDelegate.refreshLoginItem() から、状態確認のたびに呼ばれる。
    func refreshLoginItemState() {
        loginItemCheckbox.state = isLoginItemEnabled() ? .on : .off
    }

    // AppDelegate.refreshPrivilegeItem() から、状態確認のたびに呼ばれる。
    func refreshPrivilegeState() {
        privilegeCheckbox.state = isPrivilegeInstalled() ? .on : .off
    }

    private func refreshAll() {
        updateShortcutLabel(currentShortcutLabel())
        refreshLoginItemState()
        refreshPrivilegeState()
    }

    @objc private func changeShortcutPressed() {
        changeShortcutAction()
    }

    @objc private func resetShortcutPressed() {
        resetShortcutAction()
    }

    @objc private func loginItemPressed() {
        toggleLoginItemAction()
        // チェックボックスはクリックで即座に見た目が反転するため、
        // 実際の状態(操作が失敗した場合を含む)で必ず上書きする。
        refreshLoginItemState()
    }

    @objc private func privilegePressed() {
        togglePrivilegeAction()
        // 確認ダイアログがキャンセルされた場合でも見た目が反転したままに
        // ならないよう、操作後は必ず実際の状態を読み直す。
        refreshPrivilegeState()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "設定"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()

        let shortcutValueRow = NSStackView(views: [
            NSTextField(labelWithString: "現在のショートカット"),
            shortcutValueLabel
        ])
        shortcutValueRow.orientation = .horizontal
        shortcutValueRow.spacing = 6
        shortcutValueLabel.font = .systemFont(ofSize: 13, weight: .medium)
        shortcutValueLabel.textColor = .secondaryLabelColor

        changeShortcutButton.bezelStyle = .rounded
        resetShortcutButton.bezelStyle = .rounded
        let shortcutButtonRow = NSStackView(views: [changeShortcutButton, resetShortcutButton])
        shortcutButtonRow.orientation = .horizontal
        shortcutButtonRow.spacing = 8

        let shortcutStack = NSStackView(views: [
            sectionLabel("ショートカット"),
            shortcutValueRow,
            shortcutButtonRow
        ])
        shortcutStack.orientation = .vertical
        shortcutStack.alignment = .leading
        shortcutStack.spacing = 8

        let launchStack = NSStackView(views: [sectionLabel("起動"), loginItemCheckbox])
        launchStack.orientation = .vertical
        launchStack.alignment = .leading
        launchStack.spacing = 8

        let privilegeStack = NSStackView(views: [sectionLabel("権限"), privilegeCheckbox])
        privilegeStack.orientation = .vertical
        privilegeStack.alignment = .leading
        privilegeStack.spacing = 8

        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        let footerLabel = NSTextField(labelWithString: "AI Shell Switch v\(version)")
        footerLabel.font = .systemFont(ofSize: 11)
        footerLabel.textColor = .tertiaryLabelColor

        let firstSeparator = separator()
        let secondSeparator = separator()
        let thirdSeparator = separator()

        let contentStack = NSStackView(views: [
            shortcutStack,
            firstSeparator,
            launchStack,
            secondSeparator,
            privilegeStack,
            thirdSeparator,
            footerLabel
        ])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(contentStack)
        window.contentView = contentView

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -18),
            shortcutStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            launchStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            privilegeStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            footerLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            firstSeparator.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            secondSeparator.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            thirdSeparator.widthAnchor.constraint(equalTo: contentStack.widthAnchor)
        ])

        return window
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
