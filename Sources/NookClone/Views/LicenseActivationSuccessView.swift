import SwiftUI

struct LicenseActivationSuccessView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringProgress = 0.02
    @State private var checkScale = 0.55
    @State private var glowVisible = false

    var body: some View {
        VStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(glowVisible ? 0.18 : 0.05))
                    .frame(width: 88, height: 88)
                    .blur(radius: glowVisible ? 3 : 0)

                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 5)
                    .frame(width: 66, height: 66)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        Color.green,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 66, height: 66)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(checkScale)
            }

            Text("Activation complete")
                .font(.title2.bold())
            Text("Dynamic Nook Pro is ready.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard !reduceMotion else {
                ringProgress = 1
                checkScale = 1
                glowVisible = true
                return
            }
            withAnimation(.smooth(duration: 0.65)) {
                ringProgress = 1
                glowVisible = true
            }
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.64)) {
                checkScale = 1
            }
        }
        .accessibilityElement(children: .combine)
    }
}
