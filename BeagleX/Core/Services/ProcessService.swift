import Foundation
import Darwin

public final class ProcessService {
    public init() {}

    public func readAll() -> [ProcessReading] {
        let kinfos = listAllKinfoProcesses()
        return kinfos.map { kinfo in
            let pid = kinfo.kp_proc.p_pid
            // Try proc_pidinfo first for full RSS data (only works for own user)
            if let detailed = reading(for: pid) { return detailed }
            // Fallback: minimal data from kinfo_proc (works for all processes)
            return readingFromKinfo(kinfo)
        }
    }

    public func topByRSS(limit: Int) -> [ProcessReading] {
        readAll().sorted { $0.rssBytes > $1.rssBytes }.prefix(limit).map { $0 }
    }

    // MARK: - sysctl-based enumeration (works for all processes, no root needed)

    private func listAllKinfoProcesses() -> [kinfo_proc] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: Int = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return [] }
        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        var actualSize = size
        guard sysctl(&mib, UInt32(mib.count), &procs, &actualSize, nil, 0) == 0 else { return [] }
        let actualCount = actualSize / MemoryLayout<kinfo_proc>.stride
        return Array(procs.prefix(actualCount)).filter { $0.kp_proc.p_pid > 0 }
    }

    private func readingFromKinfo(_ info: kinfo_proc) -> ProcessReading {
        var info = info
        let pid = info.kp_proc.p_pid
        let name = withUnsafePointer(to: &info.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) {
                String(cString: $0)
            }
        }
        let uid = info.kp_eproc.e_ucred.cr_uid
        return ProcessReading(
            id: pid, pid: pid, name: name,
            bundleId: nil,
            executablePath: nil,
            user: userName(uid: uid),
            rssBytes: 0,                                  // unknown without privileged access
            cpuPercent: 0,
            startedAt: Date.distantPast
        )
    }

    // MARK: - libproc bridge (full data — only works for own user)

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
            cpuPercent: 0,
            startedAt: started
        )
    }

    private func executablePath(for pid: pid_t) -> String? {
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
