import Foundation
import Darwin

public final class ProcessService {
    public init() {}

    public func readAll() -> [ProcessReading] {
        let pids = listPIDs()
        return pids.compactMap { reading(for: $0) }
    }

    public func topByRSS(limit: Int) -> [ProcessReading] {
        readAll().sorted { $0.rssBytes > $1.rssBytes }.prefix(limit).map { $0 }
    }

    // MARK: - libproc bridge

    private func listPIDs() -> [pid_t] {
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }
        let count = Int(bufferSize) / MemoryLayout<pid_t>.stride
        var pids = [pid_t](repeating: 0, count: count)
        let written = pids.withUnsafeMutableBufferPointer {
            proc_listallpids($0.baseAddress, Int32($0.count * MemoryLayout<pid_t>.stride))
        }
        guard written > 0 else { return [] }
        return Array(pids.prefix(Int(written) / MemoryLayout<pid_t>.stride)).filter { $0 > 0 }
    }

    private func reading(for pid: pid_t) -> ProcessReading? {
        var taskInfo = proc_taskallinfo()
        let n = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskallinfo>.stride))
        guard n == MemoryLayout<proc_taskallinfo>.stride else { return nil }

        let rss = Int64(taskInfo.ptinfo.pti_resident_size)
        let name = withUnsafePointer(to: &taskInfo.pbsd.pbi_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { String(cString: $0) }
        }
        let startSec = TimeInterval(taskInfo.pbsd.pbi_start_tvsec)
        let started = Date(timeIntervalSince1970: startSec)
        let cpu = cpuPercent(for: pid)

        let path = executablePath(for: pid)
        let user = userName(uid: taskInfo.pbsd.pbi_uid)

        return ProcessReading(
            id: pid,
            pid: pid,
            name: name,
            bundleId: nil,
            executablePath: path,
            user: user,
            rssBytes: rss,
            cpuPercent: cpu,
            startedAt: started
        )
    }

    private func cpuPercent(for pid: pid_t) -> Double {
        // Cumulative CPU is available; "percent" requires deltas.
        // Phase 1 reports 0; revisit in Phase 2 if Smart Kill banner needs it.
        return 0
    }

    private func executablePath(for pid: pid_t) -> String? {
        // PROC_PIDPATHINFO_MAXSIZE is MAXPATHLEN*4 = 4096; constant not exposed in Swift.
        var buffer = [CChar](repeating: 0, count: 4096)
        let n = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard n > 0 else { return nil }
        return String(cString: buffer)
    }

    private func userName(uid: UInt32) -> String {
        guard let pwd = getpwuid(uid_t(uid)), let cName = pwd.pointee.pw_name else { return "?" }
        return String(cString: cName)
    }
}
