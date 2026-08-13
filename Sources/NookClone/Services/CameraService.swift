import AVFoundation
import Observation

enum CameraPermissionState: Sendable {
    case notDetermined
    case denied
    case authorized
    case unavailable
}

final class CameraSessionBox: @unchecked Sendable {
    let session = AVCaptureSession()
}

@MainActor
@Observable
final class CameraService {
    @ObservationIgnored private let box = CameraSessionBox()
    private(set) var permissionState: CameraPermissionState = .notDetermined
    private(set) var errorMessage: String?
    private(set) var isRunning = false
    private var configured = false

    var session: AVCaptureSession { box.session }

    init() {
        updatePermissionState()
    }

    func refreshPermission() { updatePermissionState() }

    func start() async {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        updatePermissionState()
        guard permissionState == .authorized else { return }

        do {
            if !configured { try configureSession() }
            let box = box
            isRunning = true
            await Task.detached(priority: .userInitiated) {
                if !box.session.isRunning { box.session.startRunning() }
            }.value
        } catch {
            errorMessage = error.localizedDescription
            isRunning = false
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        let box = box
        Task.detached(priority: .utility) {
            if box.session.isRunning { box.session.stopRunning() }
        }
    }

    private func configureSession() throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            permissionState = .unavailable
            return
        }
        let input = try AVCaptureDeviceInput(device: device)
        box.session.beginConfiguration()
        box.session.sessionPreset = .high
        defer { box.session.commitConfiguration() }
        guard box.session.canAddInput(input) else {
            throw ProcessRunnerError.failed("Camera input is unavailable.")
        }
        box.session.addInput(input)
        configured = true
        errorMessage = nil
    }

    private func updatePermissionState() {
        guard AVCaptureDevice.default(for: .video) != nil else {
            permissionState = .unavailable
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: permissionState = .notDetermined
        case .denied, .restricted: permissionState = .denied
        case .authorized: permissionState = .authorized
        @unknown default: permissionState = .denied
        }
    }
}
