import SwiftUI

struct NookRootView: View {
    let environment: AppEnvironment
    let onHover: (Bool) -> Void
    let onEscape: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            panelShape
                .fill(Color.black.opacity(environment.settings.opacity))

            content
                .padding(.horizontal, environment.appStore.nookState.isFullyExpanded ? 14 : 0)
                .padding(.bottom, environment.appStore.nookState.isFullyExpanded ? 12 : 0)
                .padding(.top, environment.appStore.nookState.isFullyExpanded ? 27 : 0)
        }
        .contentShape(Rectangle())
        .clipShape(panelShape)
        .onHover(perform: onHover)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.escape) {
            onEscape()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            environment.appStore.selectAdjacentWidget(offset: -1, enabled: environment.settings.enabledWidgets)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            environment.appStore.selectAdjacentWidget(offset: 1, enabled: environment.settings.enabledWidgets)
            return .handled
        }
        .animation(
            NookMotion.animation(speed: environment.settings.animationSpeed, reduceMotion: reduceMotion),
            value: environment.appStore.nookState
        )
        .environment(\.locale, environment.settings.appLanguage.locale)
        .task {
            while !Task.isCancelled {
                await environment.mediaStore.refresh()
                try? await Task.sleep(for: AppConstants.mediaRefreshInterval)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !environment.licenseStore.isLicensed {
            switch environment.appStore.nookState {
            case .collapsed, .peeking:
                CollapsedNookView(isPeeking: environment.appStore.nookState == .peeking)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            case .expanded, .tray:
                LicenseActivationNookView(environment: environment)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        } else if environment.appStore.nookState == .collapsed,
           let action = environment.liveActions.currentAction {
            LiveActionView(action: action)
        } else if (environment.appStore.nookState == .collapsed || environment.appStore.nookState == .peeking),
                  environment.settings.showMediaIsland,
                  !environment.appStore.isMediaIslandManuallyHidden,
                  let media = environment.mediaStore.info {
            CompactMediaIslandView(
                info: media,
                store: environment.mediaStore,
                isPeeking: environment.appStore.nookState == .peeking,
                onInteraction: { environment.panelController?.keepMediaControlsOpen() },
                onCollapse: { environment.panelController?.collapseMediaPreview() }
            )
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                )
            )
        } else {
            switch environment.appStore.nookState {
            case .collapsed, .peeking:
                CollapsedNookView(isPeeking: environment.appStore.nookState == .peeking)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            case .expanded:
                ExpandedNookView(environment: environment)
                    .transition(.opacity.combined(with: .scale(scale: 0.975, anchor: .top)))
            case .tray:
                TrayView(environment: environment)
                    .transition(.opacity.combined(with: .scale(scale: 0.975, anchor: .top)))
            }
        }
    }

    private var panelShape: UnevenRoundedRectangle {
        let radius: CGFloat = switch environment.appStore.nookState {
        case .collapsed: 12
        case .peeking: 18
        case .expanded, .tray: environment.settings.cornerRadius
        }
        return UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }
}
