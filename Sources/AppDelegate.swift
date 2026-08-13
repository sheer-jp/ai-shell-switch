import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private let openControlItem = NSMenuItem(title: "操作画面を開く…", action: #selector(showControlWindow), keyEquivalent: "o")
    private let stateItem = NSMenuItem(title: "状態を確認中…", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "切り替え", action: #selector(toggleMode), keyEquivalent: "")
    private let privilegeItem = NSMenuItem(title: "パスワード省略を設定…", action: #selector(togglePrivilegeMode), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "ログイン時にも起動", action: #selector(toggleLoginItem), keyEquivalent: "")
    private lazy var controlWindowController = ControlWindowController(
        toggleAction: { [weak self] in self?.toggleMode() },
        refreshAction: { [weak self] in self?.refreshState() },
        restoreStatusItemAction: { [weak self] in self?.rebuildStatusItem() }
    )
    private var timer: Timer?
    private var globalHotKey: GlobalHotKey?
    private var statusItemRebuildWorkItem: DispatchWorkItem?
    private var statusItemVisibilityWorkItem: DispatchWorkItem?
    private var currentState = PowerState(mode: .off, onACPower: false)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        observeDisplayChanges()
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
        rebuildStatusItem()
        showControlWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        statusItemRebuildWorkItem?.cancel()
        statusItemVisibilityWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
        globalHotKey = nil
    }

    private func configureMenu() {
        openControlItem.target = self
        toggleItem.target = self
        privilegeItem.target = self
        loginItem.target = self
        menu.addItem(openControlItem)
        menu.addItem(.separator())
        menu.addItem(stateItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)

        let shortcutItem = NSMenuItem(title: "ショートカット: ⌃⌥A（ONとOFFを切り替え）", action: nil, keyEquivalent: "")
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
        installStatusItem()
        refreshPrivilegeItem()
        refreshLoginItem()
    }

    private func observeDisplayChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        statusItemRebuildWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.rebuildStatusItem()
        }
        statusItemRebuildWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }

    private func installStatusItem() {
        if let currentItem = statusItem {
            NSStatusBar.system.removeStatusItem(currentItem)
        }

        let newItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = newItem
        newItem.button?.imagePosition = .imageOnly
        newItem.button?.title = ""
        newItem.menu = menu
        newItem.isVisible = true
        refreshStatusIcon()
        scheduleStatusItemVisibilityAssessment()
    }

    private func rebuildStatusItem() {
        installStatusItem()
        refreshState()
    }

    private func scheduleStatusItemVisibilityAssessment() {
        statusItemVisibilityWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.enableDockFallbackIfStatusItemIsObscured()
        }
        statusItemVisibilityWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func enableDockFallbackIfStatusItemIsObscured() {
        guard !statusItemIsInsideSafeMenuBarArea() else { return }
        NSApp.setActivationPolicy(.regular)
    }

    private func statusItemIsInsideSafeMenuBarArea() -> Bool {
        guard let itemWindow = statusItem?.button?.window,
              let screen = itemWindow.screen else {
            return false
        }

        let itemFrame = itemWindow.frame
        let safeAreas = [screen.auxiliaryTopLeftArea, screen.auxiliaryTopRightArea].compactMap { $0 }
        if safeAreas.isEmpty {
            return screen.frame.contains(itemFrame)
        }
        return safeAreas.contains { $0.contains(itemFrame) }
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
        toggleMode()
    }

    @objc private func showControlWindow() {
        refreshState()
        controlWindowController.show()
    }

    @objc private func refreshFromMenu() {
        refreshState()
    }

    private func refreshState() {
        restoreStatusItemVisibility()
        currentState = PowerController.read()

        switch currentState.mode {
        case .on:
            stateItem.title = currentState.onACPower
                ? "状態: ON（蓋を閉じても継続）"
                : "状態: ON（バッテリー注意）"
            toggleItem.title = "通常スリープに戻す（OFF）"
        case .off:
            stateItem.title = "状態: OFF（通常スリープ）"
            toggleItem.title = "AI稼働モードにする（ON）"
        }

        refreshStatusIcon()
        refreshLoginItem()
        refreshPrivilegeItem()
        controlWindowController.update(currentState)
    }

    private func refreshStatusIcon() {
        let symbolName: String
        let accessibilityLabel: String

        switch currentState.mode {
        case .on where currentState.onACPower:
            symbolName = "bolt.circle.fill"
            accessibilityLabel = "AI Shell Switch: AI ON"
        case .on:
            symbolName = "exclamationmark.triangle.fill"
            accessibilityLabel = "AI Shell Switch: AI ON、バッテリー注意"
        case .off:
            symbolName = "moon.zzz"
            accessibilityLabel = "AI Shell Switch: AI OFF"
        }

        guard let button = statusItem?.button else { return }
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityLabel
        )?.withSymbolConfiguration(configuration)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = accessibilityLabel
        button.setAccessibilityLabel(accessibilityLabel)
    }

    private func restoreStatusItemVisibility() {
        // A status item can be hidden by a Command-drag or after the menu bar is
        // rebuilt while this process stays alive. Keep the control surface
        // available instead of requiring the user to restart the app.
        if statusItem == nil {
            installStatusItem()
        }
        statusItem?.isVisible = true
    }

    @objc private func toggleMode() {
        let enabling = currentState.mode == .off
        if enabling && !currentState.onACPower {
            guard confirm(
                title: "バッテリー駆動中にONにしますか？",
                message: "スリープを止めたまま忘れると、電池の消耗と発熱が進みます。できれば電源アダプタの接続をおすすめします。",
                button: "ONにする"
            ) else { return }
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
        _ = presentFront(alert)
    }

    private func confirm(title: String, message: String, button: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: "キャンセル")
        return presentFront(alert) == .alertFirstButtonReturn
    }

    // メニューバー常駐アプリのNSAlertは、そのままだと非アクティブのまま
    // 別スペースや背面に出て気づけないことがある。いま操作中の画面の
    // アクティブなスペースへ、フルスクリーン上でも最前面に表示する。
    private func presentFront(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        alert.layout()

        let window = alert.window
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2 + visible.height * 0.12
            ))
        }

        window.makeKeyAndOrderFront(nil)
        return alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
