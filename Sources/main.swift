import AppKit
import Carbon
import Darwin

private enum ShellMode {
    case on
    case off
}

private struct PowerState {
    let mode: ShellMode
    let onACPower: Bool
}

private enum PrivilegedToggleManager {
    static let rulePath = "/private/etc/sudoers.d/ai-shell-switch"
    private static let legacyRulePath = "/private/etc/sudoers.d/dev.arisa.ai-shell-switch"
    private static let allowedCommands = [
        "/usr/bin/pmset -a disablesleep 0",
        "/usr/bin/pmset -a disablesleep 1"
    ]

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: rulePath)
    }

    static func runPasswordless(_ enabled: Bool) -> Bool {
        let value = enabled ? "1" : "0"
        let result = run(
            "/usr/bin/sudo",
            arguments: ["-n", "/usr/bin/pmset", "-a", "disablesleep", value]
        )
        return result.status == 0
    }

    static func install() throws {
        let username = NSUserName()
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard !username.isEmpty,
              username.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            throw PrivilegeError.failed("macOSのユーザー名を安全に確認できませんでした。")
        }

        let rule = "\(username) ALL=(root) NOPASSWD: \(allowedCommands.joined(separator: ", "))\n"
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dev.arisa.ai-shell-switch.\(UUID().uuidString).sudoers")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try rule.write(to: temporaryURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporaryURL.path)

        let temp = shellQuoted(temporaryURL.path)
        let destination = shellQuoted(rulePath)
        let legacyDestination = shellQuoted(legacyRulePath)
        let command = [
            "/usr/bin/grep -Eq '^[[:space:]]*(#|@)includedir[[:space:]]+(/private)?/etc/sudoers.d' /etc/sudoers",
            "/usr/sbin/visudo -cf \(temp)",
            "/bin/mkdir -p /private/etc/sudoers.d",
            "/usr/bin/install -o root -g wheel -m 0440 \(temp) \(destination)",
            "/bin/rm -f \(legacyDestination)",
            "/usr/sbin/visudo -cf /etc/sudoers"
        ].joined(separator: " && ")
        try runAsAdministrator(command)
    }

    static func uninstall() throws {
        let destination = shellQuoted(rulePath)
        let legacyDestination = shellQuoted(legacyRulePath)
        try runAsAdministrator("/bin/rm -f \(destination) \(legacyDestination) && /usr/sbin/visudo -cf /etc/sudoers")
    }

    private static func runAsAdministrator(_ command: String) throws {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)

        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int
            if number == -128 {
                throw PrivilegeError.cancelled
            }
            let message = error[NSAppleScript.errorMessage] as? String ?? "権限設定を変更できませんでした。"
            throw PrivilegeError.failed(message)
        }
        guard result != nil else {
            throw PrivilegeError.failed("権限設定を変更できませんでした。")
        }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func run(_ executable: String, arguments: [String]) -> (status: Int32, error: String) {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (1, error.localizedDescription)
        }
    }
}

private enum PrivilegeError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "管理者確認がキャンセルされました。"
        case .failed(let message):
            return message
        }
    }
}

private enum PowerController {
    static func read() -> PowerState {
        let settings = run("/usr/bin/pmset", arguments: ["-g"])
        let power = run("/usr/bin/pmset", arguments: ["-g", "ps"])
        let sleepDisabled = settings
            .split(separator: "\n")
            .contains { line in
                let fields = line.split(whereSeparator: { $0.isWhitespace })
                return fields.count >= 2 && fields[0] == "SleepDisabled" && fields[1] == "1"
            }

        return PowerState(
            mode: sleepDisabled ? .on : .off,
            onACPower: power.contains("AC Power")
        )
    }

    static func setSleepDisabled(_ enabled: Bool) throws {
        if PrivilegedToggleManager.isInstalled,
           PrivilegedToggleManager.runPasswordless(enabled) {
            return
        }

        let value = enabled ? "1" : "0"
        let source = "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)

        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int
            if number == -128 {
                throw ControllerError.cancelled
            }
            let message = error[NSAppleScript.errorMessage] as? String ?? "設定を変更できませんでした。"
            throw ControllerError.failed(message)
        }

        guard result != nil else {
            throw ControllerError.failed("設定を変更できませんでした。")
        }
    }

    private static func run(_ executable: String, arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

private enum ControllerError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "管理者確認がキャンセルされました。"
        case .failed(let message):
            return message
        }
    }
}

private enum LaunchAgentManager {
    private static let label = "dev.arisa.ai-shell-switch.launcher"
    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func enable() throws {
        let directory = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", Bundle.main.bundlePath],
            "RunAtLoad": true
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)

        let result = runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
        guard result.status == 0 else {
            try? FileManager.default.removeItem(at: plistURL)
            throw LaunchAgentError.failed(result.error)
        }
    }

    static func disable() throws {
        _ = runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    private static func runLaunchctl(_ arguments: [String]) -> (status: Int32, error: String) {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, message)
        } catch {
            return (1, error.localizedDescription)
        }
    }
}

private enum LaunchAgentError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message.isEmpty ? "ログイン時起動を登録できませんでした。" : message
        }
    }
}

private final class GlobalHotKey {
    private static let signature: OSType = 0x41495357 // AISW
    private let identifier: UInt32 = 1
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init?(action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let instance = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                var receivedID = EventHotKeyID(signature: 0, id: 0)
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &receivedID
                )
                guard parameterStatus == noErr, receivedID.id == instance.identifier else {
                    return OSStatus(eventNotHandledErr)
                }
                DispatchQueue.main.async { instance.action() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard handlerStatus == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_A),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let stateItem = NSMenuItem(title: "状態を確認中…", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "切り替え", action: #selector(toggleMode), keyEquivalent: "")
    private let privilegeItem = NSMenuItem(title: "パスワード省略を設定…", action: #selector(togglePrivilegeMode), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "ログイン時にも起動", action: #selector(toggleLoginItem), keyEquivalent: "")
    private var timer: Timer?
    private var globalHotKey: GlobalHotKey?
    private var currentState = PowerState(mode: .off, onACPower: false)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        configureGlobalHotKey()
        enableLaunchAtLoginIfNeeded()
        refreshState()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        globalHotKey = nil
    }

    private func configureMenu() {
        statusItem.button?.toolTip = "AI稼働モード切り替え"

        toggleItem.target = self
        privilegeItem.target = self
        loginItem.target = self
        menu.addItem(stateItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)

        let shortcutItem = NSMenuItem(title: "ショートカット: ⌃⌥A", action: nil, keyEquivalent: "")
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
            self?.toggleMode()
        }
        if globalHotKey == nil {
            showAlert(title: "ショートカットを登録できません", message: "⌃⌥Aが他のアプリで使われていないか確認してください。")
        }
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
        guard !LaunchAgentManager.isEnabled else { return }
        try? LaunchAgentManager.enable()
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

if CommandLine.arguments.contains("--install-passwordless") {
    let commandApplication = NSApplication.shared
    commandApplication.setActivationPolicy(.accessory)
    commandApplication.activate(ignoringOtherApps: true)
    do {
        try PrivilegedToggleManager.install()
        print("passwordless-rule: installed")
        exit(EXIT_SUCCESS)
    } catch {
        fputs("passwordless-rule: \(error.localizedDescription)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

if CommandLine.arguments.contains("--uninstall-passwordless") {
    let commandApplication = NSApplication.shared
    commandApplication.setActivationPolicy(.accessory)
    commandApplication.activate(ignoringOtherApps: true)
    do {
        try PrivilegedToggleManager.uninstall()
        print("passwordless-rule: removed")
        exit(EXIT_SUCCESS)
    } catch {
        fputs("passwordless-rule: \(error.localizedDescription)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

if CommandLine.arguments.contains("--passwordless-status") {
    print(PrivilegedToggleManager.isInstalled ? "passwordless-rule: installed" : "passwordless-rule: not-installed")
    exit(PrivilegedToggleManager.isInstalled ? EXIT_SUCCESS : EXIT_FAILURE)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
