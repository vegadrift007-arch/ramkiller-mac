import Foundation
import Darwin

final class NetworkService {
    struct Reading {
        let downBytesPerSec: Double
        let upBytesPerSec: Double
    }

    private var prevRecv: UInt64 = 0
    private var prevSent: UInt64 = 0
    private var prevTime: Date?

    func readCurrent() -> Reading {
        let now = Date()
        let (recv, sent) = totalBytes()

        let dt: Double = {
            guard let last = prevTime else { return 1 }
            return max(0.001, now.timeIntervalSince(last))
        }()

        let downRate = prevTime == nil ? 0.0 : max(0, Double(recv &- prevRecv) / dt)
        let upRate   = prevTime == nil ? 0.0 : max(0, Double(sent &- prevSent) / dt)

        prevRecv = recv
        prevSent = sent
        prevTime = now

        return Reading(downBytesPerSec: downRate, upBytesPerSec: upRate)
    }

    private func totalBytes() -> (recv: UInt64, sent: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var totalRecv: UInt64 = 0
        var totalSent: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            let ifa = cur.pointee
            if let addrPtr = ifa.ifa_addr, addrPtr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ifa.ifa_name)
                if !name.hasPrefix("lo"), let data = ifa.ifa_data {
                    let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                    totalRecv += UInt64(ifData.ifi_ibytes)
                    totalSent += UInt64(ifData.ifi_obytes)
                }
            }
            ptr = ifa.ifa_next
        }

        return (totalRecv, totalSent)
    }
}
