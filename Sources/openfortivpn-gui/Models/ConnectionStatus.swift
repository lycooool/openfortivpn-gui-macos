import SwiftUI

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting(String)
    case connected(since: Date?)
    case disconnecting
    case error(VpnError)

    var isBusy: Bool {
        switch self {
        case .connecting, .disconnecting: return true
        default: return false
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .disconnected: return L("未連線")
        case .connecting(let message): return message.isEmpty ? L("連線中…") : message
        case .connected: return L("已連線")
        case .disconnecting: return L("斷線中…")
        case .error(let err): return String(format: L("錯誤：%@"), err.localizedDescription)
        }
    }

    var tintColor: Color {
        switch self {
        case .connected: return .green
        case .connecting, .disconnecting: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }

    /// AppKit auto-templates (forces monochrome) NSImage-based menu-bar status
    /// items regardless of SwiftUI-level color hints, so the tray icon
    /// differentiates status by shape instead of color — the native macOS
    /// convention for menu-bar items anyway. Shield-family symbols echo the
    /// app icon (lock.shield.fill) so the tray reads as "this app" at a glance.
    var menuBarSymbolName: String {
        switch self {
        case .disconnected: return "xmark.shield"
        case .connecting, .disconnecting: return "shield.lefthalf.filled"
        case .connected: return "checkmark.shield.fill"
        case .error: return "exclamationmark.shield.fill"
        }
    }
}
