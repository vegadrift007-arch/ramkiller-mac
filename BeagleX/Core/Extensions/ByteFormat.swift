import Foundation

public enum ByteFormat {
    public static func gb(_ b: Int64) -> String {
        let gb = Double(b) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gb)
    }

    public static func mb(_ b: Int64) -> String {
        let mb = Double(b) / (1024 * 1024)
        return String(format: "%.0f MB", mb)
    }

    public static func auto(_ b: Int64) -> String {
        if b >= 1024 * 1024 * 1024 { return gb(b) }
        if b >= 1024 * 1024 { return mb(b) }
        return "\(b / 1024) KB"
    }
}
