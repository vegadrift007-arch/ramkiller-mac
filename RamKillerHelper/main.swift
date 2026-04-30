import Foundation

// XPC server arrives in Phase 2. For now we just log and idle.
// Helper will run as a daemon registered via SMAppService later.
NSLog("RamKillerHelper stub started — Phase 2 will fill this in")

// Run forever so launchd doesn't restart-loop us in dev tests.
RunLoop.current.run()
