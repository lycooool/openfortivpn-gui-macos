import Foundation

/// Only the fields we need — Codable ignores every other key FortiClient stores
/// (there is no password-shaped field here; FortiClient's own saved passwords,
/// if any, live in its own Keychain items, which this app never touches).
struct ForticlientProfile: Decodable {
    var name: String?
    var server: String?
    var serverPort: Int?
    var user: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case server = "Server"
        case serverPort = "ServerPort"
        case user = "User"
    }
}

/// FortiClient's vpn.plist has a top-level `Profiles` dict keyed by profile
/// *name* (not a fixed schema), which static `CodingKeys` can't express —
/// hence the custom decoding via a dynamic-key helper.
struct ForticlientVpnPlist: Decodable {
    let profiles: [String: ForticlientProfile]

    private enum TopLevelKeys: String, CodingKey {
        case profiles = "Profiles"
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: TopLevelKeys.self)
        let dict = try top.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .profiles)
        var result: [String: ForticlientProfile] = [:]
        for key in dict.allKeys {
            if let profile = try? dict.decode(ForticlientProfile.self, forKey: key) {
                result[key.stringValue] = profile
            }
        }
        profiles = result
    }
}
