import Foundation

enum PrivilegeService {
    /// `sudo -n openfortivpn --version` — succeeds with no prompt only if the
    /// sudoers.d grant is already installed and working end to end.
    static func checkGranted() async -> Bool {
        guard let result = try? await ShellRunner.run(
            "/usr/bin/sudo",
            ["-n", Constants.openfortivpnBinary, "--version"]
        ) else {
            return false
        }
        return result.exitCode == 0
    }

    static func grantAccess() async throws {
        let username = try currentValidatedUsername()
        let content = sudoersContent(username: username)

        let scriptURL = Constants.appSupportDirectory.appendingPathComponent("grant-access.sh")
        let script = """
        #!/bin/sh
        set -e
        tmp=$(mktemp /tmp/openfortivpn-gui-sudoers.XXXXXX)
        cat > "$tmp" <<'OFVPN_EOF'
        \(content)
        OFVPN_EOF
        chmod 0440 "$tmp"
        /usr/sbin/visudo -c -f "$tmp"
        /usr/bin/install -m 0440 -o root -g wheel "$tmp" \(Constants.sudoersPath)
        rm -f "$tmp"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        // Single-quoted for the shell — Application Support paths contain a
        // literal space, and this exact class of bug was hit once already.
        let escapedPath = scriptURL.path.replacingOccurrences(of: "'", with: #"'\''"#)
        let shellCommand = "/bin/sh '\(escapedPath)'"
        let appleScript = "do shell script \(appleScriptQuoted(shellCommand)) with administrator privileges"

        let result = try await ShellRunner.run("/usr/bin/osascript", ["-e", appleScript])

        guard result.exitCode == 0 else {
            if result.stderr.contains("User canceled") || result.stderr.contains("-128") {
                throw VpnError.privilegeGrantCancelled
            }
            throw VpnError.privilegeGrantFailed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        guard await checkGranted() else {
            throw VpnError.privilegeGrantFailed(
                "Setup completed but verification failed — check \(Constants.sudoersPath)"
            )
        }
    }

    private static func currentValidatedUsername() throws -> String {
        let username = NSUserName()
        let isValid = !username.isEmpty && username.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "." || $0 == "-")
        }
        guard isValid else {
            throw VpnError.privilegeGrantFailed("Unexpected username format: \(username)")
        }
        return username
    }

    private static func sudoersContent(username: String) -> String {
        let bin = Constants.openfortivpnBinary
        return """
        Cmnd_Alias OPENFORTIVPN_GUI_CONNECT = \(bin)
        Cmnd_Alias OPENFORTIVPN_GUI_STOP = /usr/bin/pkill -TERM -f \(bin), /usr/bin/pkill -KILL -f \(bin)
        Cmnd_Alias OPENFORTIVPN_GUI_CHECK = /usr/bin/pgrep -f \(bin), \(bin) --version

        \(username) ALL=(root) NOPASSWD: OPENFORTIVPN_GUI_CONNECT, OPENFORTIVPN_GUI_STOP, OPENFORTIVPN_GUI_CHECK
        """
    }

    private static func appleScriptQuoted(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
