import AppKit
import CoreServices
import Observation

enum AutomationPermissionState: Sendable {
    case notDetermined
    case allowed
    case denied
    case targetNotRunning
    case unavailable
}

@MainActor
@Observable
final class AutomationPermissionService {
    private(set) var state: AutomationPermissionState = .notDetermined

    func refresh() async {
        state = await Self.permission(askUser: false)
    }

    func requestPermission() async {
        if !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.apple.Music" }) {
            _ = try? await NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: "/System/Applications/Music.app"),
                configuration: NSWorkspace.OpenConfiguration()
            )
            try? await Task.sleep(for: .seconds(1))
        }
        state = await Self.permission(askUser: true)
    }

    private nonisolated static func permission(askUser: Bool) async -> AutomationPermissionState {
        await Task.detached(priority: .utility) {
            let bundleID = "com.apple.Music"
            var target = AEAddressDesc()
            let creation = bundleID.withCString { pointer in
                AECreateDesc(
                    DescType(typeApplicationBundleID),
                    pointer,
                    bundleID.utf8.count,
                    &target
                )
            }
            guard creation == noErr else { return .unavailable }
            defer { AEDisposeDesc(&target) }
            let status = AEDeterminePermissionToAutomateTarget(
                &target,
                AEEventClass(typeWildCard),
                AEEventID(typeWildCard),
                askUser
            )
            switch status {
            case noErr: return .allowed
            case OSStatus(errAEEventNotPermitted): return .denied
            case OSStatus(errAEEventWouldRequireUserConsent): return .notDetermined
            case OSStatus(procNotFound): return .targetNotRunning
            default: return .unavailable
            }
        }.value
    }
}
