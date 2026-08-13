import SwiftUI

struct CollapsedNookView: View {
    let isPeeking: Bool

    var body: some View {
        VStack {
            Spacer()
            Capsule()
                .fill(.white.opacity(isPeeking ? 0.55 : 0.18))
                .frame(width: isPeeking ? 34 : 24, height: 3)
                .padding(.bottom, 5)
        }
        .contentShape(Rectangle())
        .accessibilityLabel("Open Nook")
        .accessibilityAddTraits(.isButton)
    }
}
