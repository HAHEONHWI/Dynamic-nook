import AppKit
import SwiftUI

struct MirrorWidgetView: View {
    let service: CameraService

    var body: some View {
        Group {
            switch service.permissionState {
            case .authorized:
                CameraPreviewView(session: service.session)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        Label("Mirror", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                            .font(.caption2)
                            .padding(7)
                            .background(.black.opacity(0.5), in: Capsule())
                            .padding(8)
                    }
            case .notDetermined:
                cameraUnavailable("Camera Access Required", button: "Grant Permission") {
                    Task { await service.start() }
                }
            case .denied:
                cameraUnavailable("Camera Access Denied", button: "Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
            case .unavailable:
                cameraUnavailable("No Camera Available", button: nil, action: {})
            }
        }
        .task { await service.start() }
        .onDisappear { service.stop() }
    }

    private func cameraUnavailable(
        _ title: LocalizedStringKey,
        button: LocalizedStringKey?,
        action: @escaping () -> Void
    ) -> some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: "camera.fill")
            }
            .foregroundStyle(.white)
        } description: {
            if let error = service.errorMessage {
                Text(error).foregroundStyle(.white.opacity(0.58))
            } else {
                Text("Camera access only affects Mirror.")
                    .foregroundStyle(.white.opacity(0.58))
            }
        } actions: {
            if let button { Button(action: action) { Text(button) }.buttonStyle(.bordered) }
        }
    }
}
