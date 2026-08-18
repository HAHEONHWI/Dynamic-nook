import SwiftUI

struct NookSizePreview: View {
    let virtualWidth: Double
    let minimumWidth: Double
    let maximumWidth: Double
    let expandedWidth: Double
    let expandedHeight: Double
    let cornerRadius: Double
    let opacity: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Live size preview")
                    .font(.headline)
                Spacer()
                Text("Scaled to fit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let chartWidth = max(1, proxy.size.width - 150)
                let scale = chartWidth / 1_400

                VStack(spacing: 9) {
                    previewRow(
                        title: "Collapsed",
                        width: CGFloat(virtualWidth),
                        height: 32,
                        scale: scale,
                        chartWidth: chartWidth,
                        style: .filled
                    )
                    previewRow(
                        title: "Media minimum",
                        width: CGFloat(minimumWidth),
                        height: 52,
                        scale: scale,
                        chartWidth: chartWidth,
                        style: .minimum
                    )
                    previewRow(
                        title: "Media maximum",
                        width: CGFloat(maximumWidth),
                        height: 80,
                        scale: scale,
                        chartWidth: chartWidth,
                        style: .maximum
                    )
                    previewRow(
                        title: "Expanded",
                        width: CGFloat(expandedWidth),
                        height: CGFloat(expandedHeight),
                        scale: scale,
                        chartWidth: chartWidth,
                        style: .expanded
                    )
                }
            }
            .frame(height: 150)

            Text("Changes appear here immediately, even when the Nook is hidden.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
    }

    private func previewRow(
        title: LocalizedStringKey,
        width: CGFloat,
        height: CGFloat,
        scale: CGFloat,
        chartWidth: CGFloat,
        style: PreviewStyle
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            ZStack {
                Capsule()
                    .fill(.quaternary.opacity(0.35))
                    .frame(height: 1)

                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: min(CGFloat(cornerRadius), 14),
                    bottomTrailingRadius: min(CGFloat(cornerRadius), 14),
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(style.fill.opacity(opacity))
                .overlay {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: min(CGFloat(cornerRadius), 14),
                        bottomTrailingRadius: min(CGFloat(cornerRadius), 14),
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .stroke(style.stroke, lineWidth: style == .filled ? 0 : 1)
                }
                .frame(
                    width: max(46, width * scale),
                    height: min(30, max(13, height * scale))
                )
            }
            .frame(width: chartWidth, height: 30)

            Text("\(width, specifier: "%.0f") pt")
                .font(.caption.monospacedDigit())
                .frame(width: 58, alignment: .trailing)
        }
    }
}

private enum PreviewStyle: Equatable {
    case filled
    case minimum
    case maximum
    case expanded

    var fill: Color {
        switch self {
        case .filled: .black
        case .minimum: .blue.opacity(0.32)
        case .maximum: .indigo.opacity(0.32)
        case .expanded: .black
        }
    }

    var stroke: Color {
        switch self {
        case .filled, .expanded: .clear
        case .minimum: .blue
        case .maximum: .indigo
        }
    }
}
