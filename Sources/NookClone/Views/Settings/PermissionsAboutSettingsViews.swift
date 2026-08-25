import AppKit
import AVFoundation
import CoreLocation
import EventKit
import SwiftUI

struct PermissionsSettingsView: View {
    let environment: AppEnvironment

    var body: some View {
        SettingsDetailContainer(title: "Permissions", subtitle: "Only affected widgets degrade when access is denied") {
            SettingsCard {
                permissionRow("Calendar", state: calendarPermissionText, allowed: environment.calendarService.permissionState == .fullAccess) {
                    if environment.calendarService.permissionState == .notDetermined {
                        Task { await environment.calendarService.requestAccessAndRefresh() }
                    } else { environment.calendarService.openSystemSettings() }
                }
                permissionRow("Reminders", state: remindersPermissionText, allowed: environment.reminderService.permissionState == .fullAccess) {
                    if environment.reminderService.permissionState == .notDetermined {
                        Task { await environment.reminderService.requestAccessAndRefresh(maximum: environment.settings.maximumReminders, selectedListIdentifiers: environment.settings.selectedReminderListIdentifiers) }
                    } else { environment.reminderService.openSystemSettings() }
                }
                permissionRow("Camera", state: cameraPermissionText, allowed: environment.cameraService.permissionState == .authorized) {
                    if environment.cameraService.permissionState == .notDetermined { Task { await environment.cameraService.start(); environment.cameraService.stop() } }
                    else { openPrivacy("Privacy_Camera") }
                }
                permissionRow("Location", state: locationPermissionText, allowed: environment.weatherService.locationState == .authorized) {
                    if environment.weatherService.locationState == .notDetermined { environment.weatherService.requestLocationAccess() }
                    else { environment.weatherService.openSystemSettings() }
                }
                permissionRow("Accessibility", state: environment.windowLayoutService.isAccessibilityTrusted ? "Allowed" : "Denied", allowed: environment.windowLayoutService.isAccessibilityTrusted) {
                    environment.windowLayoutService.requestPermission()
                }
                permissionRow("Automation", state: automationPermissionText, allowed: environment.automationPermissionService.state == .allowed) {
                    if environment.automationPermissionService.state == .notDetermined || environment.automationPermissionService.state == .targetNotRunning {
                        Task { await environment.automationPermissionService.requestPermission() }
                    } else { openPrivacy("Privacy_Automation") }
                }
            }
            Text("System media uses runtime-loaded MediaRemote private API with Apple Music automation fallback.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task { await refreshPermissions() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshPermissions() }
        }
    }

    private func permissionRow(_ name: String, state: String, allowed: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: allowed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(allowed ? .green : .orange)
            Text(LocalizedStringKey(name))
            Spacer()
            Text(LocalizedStringKey(state)).font(.caption).foregroundStyle(.secondary)
            if !allowed {
                let canRequest = state == "Not requested" || state == "Music is not running"
                Button(canRequest ? "Request Permission" : "Open System Settings", action: action).controlSize(.small)
            }
        }
    }

    private func openPrivacy(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
    }

    private var calendarPermissionText: String {
        switch environment.calendarService.permissionState {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .fullAccess: "Full access"
        }
    }

    private var cameraPermissionText: String {
        switch environment.cameraService.permissionState {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Allowed"
        case .unavailable: "No camera"
        }
    }

    private var remindersPermissionText: String {
        switch environment.reminderService.permissionState {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .fullAccess: "Full access"
        }
    }

    private var locationPermissionText: String {
        switch environment.weatherService.locationState {
        case .notDetermined: "Not requested"
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        }
    }

    private var automationPermissionText: String {
        switch environment.automationPermissionService.state {
        case .notDetermined: "Not requested"
        case .allowed: "Allowed"
        case .denied: "Denied"
        case .targetNotRunning: "Music is not running"
        case .unavailable: "Unavailable"
        }
    }

    private func refreshPermissions() async {
        environment.calendarService.refreshPermission()
        environment.reminderService.refreshPermission()
        environment.cameraService.refreshPermission()
        environment.weatherService.refreshPermission()
        environment.windowLayoutService.refreshPermission()
        await environment.automationPermissionService.refresh()
    }
}

struct AboutSettingsView: View {
    let settings: SettingsStore

    var body: some View {
        SettingsDetailContainer(title: "About", subtitle: "Dynamic Nook") {
            SettingsCard {
                HStack(spacing: 16) {
                    Image(systemName: "rectangle.topthird.inset.filled")
                        .font(.system(size: 42))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Dynamic Nook").font(.title2.bold())
                        Text("Version 1.0.5")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Independent native macOS notch utility")
                            .foregroundStyle(.secondary)
                        Text("macOS 14.6+").font(.caption)
                    }
                }
                Button("Reset Settings") { settings.reset() }
            }
        }
    }
}
