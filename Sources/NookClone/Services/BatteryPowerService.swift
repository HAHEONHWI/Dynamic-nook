import Foundation
import IOKit.ps
import Observation

struct BatteryPowerSnapshot: Equatable, Sendable {
    let percent: Int
    let isCharging: Bool
    let isOnAC: Bool
    let timeRemainingMinutes: Int?
    let cycleCount: Int?
    let health: String?
}

@MainActor
@Observable
final class BatteryPowerService {
    private(set) var snapshot: BatteryPowerSnapshot?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init() {
        refresh()
        ticker = Task { [weak self] in
            while !Task.isCancelled { try? await Task.sleep(for: .seconds(30)); self?.refresh() }
        }
    }
    deinit { ticker?.cancel() }

    func refresh() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let data = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else { snapshot = nil; return }
        let current = data[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maximum = data[kIOPSMaxCapacityKey] as? Int ?? 100
        let minutes = data[kIOPSTimeToEmptyKey] as? Int
        snapshot = BatteryPowerSnapshot(
            percent: maximum > 0 ? Int(Double(current) / Double(maximum) * 100) : 0,
            isCharging: data[kIOPSIsChargingKey] as? Bool ?? false,
            isOnAC: (data[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue,
            timeRemainingMinutes: minutes.flatMap { $0 >= 0 ? $0 : nil },
            cycleCount: data["Cycle Count"] as? Int,
            health: data[kIOPSBatteryHealthKey] as? String
        )
    }
}
