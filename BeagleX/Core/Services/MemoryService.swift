import Foundation
import Darwin
import MachO

public final class MemoryService {
    public init() {}

    private var lastSwapIns: UInt64 = 0
    private var lastSwapOuts: UInt64 = 0
    private var lastSampleTime: Date?

    public func readCurrent() -> MemoryReading {
        let now = Date()
        let stats = vmStatistics64()
        let pageSize = vmPageSize()

        let total = physicalMemoryBytes()

        let wired       = Int64(stats.wire_count) * Int64(pageSize)
        let active      = Int64(stats.active_count) * Int64(pageSize)
        let inactive    = Int64(stats.inactive_count) * Int64(pageSize)
        let speculative = Int64(stats.speculative_count) * Int64(pageSize)
        let compressor  = Int64(stats.compressor_page_count) * Int64(pageSize)
        let unused      = Int64(stats.free_count + stats.speculative_count) * Int64(pageSize)

        let used = total - unused

        let swapIns  = UInt64(stats.swapins)
        let swapOuts = UInt64(stats.swapouts)
        let dt: Double = {
            guard let last = lastSampleTime else { return 1 }
            return max(0.001, now.timeIntervalSince(last))
        }()
        let swapInRate  = (lastSampleTime == nil) ? 0 : Double(swapIns &- lastSwapIns) / dt
        let swapOutRate = (lastSampleTime == nil) ? 0 : Double(swapOuts &- lastSwapOuts) / dt
        lastSwapIns = swapIns
        lastSwapOuts = swapOuts
        lastSampleTime = now

        return MemoryReading(
            timestamp: now,
            totalBytes: total,
            usedBytes: used,
            unusedBytes: unused,
            wiredBytes: wired,
            activeBytes: active,
            inactiveBytes: inactive,
            speculativeBytes: speculative,
            compressorBytes: compressor,
            swapInPagesPerSec: max(0, swapInRate),
            swapOutPagesPerSec: max(0, swapOutRate),
            pressureLevel: pressureLevel()
        )
    }

    // MARK: - kernel calls

    private func physicalMemoryBytes() -> Int64 {
        var size: UInt64 = 0
        var sizeOfSize = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &size, &sizeOfSize, nil, 0) == 0 {
            return Int64(size)
        }
        return Int64(ProcessInfo.processInfo.physicalMemory)
    }

    private func vmPageSize() -> Int {
        var size: vm_size_t = 0
        host_page_size(mach_host_self(), &size)
        return Int(size)
    }

    private func vmStatistics64() -> vm_statistics64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return vm_statistics64() }
        return stats
    }

    private func pressureLevel() -> Int {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        // sysctl key: kern.memorystatus_vm_pressure_level (1=normal, 2=warn, 4=critical)
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 {
            switch level {
            case 1: return 0
            case 2: return 1
            case 4: return 2
            default: return 0
            }
        }
        return 0
    }
}
