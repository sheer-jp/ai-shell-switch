import AppKit

enum PrivilegedToggleManager {
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

enum PrivilegeError: LocalizedError {
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
