import AppKit

/// The one AppKit touchpoint needed: there's no pure-SwiftUI scene modifier
/// (as of macOS 13–15) for "don't terminate when the last window closes."
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
