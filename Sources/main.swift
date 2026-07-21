import AppKit
import Darwin

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
