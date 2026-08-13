import Darwin
import Foundation
import Observation

struct SystemUsageSnapshot: Equatable, Sendable {
    let cpu: Double
    let memory: Double
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    let disk: Double
    let diskUsed: UInt64
    let diskTotal: UInt64
}

enum SystemUsageMath {
    static func cpu(previous: [UInt64], current: [UInt64]) -> Double {
        guard previous.count == 4, current.count == 4 else { return 0 }
        let deltas = zip(previous, current).map { $1 >= $0 ? $1 - $0 : 0 }
        let total = deltas.reduce(0, +)
        guard total > 0 else { return 0 }
        return min(max(Double(total - deltas[Int(CPU_STATE_IDLE)]) / Double(total), 0), 1)
    }
}

@MainActor
@Observable
final class SystemMonitorService {
    private(set) var snapshot = SystemUsageSnapshot(cpu: 0, memory: 0, memoryUsed: 0, memoryTotal: 0, disk: 0, diskUsed: 0, diskTotal: 0)
    private(set) var errorMessage: String?
    @ObservationIgnored private var previousCPUTicks: [UInt64]?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(startTicker: Bool = true) {
        refresh()
        if startTicker {
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    self?.refresh()
                }
            }
        }
    }

    deinit { ticker?.cancel() }

    func refresh() {
        guard let ticks = cpuTicks(), let memory = memoryUsage(), let disk = diskUsage() else {
            errorMessage = "System usage could not be read."
            return
        }
        let cpu = previousCPUTicks.map { SystemUsageMath.cpu(previous: $0, current: ticks) } ?? snapshot.cpu
        previousCPUTicks = ticks
        snapshot = SystemUsageSnapshot(
            cpu: cpu,
            memory: memory.total > 0 ? Double(memory.used) / Double(memory.total) : 0,
            memoryUsed: memory.used,
            memoryTotal: memory.total,
            disk: disk.total > 0 ? Double(disk.used) / Double(disk.total) : 0,
            diskUsed: disk.used,
            diskTotal: disk.total
        )
        errorMessage = nil
    }

    private func cpuTicks() -> [UInt64]? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return [UInt64(info.cpu_ticks.0), UInt64(info.cpu_ticks.1), UInt64(info.cpu_ticks.2), UInt64(info.cpu_ticks.3)]
    }

    private func memoryUsage() -> (used: UInt64, total: UInt64)? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let total = ProcessInfo.processInfo.physicalMemory
        let pageSize = UInt64(getpagesize())
        let available = UInt64(stats.free_count + stats.speculative_count) * pageSize
        return (min(total, total > available ? total - available : 0), total)
    }

    private func diskUsage() -> (used: UInt64, total: UInt64)? {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let total = (attributes[.systemSize] as? NSNumber)?.uint64Value,
              let free = (attributes[.systemFreeSize] as? NSNumber)?.uint64Value else { return nil }
        return (total > free ? total - free : 0, total)
    }
}
