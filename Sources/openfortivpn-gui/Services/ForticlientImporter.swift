import Foundation

enum ImportError: Error, LocalizedError {
    case fileNotFound
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "未偵測到 FortiClient。"
        case .decodeFailed(let message):
            return "讀取 FortiClient 設定失敗：\(message)"
        }
    }
}

/// Reads connection metadata (host/port/username/name) out of FortiClient's
/// own local config — never its password. FortiClient's saved passwords (if
/// any) live in its own Keychain items under its own access group, which
/// this app has no reason to and deliberately never touches.
enum ForticlientImporter {
    static let plistPath = "/Library/Application Support/Fortinet/FortiClient/conf/vpn.plist"

    static func discoverProfiles() throws -> [ForticlientProfile] {
        guard FileManager.default.fileExists(atPath: plistPath) else {
            throw ImportError.fileNotFound
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: plistPath))
        do {
            let decoded = try PropertyListDecoder().decode(ForticlientVpnPlist.self, from: data)
            return Array(decoded.profiles.values).sorted { ($0.name ?? "") < ($1.name ?? "") }
        } catch {
            throw ImportError.decodeFailed("\(error)")
        }
    }
}
