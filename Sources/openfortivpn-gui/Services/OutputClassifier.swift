import Foundation

enum LineClass {
    case connected
    case authFailure
    /// Gateway TLS certificate isn't in the local whitelist. Like authFailure,
    /// this is a permanent config problem, not a transient network blip —
    /// retrying with the same untrusted cert fails identically forever.
    case certUntrusted
    case networkError
    case progress
    case other
}

/// Classifies a line of openfortivpn stdout/stderr output. Substrings
/// confirmed via a manual test run against a real gateway.
enum OutputClassifier {
    static func classify(_ line: String) -> LineClass {
        if line.contains("Tunnel is up and running.") {
            return .connected
        }
        if line.contains("Gateway certificate validation failed") {
            return .certUntrusted
        }
        if line.contains("Could not authenticate to gateway")
            || line.contains("No password given")
            || line.contains("permission_denied")
        {
            return .authFailure
        }
        if line.contains("Could not read the cookie")
            || line.contains("Failed to")
            || line.contains("failed")
            || line.contains("error")
            || line.contains("ERROR")
        {
            return .networkError
        }
        if line.contains("Connected to gateway")
            || line.contains("Authenticating")
            || line.contains("Retrieving")
            || line.contains("Got addresses")
        {
            return .progress
        }
        return .other
    }

    /// Opportunistically pulls the certificate digest out of openfortivpn's
    /// `--trusted-cert <hex>` hint line, which appears on a SEPARATE, LATER
    /// line than the "Gateway certificate validation failed" trigger line —
    /// callers must not decide the final message until the process has fully
    /// exited, or the digest scraped from this later line gets lost.
    static func extractTrustedCertDigest(_ line: String) -> String? {
        guard let range = line.range(of: "--trusted-cert") else { return nil }
        let rest = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
        let withoutEquals = rest.hasPrefix("=") ? String(rest.dropFirst()).trimmingCharacters(in: .whitespaces) : rest
        guard let token = withoutEquals.split(separator: " ").first else { return nil }
        let candidate = String(token)
        guard candidate.count >= 32, candidate.allSatisfy(\.isHexDigit) else { return nil }
        return candidate
    }
}
