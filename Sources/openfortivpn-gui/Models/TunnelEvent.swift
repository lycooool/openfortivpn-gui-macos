import Foundation

enum TerminalOutcome {
    case fatal(VpnError)
    case exited(Int32)
}

enum TunnelEvent {
    case progress(String)
    case connected
    case nonFatalLog(String)
    case terminal(TerminalOutcome)
}
