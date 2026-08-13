import AppKit
import Foundation

@MainActor
final class ClosedDisplaySleepBridge {
    private var watchdogFlag: URL?

    func enable() -> Bool {
        if Self.isSleepDisabled() { return true }

        let flag = FileManager.default.temporaryDirectory
            .appending(path: "com.dynamicnook.closed-display-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: flag.path, contents: Data()) else { return false }

        let processID = ProcessInfo.processInfo.processIdentifier
        let command = "(/usr/bin/pmset disablesleep 1 && while /bin/kill -0 \(processID) 2>/dev/null && /usr/bin/test -e \(flag.path); do /bin/sleep 2; done; /usr/bin/pmset disablesleep 0) >/dev/null 2>&1 &"
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")?
            .executeAndReturnError(&error)

        guard error == nil else {
            try? FileManager.default.removeItem(at: flag)
            return false
        }
        watchdogFlag = flag
        for _ in 0..<10 {
            if Self.isSleepDisabled() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        disable()
        return false
    }

    func disable() {
        guard let watchdogFlag else { return }
        try? FileManager.default.removeItem(at: watchdogFlag)
        self.watchdogFlag = nil
    }

    private static func isSleepDisabled() -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            return output.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
        } catch {
            return false
        }
    }
}
