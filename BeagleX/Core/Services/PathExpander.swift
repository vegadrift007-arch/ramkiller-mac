import Foundation

public enum PathExpander {
    public static func expand(_ path: String) -> [String] {
        let withHome = (path as NSString).expandingTildeInPath
        if withHome.contains("*") {
            return globMatches(pattern: withHome)
        }
        return [withHome]
    }

    private static func globMatches(pattern: String) -> [String] {
        var result = [String]()
        var gt = glob_t()
        let cString = (pattern as NSString).utf8String
        let rc = glob(cString, GLOB_TILDE, nil, &gt)
        defer { globfree(&gt) }
        if rc == 0 {
            for i in 0..<Int(gt.gl_pathc) {
                if let p = gt.gl_pathv[i] {
                    result.append(String(cString: p))
                }
            }
        }
        return result
    }
}
