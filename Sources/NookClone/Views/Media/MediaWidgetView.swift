import AppKit
import SwiftUI

struct MediaWidgetView: View {
    let store: MediaStore
    @State private var pendingSeek: Double?

    var body: some View {
        Group {
            if let info = store.info {
                player(info)
            } else if store.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else {
                emptyState
            }
        }
        .task { await store.refresh() }
    }

    private func player(_ info: MediaInfo) -> some View {
        HStack(spacing: 10) {
            artwork(info)
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(info.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                Text(info.artist)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                if let album = info.album, !album.isEmpty {
                    Text(album)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.38))
                        .lineLimit(1)
                }

                HStack(spacing: 15) {
                    mediaButton("backward.fill", label: "Previous") { await store.previous() }
                    mediaButton(info.isPlaying ? "pause.fill" : "play.fill", label: info.isPlaying ? "Pause" : "Play") {
                        await store.togglePlayback()
                    }
                    mediaButton("forward.fill", label: "Next") { await store.next() }
                    Spacer(minLength: 0)
                    Button { store.openPlayer() } label: {
                        if let icon = playerIcon(info.playerBundleIdentifier) {
                            Image(nsImage: icon).resizable().frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.up.forward.app")
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Open Player"))
                }

                HStack(spacing: 5) {
                    Text(info.position.clockText)
                    Slider(
                        value: Binding(
                            get: { pendingSeek ?? info.position },
                            set: { pendingSeek = $0 }
                        ),
                        in: 0...max(info.duration, 1)
                    ) { editing in
                        if !editing, let position = pendingSeek {
                            Task { await store.seek(to: position) }
                            pendingSeek = nil
                        }
                    }
                    .tint(.white)
                    Text(info.duration.clockText)
                }
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))
            }
        }
    }

    private func playerIcon(_ bundleIdentifier: String?) -> NSImage? {
        guard let bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    @ViewBuilder
    private func artwork(_ info: MediaInfo) -> some View {
        if let data = info.artworkData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [.indigo.opacity(0.8), .purple.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: 26, weight: .medium))
            }
        }
    }

    private func mediaButton(_ symbol: String, label: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 22, height: 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(label)))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing Playing", systemImage: "music.note")
                .foregroundStyle(.white)
        } description: {
            if let error = store.errorMessage {
                Text(error).foregroundStyle(.white.opacity(0.58))
            } else {
                Text("Start playback in Music, Spotify, a browser, or another system player.")
                    .foregroundStyle(.white.opacity(0.58))
            }
        } actions: {
            Button("Open Music") { store.openPlayer() }
                .buttonStyle(.bordered)
        }
    }
}
