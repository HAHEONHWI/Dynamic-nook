import Foundation

struct CodexUsageSnapshot: Equatable, Sendable {
    let usedTokens: Int
    let contextWindow: Int
    let remainingTokens: Int
    let weeklyUsedPercent: Double?
    let updatedAt: Date?

    var usedFraction: Double {
        guard contextWindow > 0 else { return 0 }
        return min(max(Double(usedTokens) / Double(contextWindow), 0), 1)
    }
}

enum CodexUsageParser {
    private struct Event: Decodable {
        let timestamp: String?
        let payload: Payload?
    }

    private struct Payload: Decodable {
        let type: String
        let info: Info?
        let rateLimits: RateLimits?
    }

    private struct Info: Decodable {
        let lastTokenUsage: TokenUsage?
        let modelContextWindow: Int?
    }

    private struct TokenUsage: Decodable {
        let totalTokens: Int
    }

    private struct RateLimits: Decodable {
        let primary: RateLimit?
    }

    private struct RateLimit: Decodable {
        let usedPercent: Double?
        let windowMinutes: Int?
    }

    static func latestSnapshot(in data: Data) -> CodexUsageSnapshot? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true).reversed() {
            guard let event = try? decoder.decode(Event.self, from: Data(line)),
                  event.payload?.type == "token_count",
                  let usedTokens = event.payload?.info?.lastTokenUsage?.totalTokens,
                  let contextWindow = event.payload?.info?.modelContextWindow,
                  contextWindow > 0 else { continue }

            let rateLimit = event.payload?.rateLimits?.primary
            let weeklyUsedPercent = rateLimit?.windowMinutes == 10_080
                ? rateLimit?.usedPercent
                : nil
            return CodexUsageSnapshot(
                usedTokens: usedTokens,
                contextWindow: contextWindow,
                remainingTokens: max(0, contextWindow - usedTokens),
                weeklyUsedPercent: weeklyUsedPercent,
                updatedAt: event.timestamp.flatMap { ISO8601DateFormatter().date(from: $0) }
            )
        }
        return nil
    }
}

actor CodexUsageService {
    private let sessionsRoot: URL
    private let tailByteCount: UInt64 = 1_048_576

    init(
        sessionsRoot: URL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".codex/sessions", directoryHint: .isDirectory)
    ) {
        self.sessionsRoot = sessionsRoot
    }

    func loadLatest() -> CodexUsageSnapshot? {
        guard let fileURL = latestSessionFile(),
              let data = readTail(of: fileURL) else { return nil }
        return CodexUsageParser.latestSnapshot(in: data)
    }

    private func latestSessionFile() -> URL? {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else { return nil }

        var latest: (url: URL, date: Date)?
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let date = values.contentModificationDate else { continue }
            if latest == nil || date > latest!.date {
                latest = (url, date)
            }
        }
        return latest?.url
    }

    private func readTail(of url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            let length = try handle.seekToEnd()
            try handle.seek(toOffset: length > tailByteCount ? length - tailByteCount : 0)
            return try handle.readToEnd()
        } catch {
            return nil
        }
    }
}
