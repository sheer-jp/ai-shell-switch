import AppKit

enum ShellMode {
    case on
    case off
}

struct PowerState {
    let mode: ShellMode
    let onACPower: Bool
}

enum PowerController {
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

enum ControllerError: LocalizedError {
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
