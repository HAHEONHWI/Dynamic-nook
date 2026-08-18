import AppKit
import SwiftUI

struct CompactMediaIslandView: View {
    let info: MediaInfo
    let store: MediaStore
    let isPeeking: Bool
    let onInteraction: () -> Void
    let onCollapse: () -> Void
    @State private var artworkAccent = Color.blue

    var body: some View {
        Group {
            if isPeeking {
                controls
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else {
                collapsedEdges
                    .transition(.opacity)
            }
        }
        .foregroundStyle(.white)
        .saturation(info.isPlaying ? 1 : 0.12)
        .brightness(info.isPlaying ? 0 : -0.12)
        .opacity(info.isPlaying ? 1 : 0.68)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [artworkAccent.opacity(info.isPlaying ? 0.24 : 0.08), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    if isPeeking, value.translation.height < -24 {
                        onCollapse()
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing \(info.title) by \(info.artist)")
        .task(id: info.artworkData) {
            withAnimation(.easeOut(duration: 0.45)) {
                artworkAccent = Self.averageArtworkColor(from: info.artworkData) ?? .blue
            }
        }
        .animation(.easeOut(duration: 0.3), value: info.isPlaying)
    }

    private var collapsedEdges: some View {
        HStack(spacing: 6) {
            artwork
                .frame(width: 27, height: 27)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Spacer(minLength: 0)

            AnimatedWaveformView(
                isPlaying: info.isPlaying,
                tint: artworkAccent,
                phaseSeed: info.title.hashValue
            )
                .frame(width: 25, height: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .padding(.bottom, 2)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            artwork
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: artworkAccent.opacity(info.isPlaying ? 0.5 : 0.15), radius: 8)
                .onTapGesture {
                    onInteraction()
                    store.openPlayer()
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(info.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(info.artist)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .frame(minWidth: 105, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            mediaButton("backward.fill", label: "Previous") { await store.previous() }
            mediaButton(info.isPlaying ? "pause.fill" : "play.fill", label: info.isPlaying ? "Pause" : "Play") {
                await store.togglePlayback()
            }
            mediaButton("forward.fill", label: "Next") { await store.next() }
            Button {
                onInteraction()
                store.openPlayer()
            } label: {
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .accessibilityLabel(Text("Open Player"))
        }
        .padding(.horizontal, 12)
        .padding(.top, 28)
        .padding(.bottom, 7)
    }

    private func mediaButton(
        _ symbol: String,
        label: String,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            onInteraction()
            Task { await action() }
        } label: {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(artworkAccent.opacity(0.24), in: Circle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(Text(LocalizedStringKey(label)))
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = info.artworkData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [.indigo, .purple.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
    }

    private static func averageArtworkColor(from data: Data?) -> Color? {
        guard let data,
              let bitmap = NSBitmapImageRep(data: data),
              bitmap.pixelsWide > 0,
              bitmap.pixelsHigh > 0 else { return nil }

        let columns = min(bitmap.pixelsWide, 12)
        let rows = min(bitmap.pixelsHigh, 12)
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var weight = 0.0

        for row in 0..<rows {
            for column in 0..<columns {
                let x = min(bitmap.pixelsWide - 1, column * bitmap.pixelsWide / columns)
                let y = min(bitmap.pixelsHigh - 1, row * bitmap.pixelsHigh / rows)
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let saturationWeight = 0.35 + color.saturationComponent
                red += color.redComponent * saturationWeight
                green += color.greenComponent * saturationWeight
                blue += color.blueComponent * saturationWeight
                weight += saturationWeight
            }
        }

        guard weight > 0 else { return nil }
        let sampledColor = NSColor(
            calibratedRed: red / weight,
            green: green / weight,
            blue: blue / weight,
            alpha: 1
        )
        return Color(nsColor: Self.visibleAccent(sampledColor))
    }

    private static func visibleAccent(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return .systemBlue }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        if saturation < 0.12 {
            return NSColor(calibratedWhite: max(brightness, 0.72), alpha: 1)
        }
        return NSColor(
            calibratedHue: hue,
            saturation: max(saturation, 0.46),
            brightness: max(brightness, 0.68),
            alpha: 1
        )
    }
}

private struct AnimatedWaveformView: View {
    let isPlaying: Bool
    let tint: Color
    let phaseSeed: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { context in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.82), tint],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3, height: barHeight(index: index, at: context.date))
                        .shadow(color: tint.opacity(0.48), radius: 1.5)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .opacity(isPlaying ? 1 : 0.45)
        .accessibilityHidden(true)
    }

    private func barHeight(index: Int, at date: Date) -> CGFloat {
        guard isPlaying else { return [4, 6, 8, 6, 4][index] }
        let time = date.timeIntervalSinceReferenceDate
        let seed = Double(abs(phaseSeed % 997)) / 997
        let primary = sin(time * 2.8 + Double(index) * 1.18 + seed * 4)
        let secondary = sin(time * 1.45 + Double(index) * 0.68 + seed * 7)
        let energy = min(max((primary * 0.58 + secondary * 0.42 + 1) / 2, 0), 1)
        let centerWeight = 1 - abs(Double(index) - 2) * 0.08
        return 4 + CGFloat(energy * centerWeight) * 6
    }
}
