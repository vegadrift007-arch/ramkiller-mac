import Foundation
import Darwin

final class CPUService {
    private struct CoreTicks {
        var user: UInt32 = 0
        var system: UInt32 = 0
        var nice: UInt32 = 0
        var idle: UInt32 = 0
    }
    private var prev: [CoreTicks] = []

    func cpuUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfoRaw: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                     &numCPUs, &cpuInfoRaw, &numCPUInfo)
        guard kr == KERN_SUCCESS, let cpuInfoRaw else { return 0 }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: cpuInfoRaw),
                          vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<Int32>.size))
        }

        let n = Int(numCPUs)
        var current = [CoreTicks](repeating: CoreTicks(), count: n)
        for i in 0..<n {
            let base = i * Int(CPU_STATE_MAX)
            current[i] = CoreTicks(
                user:   UInt32(bitPattern: cpuInfoRaw[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: cpuInfoRaw[base + Int(CPU_STATE_SYSTEM)]),
                nice:   UInt32(bitPattern: cpuInfoRaw[base + Int(CPU_STATE_NICE)]),
                idle:   UInt32(bitPattern: cpuInfoRaw[base + Int(CPU_STATE_IDLE)])
            )
        }

        var totalUsed: Double = 0
        var totalAll:  Double = 0

        if prev.count == n {
            for i in 0..<n {
                let dUser   = Double(current[i].user   &- prev[i].user)
                let dSystem = Double(current[i].system &- prev[i].system)
                let dNice   = Double(current[i].nice   &- prev[i].nice)
                let dIdle   = Double(current[i].idle   &- prev[i].idle)
                let used    = dUser + dSystem + dNice
                let total   = used + dIdle
                totalUsed += used
                totalAll  += total
            }
        }

        prev = current
        return totalAll > 0 ? min(100, (totalUsed / totalAll) * 100) : 0
    }
}
