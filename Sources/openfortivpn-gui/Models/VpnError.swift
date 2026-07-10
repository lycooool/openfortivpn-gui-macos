import Foundation

enum VpnError: Error, Equatable, LocalizedError {
    case certUntrusted(digest: String?)
    case authFailure
    case noActiveProfile
    case noPasswordSaved
    case incompleteProfile
    case privilegeGrantCancelled
    case privilegeGrantFailed(String)
    case other(String)

    var errorDescription: String? {
        switch self {
        case .certUntrusted(let digest):
            if digest != nil {
                return L("Gateway 使用尚未信任的憑證。若確認信任，把下面這組指紋貼到設定檔的 Trusted cert 欄位。")
            }
            return "Gateway certificate is not trusted yet. Check the Trusted cert field in this profile."
        case .authFailure:
            return "Authentication failed. Check your username/password."
        case .noActiveProfile:
            return L("沒有選擇使用中的設定檔。")
        case .noPasswordSaved:
            return "No password saved in Keychain yet."
        case .incompleteProfile:
            return "VPN profile is incomplete (host/username missing)."
        case .privilegeGrantCancelled:
            return "Setup was cancelled."
        case .privilegeGrantFailed(let message):
            return "Privilege setup failed: \(message)"
        case .other(let message):
            return message
        }
    }
}
