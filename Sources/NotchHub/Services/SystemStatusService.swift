import Foundation
import IOKit.ps
import Darwin
import NotchHubCore

@MainActor
final class SystemStatusService: ObservableObject {
    @Published var snapshot = SystemSnapshot()
    private var timer: Timer?
    private var prevCPUInfo: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let (battery, charging) = readBattery()
        let cpu = readCPUUsage()
        let (memUsed, memTotal) = readMemoryGB()
        snapshot.batteryPercent = battery
        snapshot.isCharging = charging
        snapshot.cpuUsagePercent = cpu
        snapshot.memoryUsedGB = memUsed
        snapshot.memoryTotalGB = memTotal

        Task.detached(priority: .utility) {
            let (vol, muted) = Self.readVolumeSync()
            await MainActor.run { [weak self] in
                self?.snapshot.volumePercent = vol
                self?.snapshot.isMuted = muted
            }
        }
    }

    func setVolume(_ percent: Int) {
        let clamped = min(100, max(0, percent))
        snapshot.volumePercent = clamped
        snapshot.isMuted = (clamped == 0)
        Task.detached(priority: .userInitiated) {
            Self.runOSAScript("set volume output volume \(clamped)")
        }
    }

    func toggleMute() {
        let nextMuted = !snapshot.isMuted
        snapshot.isMuted = nextMuted
        Task.detached(priority: .userInitiated) {
            Self.runOSAScript("set volume output muted \(nextMuted ? "true" : "false")")
        }
    }

    private func readBattery() -> (Int, Bool) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return (100, true)
        }
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let current = desc[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int,
               maxCap > 0 {
                let pct = Int(round((Double(current) / Double(maxCap)) * 100.0))
                let isCharging = (desc[kIOPSIsChargingKey as String] as? Bool) ??
                    ((desc[kIOPSPowerSourceStateKey as String] as? String) == (kIOPSACPowerValue as String))
                return (min(100, max(0, pct)), isCharging)
            }
        }
        return (100, true)
    }

    private func readCPUUsage() -> Double {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var cpuLoad = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return snapshot.cpuUsagePercent }

        let u = UInt64(cpuLoad.cpu_ticks.0)
        let s = UInt64(cpuLoad.cpu_ticks.1)
        let i = UInt64(cpuLoad.cpu_ticks.2)
        let n = UInt64(cpuLoad.cpu_ticks.3)

        defer { prevCPUInfo = (u, s, i, n) }
        guard let prev = prevCPUInfo else { return 0 }

        let du = u &- prev.user
        let ds = s &- prev.system
        let di = i &- prev.idle
        let dn = n &- prev.nice
        let total = du + ds + di + dn
        guard total > 0 else { return 0 }
        return min(100.0, max(0.0, (Double(du + ds + dn) / Double(total)) * 100.0))
    }

    private func readMemoryGB() -> (Double, Double) {
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        let totalGB = totalBytes / 1_073_741_824.0

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let res = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard res == KERN_SUCCESS else { return (0, totalGB) }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(vmStats.active_count) * pageSize
        let wired = Double(vmStats.wire_count) * pageSize
        let compressed = Double(vmStats.compressor_page_count) * pageSize
        let usedGB = (active + wired + compressed) / 1_073_741_824.0
        return (round(usedGB * 10) / 10, round(totalGB * 10) / 10)
    }

    nonisolated private static func readVolumeSync() -> (Int, Bool) {
        let out = runOSAScript("output volume of (get volume settings) & \",\" & output muted of (get volume settings)")
        let parts = out.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ",")
        guard parts.count >= 2, let vol = Int(parts[0].trimmingCharacters(in: .whitespaces)) else {
            return (50, false)
        }
        let muted = parts[1].trimmingCharacters(in: .whitespaces).lowercased() == "true"
        return (vol, muted)
    }

    @discardableResult
    nonisolated private static func runOSAScript(_ script: String) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
