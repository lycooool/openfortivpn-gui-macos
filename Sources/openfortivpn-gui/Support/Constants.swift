import Foundation

enum Constants {
    static let bundleID = "com.liyancen.openfortivpn-gui"
    static let sudoersPath = "/etc/sudoers.d/openfortivpn-gui"

    /// Resolved once, lazily: Homebrew installs to /opt/homebrew on Apple
    /// Silicon but /usr/local on Intel — the sudoers grant needs one fixed
    /// absolute path (that's inherent to how the security model works), so
    /// this picks whichever prefix actually has the binary on disk instead
    /// of assuming Apple Silicon.
    static let openfortivpnBinary: String = {
        let candidates = ["/opt/homebrew/bin/openfortivpn", "/usr/local/bin/openfortivpn"]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? candidates[0]
    }()

    static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var profilesFileURL: URL {
        appSupportDirectory.appendingPathComponent("profiles.json")
    }
}
