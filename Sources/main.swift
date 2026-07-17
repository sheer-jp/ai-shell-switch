import AppKit
import Darwin

private enum ShellMode {
    case on
    case off
}

private struct PowerState {
    let mode: ShellMode
    let onACPower: Bool
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let stateItem = NSMenuItem(title: "状態を確認中…", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "切り替え", action: #selector(toggleMode), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "ログイン時にも起動", action: #selector(toggleLoginItem), keyEquivalent: "")
    private var timer: Timer?
    private var currentState = PowerState(mode: .off, onACPower: false)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        enableLaunchAtLoginIfNeeded()
        refreshState()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func configureMenu() {
        statusItem.button?.toolTip = "AI稼働モード切り替え"

        toggleItem.target = self
        loginItem.target = self
        menu.addItem(stateItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)

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
        refreshLoginItem()
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
