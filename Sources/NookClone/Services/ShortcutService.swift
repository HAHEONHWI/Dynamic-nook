import Foundation
import Observation

@MainActor
@Observable
final class ShortcutService {
    private(set) var shortcuts: [ShortcutItem] = []
    private(set) var runningShortcutID: String?
    private(set) var errorMessage: String?
    private let runner: ProcessRunner

    init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    func loadShortcuts() async {
        do {
            let result = try await runner.run(
                executable: URL(fileURLWithPath: "/usr/bin/shortcuts"),
                arguments: ["list"]
            )
            guard result.exitCode == 0 else { throw ProcessRunnerError.failed(result.errorOutput) }
            shortcuts = result.output
                .split(whereSeparator: \.isNewline)
                .map { ShortcutItem(name: String($0)) }
            errorMessage = nil
        } catch {
            shortcuts = []
            errorMessage = error.localizedDescription
        }
    }

    func run(_ shortcut: ShortcutItem) async throws {
        runningShortcutID = shortcut.id
        defer { runningShortcutID = nil }
        let result = try await runner.run(
            executable: URL(fileURLWithPath: "/usr/bin/shortcuts"),
            arguments: ["run", shortcut.name]
        )
        guard result.exitCode == 0 else {
            errorMessage = result.errorOutput
            throw ProcessRunnerError.failed(result.errorOutput)
        }
        errorMessage = nil
    }
}
