import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class QuickActionService {
    private(set) var runningID: UUID?
    private(set) var errorMessage: String?
    private let runner = ProcessRunner()

    func run(_ action: QuickAction) async {
        guard let target = QuickActionTarget.parse(action.target) else { errorMessage = "Invalid quick action target."; return }
        runningID = action.id; defer { runningID = nil }
        switch target {
        case .url(let url), .file(let url):
            if NSWorkspace.shared.open(url) { errorMessage = nil } else { errorMessage = "The quick action could not be opened." }
        case .shell(let command):
            do {
                let result = try await runner.run(executable: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-lc", command])
                errorMessage = result.exitCode == 0 ? nil : result.errorOutput
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
