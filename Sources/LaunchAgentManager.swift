import Darwin
import Foundation

enum LaunchAgentManager {
    private static let label = "dev.arisa.ai-shell-switch.launcher"
    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    private static var programArguments: [String] {
        ["/usr/bin/open", "-gj", Bundle.main.bundlePath, "--args", "--background"]
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func enable() throws {
        let directory = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": programArguments,
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

    static func ensureCurrent() throws {
        guard isEnabled else {
            try enable()
            return
        }
        guard installedProgramArguments() != programArguments else { return }

        _ = runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        try FileManager.default.removeItem(at: plistURL)
        try enable()
    }

    static func disable() throws {
        _ = runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    private static func installedProgramArguments() -> [String]? {
        guard let data = try? Data(contentsOf: plistURL),
              let value = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let plist = value as? [String: Any] else {
            return nil
        }
        return plist["ProgramArguments"] as? [String]
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

enum LaunchAgentError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message.isEmpty ? "ログイン時起動を登録できませんでした。" : message
        }
    }
}
