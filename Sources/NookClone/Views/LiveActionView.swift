import SwiftUI

struct LiveActionView: View {
    let action: LiveAction

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: action.icon)
                .font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(action.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let message = action.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.top, 5)
        .accessibilityElement(children: .combine)
    }
}
