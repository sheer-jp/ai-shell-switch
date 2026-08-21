import AppKit
import Carbon.HIToolbox

private enum ShortcutDefaultsKey {
    static let keyCode = "GlobalShortcutKeyCode"
    static let modifiers = "GlobalShortcutModifiers"
    static let label = "GlobalShortcutLabel"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private let openControlItem = NSMenuItem(title: "操作画面を開く…", action: #selector(showControlWindow), keyEquivalent: "o")
    private let stateItem = NSMenuItem(title: "状態を確認中…", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "切り替え", action: #selector(toggleMode), keyEquivalent: "")
    private let shortcutItem = NSMenuItem(title: "ショートカット: ⌃⌥⌘A（ONとOFFを切り替え）", action: nil, keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "設定…", action: #selector(showSettingsWindow), keyEquivalent: ",")
    private lazy var controlWindowController = ControlWindowController(
        toggleAction: { [weak self] in self?.toggleMode() },
        refreshAction: { [weak self] in self?.refreshState() },
        restoreStatusItemAction: { [weak self] in self?.rebuildStatusItem() },
        settingsAction: { [weak self] in self?.showSettingsWindow() }
    )
    private lazy var settingsWindowController = SettingsWindowController(
        currentShortcutLabel: { [weak self] in self?.shortcutLabel() ?? "⌃⌥⌘A" },
        changeShortcutAction: { [weak self] in self?.showShortcutRecorder() },
        resetShortcutAction: { [weak self] in self?.resetShortcutToDefault() },
        isLoginItemEnabled: { LaunchAgentManager.isEnabled },
        toggleLoginItemAction: { [weak self] in self?.toggleLoginItem() },
        isPrivilegeInstalled: { PrivilegedToggleManager.isInstalled },
        togglePrivilegeAction: { [weak self] in self?.togglePrivilegeMode() }
    )
    private var timer: Timer?
    private var globalHotKey: GlobalHotKey?
    private let hud = HudPanel()
    private var shortcutRecorderWindow: NSWindow?
    private var shortcutRecorderMonitor: Any?
    private var statusItemRebuildWorkItem: DispatchWorkItem?
    private var dockFallbackActive = false
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
            self?.reassessStatusItemPlacement()
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
        if let monitor = shortcutRecorderMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutRecorderMonitor = nil
        }
        NotificationCenter.default.removeObserver(self)
        globalHotKey = nil
    }

    private func configureMenu() {
        openControlItem.target = self
        toggleItem.target = self
        settingsItem.target = self
        menu.addItem(openControlItem)
        menu.addItem(.separator())
        menu.addItem(stateItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)

        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)

        let refreshItem = NSMenuItem(title: "状態を更新", action: #selector(refreshFromMenu), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        installStatusItem()
        refreshPrivilegeItem()
        refreshLoginItem()
        refreshShortcutLabels()
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
        if !dockFallbackActive {
            dockFallbackActive = true
            hud.show("メニューバーに空きがないため、Dockにアイコンを出しました", for: 4)
        }
    }

    // メニューバーの空き状況は変わるので、定期的に置き場所を見直す。
    // 空きが戻ったらメニューバーへ復帰する。操作中(アプリがアクティブ)の
    // 切り替えは避け、静かなタイミングだけで行う。
    private func reassessStatusItemPlacement() {
        if statusItemIsInsideSafeMenuBarArea() {
            guard dockFallbackActive, !NSApp.isActive else { return }
            dockFallbackActive = false
            NSApp.setActivationPolicy(.accessory)
            hud.show("メニューバーにアイコンが戻りました", for: 2.5)
        } else {
            enableDockFallbackIfStatusItemIsObscured()
        }
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
        globalHotKey = GlobalHotKey(
            keyCode: storedShortcutKeyCode(),
            modifiers: storedShortcutModifiers()
        ) { [weak self] in
            self?.handleGlobalHotKey()
        }
        if globalHotKey == nil {
            showAlert(
                title: "ショートカットを登録できません",
                message: "\(shortcutLabel())が他のアプリで使われていないか確認してください。"
            )
        }
    }

    private func storedShortcutKeyCode() -> UInt32 {
        let stored = UserDefaults.standard.object(forKey: ShortcutDefaultsKey.keyCode) as? Int
        return UInt32(stored ?? Int(kVK_ANSI_A))
    }

    private func storedShortcutModifiers() -> UInt32 {
        let stored = UserDefaults.standard.object(forKey: ShortcutDefaultsKey.modifiers) as? Int
        return UInt32(stored ?? Int(controlKey | optionKey | cmdKey))
    }

    private func shortcutLabel() -> String {
        UserDefaults.standard.string(forKey: ShortcutDefaultsKey.label) ?? "⌃⌥⌘A"
    }

    private func refreshShortcutLabels() {
        let label = shortcutLabel()
        shortcutItem.title = "ショートカット: \(label)（ONとOFFを切り替え）"
        controlWindowController.updateShortcutLabel(label)
        settingsWindowController.updateShortcutLabel(label)
    }

    // 押されたキーの組み合わせから、次回起動時にも復元できるよう
    // Carbonの登録形式(keyCode/modifiers)とメニュー表示用ラベルを保存する。
    // 登録に失敗した場合はUserDefaultsを書き換えず、直前の組み合わせのまま
    // ホットキーを登録し直す。
    private func applyShortcut(keyCode: UInt32, modifiers: UInt32, label: String) {
        let previousKeyCode = storedShortcutKeyCode()
        let previousModifiers = storedShortcutModifiers()

        globalHotKey = nil
        if let newHotKey = GlobalHotKey(keyCode: keyCode, modifiers: modifiers, action: { [weak self] in
            self?.handleGlobalHotKey()
        }) {
            globalHotKey = newHotKey
            let defaults = UserDefaults.standard
            defaults.set(Int(keyCode), forKey: ShortcutDefaultsKey.keyCode)
            defaults.set(Int(modifiers), forKey: ShortcutDefaultsKey.modifiers)
            defaults.set(label, forKey: ShortcutDefaultsKey.label)
            refreshShortcutLabels()
        } else {
            globalHotKey = GlobalHotKey(keyCode: previousKeyCode, modifiers: previousModifiers) { [weak self] in
                self?.handleGlobalHotKey()
            }
            showAlert(
                title: "ショートカットを登録できません",
                message: "\(label) は他のアプリで使われている可能性があります。別の組み合わせを選んでください。"
            )
        }
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        return mask
    }

    private func shortcutDisplayLabel(for event: NSEvent, flags: NSEvent.ModifierFlags) -> String {
        var symbols = ""
        if flags.contains(.control) { symbols += "⌃" }
        if flags.contains(.option) { symbols += "⌥" }
        if flags.contains(.shift) { symbols += "⇧" }
        if flags.contains(.command) { symbols += "⌘" }
        let keyChar = event.charactersIgnoringModifiers?.uppercased() ?? ""
        let keyPart = keyChar.isEmpty ? "Key\(event.keyCode)" : keyChar
        return symbols + keyPart
    }

    @objc private func showShortcutRecorder() {
        if let window = shortcutRecorderWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ショートカットを変更"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]

        let messageLabel = NSTextField(wrappingLabelWithString:
            "新しいショートカットを押してください(⌘ / ⌃ / ⌥ のいずれかを含む)。Escでキャンセル"
        )
        messageLabel.alignment = .center
        messageLabel.font = .systemFont(ofSize: 13)

        let resetButton = NSButton(
            title: "既定(⌃⌥⌘A)に戻す",
            target: self,
            action: #selector(resetShortcutToDefault)
        )
        resetButton.bezelStyle = .rounded

        let stack = NSStackView(views: [messageLabel, resetButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(stack)
        window.contentView = contentView
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            messageLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        window.center()
        shortcutRecorderWindow = window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutRecorderWindowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        shortcutRecorderMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === window else { return event }

            if event.keyCode == UInt16(kVK_Escape) {
                self.closeShortcutRecorder()
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasQualifyingModifier = flags.contains(.command) || flags.contains(.control) || flags.contains(.option)
            guard hasQualifyingModifier else { return nil }

            let modifiers = self.carbonModifiers(from: flags)
            let label = self.shortcutDisplayLabel(for: event, flags: flags)
            self.applyShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: label)
            self.closeShortcutRecorder()
            return nil
        }
    }

    @objc private func resetShortcutToDefault() {
        applyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey | optionKey | cmdKey), label: "⌃⌥⌘A")
        closeShortcutRecorder()
    }

    private func closeShortcutRecorder() {
        shortcutRecorderWindow?.close()
    }

    @objc private func shortcutRecorderWindowWillClose(_ notification: Notification) {
        if let monitor = shortcutRecorderMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutRecorderMonitor = nil
        }
        if let window = notification.object as? NSWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
        }
        shortcutRecorderWindow = nil
    }

    // ショートカット経由の電池ONは、ダイアログではなく「二度押し」で確認する。
    // ショートカットは押すたびに即切り替える。確認ダイアログは使わず、
    // 結果は毎回、埋もれないHUDパネルで知らせる(ON/OFFどちらも)。
    private func handleGlobalHotKey() {
        refreshState()
        let enabling = currentState.mode == .off
        performToggle(enabling: enabling, viaHotKey: true)

        guard currentState.mode == (enabling ? ShellMode.on : ShellMode.off) else { return }
        if enabling {
            hud.show(
                currentState.onACPower
                    ? "ONにしました。フタを閉じてもスリープしません"
                    : "ONにしました。バッテリー駆動中 — 発熱と電池残量に注意",
                for: 2.5
            )
        } else {
            hud.show("OFFにしました。いつものスリープに戻ります", for: 2)
        }
    }

    @objc private func showControlWindow() {
        refreshState()
        controlWindowController.show()
    }

    @objc private func showSettingsWindow() {
        settingsWindowController.show()
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

        performToggle(enabling: enabling)
    }

    private func performToggle(enabling: Bool, viaHotKey: Bool = false) {
        do {
            try PowerController.setSleepDisabled(enabling)
            refreshState()

            let expectedMode: ShellMode = enabling ? .on : .off
            guard currentState.mode == expectedMode else {
                if viaHotKey {
                    hud.show("切り替えを確認できませんでした。メニューバーから状態を確認してください", for: 4)
                } else {
                    showAlert(title: "切り替えを確認できません", message: "設定状態を確認して、もう一度お試しください。")
                }
                return
            }
        } catch ControllerError.cancelled {
            refreshState()
        } catch {
            if viaHotKey {
                hud.show("切り替えに失敗しました: \(error.localizedDescription)", for: 4)
            } else {
                showAlert(title: "切り替えに失敗しました", message: error.localizedDescription)
            }
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
        settingsWindowController.refreshPrivilegeState()
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
        settingsWindowController.refreshLoginItemState()
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
    // runModalは自前でウィンドウの位置と重なり順を触るため、モーダル開始
    // 直後(main queueの次のターン)にもう一度こちらの指定を適用し直す。
    private func presentFront(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        alert.layout()

        let window = alert.window
        let applyFrontPlacement = {
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

            window.orderFrontRegardless()
        }

        applyFrontPlacement()
        DispatchQueue.main.async(execute: applyFrontPlacement)
        window.makeKeyAndOrderFront(nil)
        return alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
