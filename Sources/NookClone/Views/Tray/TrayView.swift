import SwiftUI

struct TrayView: View {
    let environment: AppEnvironment

    var body: some View {
        VStack(spacing: 8) {
            trayHeader

            if environment.appStore.isDraggingFile {
                dragActions
            } else if environment.trayStore.items.isEmpty {
                emptyState
            } else {
                trayItems
            }
        }
        .foregroundStyle(.white)
    }

    private var trayHeader: some View {
        HStack(spacing: 5) {
            ForEach(environment.settings.nookPages) { page in
                Button {
                    environment.appStore.selectPage(page)
                    environment.settings.rememberNookPage(page)
                } label: {
                    Label(LocalizedStringKey(page.title), systemImage: page.systemImage)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .frame(height: 25)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.45))
            }

            Label("Tray", systemImage: "tray.full")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 25)
                .background(.white.opacity(0.14), in: Capsule())

            Spacer()

            if !environment.trayStore.items.isEmpty {
                Button("AirDrop") {
                    shareAllViaAirDrop()
                }
                .buttonStyle(.borderless)
                .disabled(!canAirDrop)
                Button("Clear") { environment.trayStore.clear() }
                    .buttonStyle(.borderless)
            }
        }
    }

    private var dragActions: some View {
        HStack(spacing: 12) {
            dropCard(
                title: "Files Tray",
                subtitle: "Keep files here temporarily",
                symbol: "tray.and.arrow.down.fill",
                color: .blue,
                dashed: true,
                targeted: environment.appStore.fileDropTarget == .tray
            )

            dropCard(
                title: "AirDrop",
                subtitle: "Send without storing",
                symbol: "airplayaudio",
                color: .teal,
                dashed: false,
                targeted: environment.appStore.fileDropTarget == .airDrop
            )
            .opacity(canAirDrop ? 1 : 0.45)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: environment.appStore.fileDropTarget)
    }

    private func dropCard(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        symbol: String,
        color: Color,
        dashed: Bool,
        targeted: Bool
    ) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(color.opacity(0.24))
            .overlay {
                if dashed {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(color.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [7]))
                }
            }
            .overlay {
                if targeted {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                }
            }
            .overlay {
                VStack(spacing: 7) {
                    Image(systemName: symbol).font(.title2)
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption2).foregroundStyle(.white.opacity(0.55))
                }
            }
            .accessibilityLabel(Text(title))
            .scaleEffect(targeted ? 1.015 : 1)
    }

    private var trayItems: some View {
        ScrollView(.horizontal, showsIndicators: environment.settings.showWidgetScrollIndicator) {
            LazyHStack(spacing: 9) {
                ForEach(environment.trayStore.items) { item in
                    TrayItemView(item: item, environment: environment)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Tray is Empty", systemImage: "tray")
                .foregroundStyle(.white)
        } description: {
            Text("Drag files from Finder onto the notch.")
                .foregroundStyle(.white.opacity(0.56))
        }
    }

    private var canAirDrop: Bool {
        environment.settings.enableAirDrop && environment.sharingService.canAirDrop
    }

    private func shareAllViaAirDrop() {
        let urls = environment.trayStore.items.filter(\.exists).map(\.url)
        guard !urls.isEmpty else { return }
        environment.liveActions.enqueue(
            LiveAction(
                icon: "airplayaudio",
                title: environment.settings.localized("Preparing AirDrop…"),
                priority: .important
            )
        )
        environment.sharingService.shareViaAirDrop(urls: urls)
    }
}
