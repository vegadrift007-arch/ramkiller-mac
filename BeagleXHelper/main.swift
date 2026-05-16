import Foundation

NSLog("[helper] starting v\(HelperService.version)")

let listener = NSXPCListener(machServiceName: "com.vannaq.BeagleXHelper")
let delegate = HelperService()
listener.delegate = delegate
listener.resume()

NSLog("[helper] XPC listener resumed; entering run loop")
RunLoop.current.run()
