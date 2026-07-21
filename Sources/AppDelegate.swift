import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let openControlItem = NSMenuItem(title: "操作画面を開く…", action: #selector(showControlWindow), keyEquivalent: "o")
    private let stateItem = NSMenuItem(title: "状態を確認中…", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "切り替え", action: #selector(toggleMode), keyEquivalent: "")
    private let privilegeItem = NSMenuItem(title: "パスワード省略を設定…", action: #selector(togglePrivilegeMode), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "ログイン時にも起動", action: #selector(toggleLoginItem), keyEquivalent: "")
    private lazy var controlWindowController = ControlWindowController(
        toggleAction: { [weak self] in self?.toggleMode() },
        refreshAction: { [weak self] in self?.refreshState() }
    )
    private var timer: Timer?
    private var globalHotKey: GlobalHotKey?
    private var currentState = PowerState(mode: .off, onACPower: false)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        configureGlobalHotKey()
        enableLaunchAtLoginIfNeeded()
        refreshState()
        if !CommandLine.arguments.contains("--background") {
            showControlWindow()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControlWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        globalHotKey = nil
    }

    private func configureMenu() {
        statusItem.button?.toolTip = "AI稼働モード切り替え"

        openControlItem.target = self
        toggleItem.target = self
        privilegeItem.target = self
        loginItem.target = self
        menu.addItem(openControlItem)
        menu.addItem(.separator())
        menu.addItem(stateItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)

        let shortcutItem = NSMenuItem(title: "ショートカット: ⌃⌥A（画面 / 緊急OFF）", action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)
        menu.addItem(privilegeItem)

        let refreshItem = NSMenuItem(title: "状態を更新", action: #selector(refreshFromMenu), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        refreshPrivilegeItem()
        refreshLoginItem()
    }

    private func configureGlobalHotKey() {
        globalHotKey = GlobalHotKey { [weak self] in
            self?.handleGlobalHotKey()
        }
        if globalHotKey == nil {
            showAlert(title: "ショートカットを登録できません", message: "⌃⌥Aが他のアプリで使われていないか確認してください。")
        }
    }

    private func handleGlobalHotKey() {
        refreshState()
        switch currentState.mode {
        case .on:
            toggleMode()
        case .off:
            showControlWindow()
        }
    }

    @objc private func showControlWindow() {
        refreshState()
        controlWindowController.show()
    }

    @objc private func refreshFromMenu() {
        refreshState()
    }

    private func refreshState() {
        currentState = PowerController.read()

        switch currentState.mode {
        case .on:
            statusItem.button?.title = currentState.onACPower ? "AI ON" : "AI ON ⚠︎"
            stateItem.title = currentState.onACPower
                ? "状態: ON（蓋を閉じても継続）"
                : "状態: ON（バッテリー注意）"
            toggleItem.title = "通常スリープに戻す（OFF）"
        case .off:
            statusItem.button?.title = "AI OFF"
            stateItem.title = "状態: OFF（通常スリープ）"
            toggleItem.title = "AI稼働モードにする（ON）"
        }

        refreshLoginItem()
        refreshPrivilegeItem()
        controlWindowController.update(currentState)
    }

    @objc private func toggleMode() {
        let enabling = currentState.mode == .off
        if enabling && !currentState.onACPower {
            showAlert(
                title: "電源アダプタが必要です",
                message: "安全のため、AI稼働モードは電源アダプタ接続中だけONにできます。"
            )
            return
        }

        do {
            try PowerController.setSleepDisabled(enabling)
            refreshState()

            let expectedMode: ShellMode = enabling ? .on : .off
            guard currentState.mode == expectedMode else {
                showAlert(title: "切り替えを確認できません", message: "設定状態を確認して、もう一度お試しください。")
                return
            }
        } catch ControllerError.cancelled {
            refreshState()
        } catch {
            showAlert(title: "切り替えに失敗しました", message: error.localizedDescription)
            refreshState()
        }
    }

    @objc private func togglePrivilegeMode() {
        if PrivilegedToggleManager.isInstalled {
            guard confirm(
                title: "パスワード省略を解除しますか？",
                message: "解除後は、ON/OFFのたびにmacOSの管理者確認が表示されます。",
                button: "解除"
            ) else { return }
            do {
                try PrivilegedToggleManager.uninstall()
            } catch PrivilegeError.cancelled {
                return
            } catch {
                showAlert(title: "解除できませんでした", message: error.localizedDescription)
            }
        } else {
            guard confirm(
                title: "初回だけ権限設定しますか？",
                message: "このアプリに許可するのは、スリープ禁止をON/OFFする2つのpmsetコマンドだけです。設定時に一度だけパスワードが必要です。",
                button: "設定"
            ) else { return }
            do {
                try PrivilegedToggleManager.install()
            } catch PrivilegeError.cancelled {
                return
            } catch {
                showAlert(title: "設定できませんでした", message: error.localizedDescription)
            }
        }
        refreshPrivilegeItem()
    }

    private func refreshPrivilegeItem() {
        privilegeItem.title = PrivilegedToggleManager.isInstalled
            ? "パスワード省略: 設定済み（解除…）"
            : "パスワード省略を設定…"
    }

    @objc private func toggleLoginItem() {
        do {
            if LaunchAgentManager.isEnabled {
                try LaunchAgentManager.disable()
            } else {
                try LaunchAgentManager.enable()
            }
        } catch {
            showAlert(
                title: "ログイン項目を変更できません",
                message: error.localizedDescription
            )
        }
        refreshLoginItem()
    }

    private func enableLaunchAtLoginIfNeeded() {
        try? LaunchAgentManager.ensureCurrent()
        refreshLoginItem()
    }

    private func refreshLoginItem() {
        loginItem.state = LaunchAgentManager.isEnabled ? .on : .off
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func confirm(title: String, message: String, button: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: "キャンセル")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
