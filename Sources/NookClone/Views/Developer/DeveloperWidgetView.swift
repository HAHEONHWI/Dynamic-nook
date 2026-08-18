import SwiftUI

struct DeveloperWidgetView: View {
    let service: DeveloperService
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Developer", systemImage: "terminal.fill").font(.caption.weight(.bold))
                Spacer()
                if service.isLoading { ProgressView().controlSize(.mini) }
                Button { refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain)
            }
            if settings.showCodexUsage, let codex = service.codexUsageSnapshot {
                codexStatus(codex)
            }
            if let github = service.githubSnapshot { githubStatus(github) }
            if let local = service.snapshot { localStatus(local) }
            if service.githubSnapshot == nil,
               service.snapshot == nil,
               service.codexUsageSnapshot == nil,
               !service.isLoading {
                Spacer()
                Text(LocalizedStringKey(service.errorMessage ?? "Choose a Git repository or enter a GitHub username in Settings."))
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                Spacer()
            } else if let error = service.errorMessage {
                Text(LocalizedStringKey(error)).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(1)
            }
        }
        .task(id: "\(settings.developerRepositoryPath)|\(settings.githubUsername)|\(settings.showCodexUsage)") {
            await refreshAsync()
        }
    }

    private func codexStatus(_ item: CodexUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Label("Codex context", systemImage: "brain.head.profile")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(item.remainingTokens, format: .number.notation(.compactName))
                        .font(.caption.monospacedDigit().weight(.bold))
                    Text("remaining")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: item.usedFraction)
                .tint(.cyan)
            HStack(spacing: 5) {
                Text(item.usedTokens, format: .number.notation(.compactName))
                Text("/")
                Text(item.contextWindow, format: .number.notation(.compactName))
                Spacer()
                if let percent = item.weeklyUsedPercent {
                    Text("Weekly limit")
                    Text(percent / 100, format: .percent.precision(.fractionLength(0)))
                }
            }
            .font(.system(size: 8).monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(7)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func githubStatus(_ item: GitHubDeveloperSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Link(destination: item.profileURL) {
                    Label(item.displayName, systemImage: "person.crop.circle.fill").font(.caption.weight(.semibold)).lineLimit(1)
                }.buttonStyle(.plain)
                Spacer()
                Text("@\(item.username)").font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(spacing: 10) {
                Label("\(item.publicRepositories)", systemImage: "book.closed").help("Public repositories")
                Label("\(item.followers)", systemImage: "person.2").help("Followers")
                if let count = item.contributionCount { Label("\(count)", systemImage: "square.grid.3x3.fill").help("Contributions in the last year") }
            }.font(.system(size: 9)).foregroundStyle(.secondary)
            contributionGrid(item.contributionDays)
        }
    }

    private func contributionGrid(_ days: [GitHubContributionDay]) -> some View {
        let rows = Array(repeating: GridItem(.fixed(6), spacing: 2), count: 7)
        return LazyHGrid(rows: rows, spacing: 2) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(contributionColor(day.level))
                    .frame(width: 6, height: 6)
                    .help("\(day.date) · level \(day.level)")
            }
        }.frame(height: 54, alignment: .leading)
    }

    private func localStatus(_ item: DeveloperSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Divider().overlay(.white.opacity(0.08))
            HStack {
                Text(item.repositoryName).font(.caption2.weight(.bold)).lineLimit(1)
                Spacer()
                Label(item.branch, systemImage: "arrow.triangle.branch").font(.system(size: 9)).lineLimit(1)
            }
            HStack {
                Label("\(item.changedFiles) changed", systemImage: item.changedFiles == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(item.changedFiles == 0 ? .green : .orange)
                Spacer()
                if !item.listeningPorts.isEmpty { Text("Ports \(item.listeningPorts.map(String.init).joined(separator: ", "))").foregroundStyle(.blue) }
            }.font(.system(size: 9))
            Text(item.lastCommit).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private func contributionColor(_ level: Int) -> Color {
        switch level {
        case 1: .green.opacity(0.35)
        case 2: .green.opacity(0.55)
        case 3: .green.opacity(0.75)
        case 4: .green
        default: .white.opacity(0.1)
        }
    }

    private func refresh() { Task { await refreshAsync() } }
    private func refreshAsync() async {
        await service.refresh(
            repositoryPath: settings.developerRepositoryPath,
            githubUsername: settings.githubUsername,
            includeCodexUsage: settings.showCodexUsage
        )
    }
}
