import Foundation

/// Spawns/monitors/kills the openfortivpn tunnel via `sudo -n`. Never signals
/// a PID directly — the tunnel runs as root under sudo, which the unprivileged
/// GUI process can't signal (UID mismatch), and sudo's monitor-process model
/// means a locally-held child PID isn't reliably "the" real process anyway —
/// so termination always goes through `sudo -n pkill -f <full binary path>`.
final class ProcessManager {
    func startTunnel(profile: VpnProfile, password: String) -> AsyncStream<TunnelEvent> {
        AsyncStream { continuation in
            let process = Process()

            // Wrapped in `script` to allocate a pty for openfortivpn's output.
            // Piped (non-TTY) stdout makes many C programs — including
            // openfortivpn — switch from line-buffered to fully-buffered
            // stdio. On a long-running connection that never exits (the
            // whole point of a VPN tunnel), a critical line like "Tunnel is
            // up and running." can then sit in the child's internal buffer
            // forever — the tunnel is actually fully up (routes/DNS/ppp
            // interface all configured) but the app never sees the line that
            // would flip its status to Connected. A pty makes openfortivpn
            // behave as if attached to a real terminal, restoring immediate
            // line-buffered output. `script` merges stdout+stderr into the
            // pty (matching normal terminal behavior), so only one output
            // pipe is needed below instead of separate stdout/stderr pipes.
            process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
            var scriptArgs = [
                "-q", "/dev/null",
                "/usr/bin/sudo", "-n", Constants.openfortivpnBinary,
                "\(profile.host):\(profile.port)", "-u", profile.username,
            ]
            scriptArgs.append(contentsOf: profile.flagArgs())
            process.arguments = scriptArgs
            process.environment = ProcessInfo.processInfo.environment.merging(
                ["LC_ALL": "C", "LANG": "C"]
            ) { _, new in new }

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stdoutPipe

            // fatalKind/scrapedDigest are only combined into a final VpnError
            // once the process has fully exited (see terminationHandler) —
            // the cert digest hint line arrives strictly AFTER the "validation
            // failed" trigger line, so deciding any earlier would lose it.
            let lock = NSLock()
            var fatalKind: LineClass?
            var scrapedDigest: String?

            func handleLine(_ line: String) {
                guard !line.isEmpty else { return }
                lock.lock()
                if let digest = OutputClassifier.extractTrustedCertDigest(line) {
                    scrapedDigest = digest
                }
                let classification = OutputClassifier.classify(line)
                switch classification {
                case .certUntrusted, .authFailure:
                    fatalKind = classification
                default:
                    break
                }
                lock.unlock()

                switch classification {
                case .connected:
                    continuation.yield(.connected)
                case .progress:
                    continuation.yield(.progress(line))
                case .networkError:
                    continuation.yield(.nonFatalLog(line))
                case .certUntrusted, .authFailure, .other:
                    break
                }
            }

            let readersGroup = DispatchGroup()

            func readLines(from pipe: Pipe) {
                readersGroup.enter()
                Task.detached {
                    do {
                        for try await line in pipe.fileHandleForReading.bytes.lines {
                            handleLine(line)
                        }
                    } catch {
                        // pipe closed/errored — treated the same as a clean EOF
                    }
                    readersGroup.leave()
                }
            }

            readLines(from: stdoutPipe)

            process.terminationHandler = { proc in
                readersGroup.notify(queue: .global()) {
                    lock.lock()
                    let kind = fatalKind
                    let digest = scrapedDigest
                    lock.unlock()

                    let outcome: TerminalOutcome
                    switch kind {
                    case .certUntrusted:
                        outcome = .fatal(.certUntrusted(digest: digest))
                    case .authFailure:
                        outcome = .fatal(.authFailure)
                    default:
                        outcome = .exited(proc.terminationStatus)
                    }
                    continuation.yield(.terminal(outcome))
                    continuation.finish()
                }
            }

            do {
                try process.run()
            } catch {
                continuation.yield(.terminal(.fatal(.other("Failed to launch openfortivpn: \(error.localizedDescription)"))))
                continuation.finish()
                return
            }

            // Deliberately NOT closing stdin after this write (unlike before the
            // `script`/pty wrapper was introduced). openfortivpn's password read
            // is line-terminated by the trailing "\n" — it doesn't need EOF to
            // complete. Closing immediately here raced with `script`'s own
            // internal read-and-forward-to-pty loop (an extra hop that didn't
            // exist with a direct pipe): closing our end could reach the pty as
            // an EOF signal before `script` had finished relaying the already
            // written password bytes, intermittently corrupting/dropping it —
            // confirmed by reproducing a stray EOF marker landing ahead of the
            // password in the pty's echoed output during a manual repro. The
            // pipe is cleaned up naturally when the process exits/is killed.
            if let data = "\(password)\n".data(using: .utf8) {
                try? stdinPipe.fileHandleForWriting.write(contentsOf: data)
            }
        }
    }

    func terminate() async {
        guard await isRunning() else { return }

        _ = try? await ShellRunner.run("/usr/bin/sudo", ["-n", "/usr/bin/pkill", "-TERM", "-f", Constants.openfortivpnBinary])

        for _ in 0..<10 {
            if !(await isRunning()) { break }
            try? await Task.sleep(for: .milliseconds(500))
        }

        if await isRunning() {
            _ = try? await ShellRunner.run("/usr/bin/sudo", ["-n", "/usr/bin/pkill", "-KILL", "-f", Constants.openfortivpnBinary])
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    func detectOrphan() async -> Bool {
        await isRunning()
    }

    private func isRunning() async -> Bool {
        guard let result = try? await ShellRunner.run("/usr/bin/sudo", ["-n", "/usr/bin/pgrep", "-f", Constants.openfortivpnBinary]) else {
            return false
        }
        return result.exitCode == 0
    }
}
