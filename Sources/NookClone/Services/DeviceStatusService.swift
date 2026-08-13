import Foundation
import Observation

struct ConnectedDeviceItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: String
    let detail: String?
}

@MainActor
@Observable
final class DeviceStatusService {
    private(set) var devices: [ConnectedDeviceItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private let runner = ProcessRunner()

    func refresh() async {
        isLoading = true; defer { isLoading = false }
        do {
            let result = try await runner.run(executable: URL(fileURLWithPath: "/usr/sbin/system_profiler"), arguments: ["SPBluetoothDataType", "SPUSBDataType", "-json"])
            guard result.exitCode == 0, let object = try JSONSerialization.jsonObject(with: Data(result.output.utf8)) as? [String: Any] else { throw ProcessRunnerError.failed(result.errorOutput) }
            var found: [ConnectedDeviceItem] = []
            if let bluetooth = object["SPBluetoothDataType"] as? [[String: Any]] {
                for section in bluetooth {
                    for key in ["device_connected", "device_connected_not_configured"] {
                        for entry in section[key] as? [[String: Any]] ?? [] {
                            for (name, rawDetails) in entry {
                                let details = rawDetails as? [String: Any]
                                let battery = details?.first(where: { $0.key.localizedCaseInsensitiveContains("battery") })?.value as? String
                                found.append(.init(id: "bt-\(name)", name: name, kind: "Bluetooth", detail: battery))
                            }
                        }
                    }
                }
            }
            if let usb = object["SPUSBDataType"] as? [[String: Any]] { collectUSB(usb, into: &found) }
            collectRemovableVolumes(into: &found)
            devices = Array(Dictionary(grouping: found, by: \.id).compactMap { $0.value.first }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .prefix(10))
            errorMessage = nil
        } catch { devices = []; errorMessage = "Connected devices could not be refreshed." }
    }

    private func collectUSB(_ nodes: [[String: Any]], into result: inout [ConnectedDeviceItem]) {
        for node in nodes {
            if let name = node["_name"] as? String, node["bcd_device"] != nil || node["vendor_id"] != nil { result.append(.init(id: "usb-\(name)", name: name, kind: "USB", detail: nil)) }
            if let children = node["_items"] as? [[String: Any]] { collectUSB(children, into: &result) }
        }
    }

    private func collectRemovableVolumes(into result: inout [ConnectedDeviceItem]) {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeIsRemovableKey]
        for url in FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys)) ?? [] {
            guard let values = try? url.resourceValues(forKeys: keys), values.volumeIsRemovable == true else { continue }
            let name = values.volumeName ?? url.lastPathComponent
            result.append(.init(id: "disk-\(url.path)", name: name, kind: "External Disk", detail: nil))
        }
    }
}
