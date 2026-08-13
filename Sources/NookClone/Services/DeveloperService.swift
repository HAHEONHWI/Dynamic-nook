import Foundation
import Observation

struct DeveloperSnapshot: Equatable, Sendable {
    let repositoryName: String
    let branch: String
    let changedFiles: Int
    let lastCommit: String
    let listeningPorts: [Int]
}

struct GitHubContributionDay: Identifiable, Equatable, Sendable {
    let date: String
    let level: Int
    var id: String { date }
}

struct GitHubDeveloperSnapshot: Equatable, Sendable {
    let username: String
    let displayName: String
    let publicRepositories: Int
    let followers: Int
    let contributionCount: Int?
    let contributionDays: [GitHubContributionDay]
    var profileURL: URL { URL(string: "https://github.com/\(username)")! }
}

private struct GitHubUserResponse: Decodable {
    let login: String
    let name: String?
    let publicRepos: Int
    let followers: Int

    enum CodingKeys: String, CodingKey {
        case login, name, followers
        case publicRepos = "public_repos"
    }
}

@MainActor
@Observable
final class DeveloperService {
    private(set) var snapshot: DeveloperSnapshot?
    private(set) var githubSnapshot: GitHubDeveloperSnapshot?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private let runner = ProcessRunner()

    func refresh(repositoryPath: String, githubUsername: String = "") async {
        isLoading = true
        defer { isLoading = false }

        let path = NSString(string: repositoryPath).expandingTildeInPath
        let hasRepository = !path.isEmpty && FileManager.default.fileExists(atPath: path)
        snapshot = hasRepository ? await loadLocalSnapshot(path: path) : nil

        var resolvedUsername = Self.sanitizedUsername(githubUsername)
        if resolvedUsername.isEmpty, hasRepository {
            resolvedUsername = await inferredGitHubUsername(path: path)
        }
        githubSnapshot = resolvedUsername.isEmpty ? nil : await loadGitHubSnapshot(username: resolvedUsername)

        if snapshot == nil && githubSnapshot == nil {
            errorMessage = resolvedUsername.isEmpty
                ? "Choose a Git repository or enter a GitHub username in Settings."
                : "GitHub status could not be refreshed."
        } else if githubSnapshot == nil && !resolvedUsername.isEmpty {
            errorMessage = "GitHub status could not be refreshed."
        } else {
            errorMessage = nil
        }
    }

    private func loadLocalSnapshot(path: String) async -> DeveloperSnapshot? {
        do {
            async let branchResult = runner.run(executable: URL(fileURLWithPath: "/usr/bin/git"), arguments: ["-C", path, "branch", "--show-current"])
            async let statusResult = runner.run(executable: URL(fileURLWithPath: "/usr/bin/git"), arguments: ["-C", path, "status", "--porcelain"])
            async let commitResult = runner.run(executable: URL(fileURLWithPath: "/usr/bin/git"), arguments: ["-C", path, "log", "-1", "--pretty=%s"])
            async let portsResult = runner.run(executable: URL(fileURLWithPath: "/usr/sbin/lsof"), arguments: ["-nP", "-iTCP", "-sTCP:LISTEN"])
            let (branch, status, commit, ports) = try await (branchResult, statusResult, commitResult, portsResult)
            guard branch.exitCode == 0 else { return nil }
            let portValues = Set(ports.output.split(whereSeparator: \.isNewline).compactMap { line -> Int? in
                let fields = line.split(whereSeparator: \.isWhitespace)
                guard let endpoint = fields.reversed().first(where: { $0.contains(":") }),
                      let colon = endpoint.lastIndex(of: ":") else { return nil }
                return Int(endpoint[endpoint.index(after: colon)...])
            }).sorted()
            return DeveloperSnapshot(
                repositoryName: URL(fileURLWithPath: path).lastPathComponent,
                branch: branch.output.trimmingCharacters(in: .whitespacesAndNewlines),
                changedFiles: status.output.split(whereSeparator: \.isNewline).count,
                lastCommit: commit.output.trimmingCharacters(in: .whitespacesAndNewlines),
                listeningPorts: Array(portValues.prefix(4))
            )
        } catch { return nil }
    }

    private func inferredGitHubUsername(path: String) async -> String {
        guard let result = try? await runner.run(
            executable: URL(fileURLWithPath: "/usr/bin/git"),
            arguments: ["-C", path, "remote", "get-url", "origin"]
        ), result.exitCode == 0 else { return "" }
        return Self.username(fromRemoteURL: result.output)
    }

    private func loadGitHubSnapshot(username: String) async -> GitHubDeveloperSnapshot? {
        guard let profileURL = URL(string: "https://api.github.com/users/\(username)"),
              let contributionsURL = URL(string: "https://github.com/users/\(username)/contributions") else { return nil }
        do {
            var profileRequest = URLRequest(url: profileURL)
            profileRequest.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            profileRequest.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            profileRequest.setValue("Dynamic-Nook", forHTTPHeaderField: "User-Agent")
            var contributionRequest = URLRequest(url: contributionsURL)
            contributionRequest.setValue("text/html", forHTTPHeaderField: "Accept")
            contributionRequest.setValue("en-US", forHTTPHeaderField: "Accept-Language")
            contributionRequest.setValue("Dynamic-Nook", forHTTPHeaderField: "User-Agent")

            async let profileResult = URLSession.shared.data(for: profileRequest)
            async let contributionResult = URLSession.shared.data(for: contributionRequest)
            let ((profileData, profileResponse), (contributionData, contributionResponse)) = try await (profileResult, contributionResult)
            guard (profileResponse as? HTTPURLResponse)?.statusCode == 200,
                  (contributionResponse as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let profile = try JSONDecoder().decode(GitHubUserResponse.self, from: profileData)
            let html = String(decoding: contributionData, as: UTF8.self)
            return GitHubDeveloperSnapshot(
                username: profile.login,
                displayName: profile.name ?? profile.login,
                publicRepositories: profile.publicRepos,
                followers: profile.followers,
                contributionCount: Self.parseContributionCount(html),
                contributionDays: Array(Self.parseContributionDays(html).suffix(35))
            )
        } catch { return nil }
    }

    static func sanitizedUsername(_ input: String) -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.count <= 39,
              value.range(of: #"^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$"#, options: .regularExpression) != nil else { return "" }
        return value
    }

    static func username(fromRemoteURL input: String) -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [#"github\.com[:/]([^/]+)/[^/]+?(?:\.git)?$"#]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
                  let range = Range(match.range(at: 1), in: value) else { continue }
            return sanitizedUsername(String(value[range]))
        }
        return ""
    }

    static func parseContributionDays(_ html: String) -> [GitHubContributionDay] {
        let pattern = "<[^>]*data-date=\\\"([^\\\"]+)\\\"[^>]*data-level=\\\"([0-4])\\\"[^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            guard let dateRange = Range(match.range(at: 1), in: html),
                  let levelRange = Range(match.range(at: 2), in: html),
                  let level = Int(html[levelRange]) else { return nil }
            return GitHubContributionDay(date: String(html[dateRange]), level: level)
        }.sorted { $0.date < $1.date }
    }

    static func parseContributionCount(_ html: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"([0-9,]+)\s+contributions?\s+in\s+the\s+last\s+year"#, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return Int(html[range].replacingOccurrences(of: ",", with: ""))
    }
}
