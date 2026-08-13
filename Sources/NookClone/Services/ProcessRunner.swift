import Foundation

struct ProcessResult: Sendable {
    let output: String
    let errorOutput: String
    let exitCode: Int32
}

enum ProcessRunnerError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): message
        }
    }
}

actor ProcessRunner {
    func run(executable: URL, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errorOutput = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return ProcessResult(output: output, errorOutput: errorOutput, exitCode: process.terminationStatus)
    }
}
