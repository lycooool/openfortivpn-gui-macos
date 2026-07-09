import Foundation

struct VpnProfile: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var host: String
    var port: UInt16
    var username: String
    var trustedCert: String?
    var setRoutes: Bool
    var setDns: Bool
    var halfInternetRoutes: Bool
    var pppdUsePeerdns: Bool
    var caFile: String?
    var userCert: String?
    var userKey: String?
    var autoReconnect: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, host, port, username
        case trustedCert = "trusted_cert"
        case setRoutes = "set_routes"
        case setDns = "set_dns"
        case halfInternetRoutes = "half_internet_routes"
        case pppdUsePeerdns = "pppd_use_peerdns"
        case caFile = "ca_file"
        case userCert = "user_cert"
        case userKey = "user_key"
        case autoReconnect = "auto_reconnect"
    }

    static func blank(name: String) -> VpnProfile {
        VpnProfile(
            id: "",
            name: name,
            host: "",
            port: 443,
            username: "",
            trustedCert: nil,
            setRoutes: true,
            setDns: true,
            halfInternetRoutes: false,
            pppdUsePeerdns: true,
            caFile: nil,
            userCert: nil,
            userKey: nil,
            autoReconnect: true
        )
    }

    /// CLI flags for openfortivpn, mirroring the previously-validated Rust implementation.
    func flagArgs() -> [String] {
        var args = [
            "--set-routes=\(setRoutes ? 1 : 0)",
            "--set-dns=\(setDns ? 1 : 0)",
            "--half-internet-routes=\(halfInternetRoutes ? 1 : 0)",
            "--pppd-use-peerdns=\(pppdUsePeerdns ? 1 : 0)",
        ]
        if let trustedCert, !trustedCert.isEmpty {
            args.append("--trusted-cert=\(trustedCert)")
        }
        if let caFile, !caFile.isEmpty {
            args.append("--ca-file=\(caFile)")
        }
        if let userCert, !userCert.isEmpty {
            args.append("--user-cert=\(userCert)")
        }
        if let userKey, !userKey.isEmpty {
            args.append("--user-key=\(userKey)")
        }
        return args
    }
}

struct ProfileStore: Codable {
    var profiles: [VpnProfile] = []
    var activeProfileId: String?

    enum CodingKeys: String, CodingKey {
        case profiles
        case activeProfileId = "active_profile_id"
    }
}
