import Foundation

enum Constants {
    static let bundleID = "com.liyancen.openfortivpn-gui"
    static let openfortivpnBinary = "/opt/homebrew/bin/openfortivpn"
    static let sudoersPath = "/etc/sudoers.d/openfortivpn-gui"

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
