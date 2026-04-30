import Foundation

/// XPC protocol bridging app → helper.
@objc public protocol HelperProtocol {
    /// Helper version, used by app to detect stale installs.
    func helperVersion(reply: @escaping (String) -> Void)

    /// Execute a JSON-encoded `HelperCommand`. Reply is JSON-encoded `HelperResult`.
    func execute(commandData: Data, reply: @escaping (Data) -> Void)
}
