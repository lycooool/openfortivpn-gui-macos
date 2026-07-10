import AppKit
import Foundation
import Network
import Observation

/// Single shared source of truth for the whole app — both the main window's
/// views and the MenuBarExtra content read this same instance directly via
/// `@Environment`, so there's no event-bus/IPC layer needed (unlike the
/// previous Tauri version, where the Rust backend and JS frontend were
/// separate runtimes that had to be bridged via `emit`/`listen`).
@MainActor
@Observable
final class VpnManager {
    var status: ConnectionStatus = .disconnected
    var profileStore = ProfileStore()
    var privilegeGranted = false
    var recentLog: [String] = []

    private var reconnectAttempt = 0
    private var userRequestedDisconnect = false
    /// Represents the current connection attempt's lifecycle (spawn → stream
    /// → maybe backoff-sleep → recurse). connect()/disconnect() both cancel
    /// this first; every point below that mutates `status` or schedules a
    /// retry is guarded by `guard !Task.isCancelled` — the cancellation flag
    /// itself acts as a generation marker, replacing the manual counter the
    /// previous Rust version needed (Rust's spawned tasks don't auto-cancel).
    private var lifecycleTask: Task<Void, Never>?
    /// Watches the tunnel while `status` is `.connected` — the process/stream
    /// only tells us the tunnel died if openfortivpn itself notices and exits,
    /// but with no TLS/PPP keepalive configured, a network drop (Wi-Fi roam,
    /// NAT rebind, sleep/wake) can leave openfortivpn silently blocked forever
    /// on a dead socket, never emitting a terminal event. This task
    /// periodically re-probes the gateway so a real-world disconnect still
    /// flips the status instead of showing "Connected" indefinitely.
    private var healthCheckTask: Task<Void, Never>?

    private let processManager = ProcessManager()
    private let profileStoreService = ProfileStoreService()
    private let logLimit = 200
    private let healthCheckInterval: Duration = .seconds(15)
    private let healthCheckFailureThreshold = 2

    var activeProfile: VpnProfile? {
        profileStore.profiles.first { $0.id == profileStore.activeProfileId }
    }

    // MARK: - Startup

    func bootstrap() async {
        privilegeGranted = await PrivilegeService.checkGranted()
        guard privilegeGranted else { return }
        profileStore = (try? profileStoreService.load()) ?? ProfileStore()
        // Orphan detection: disconnect() never depends on a locally-held
        // process handle (it always goes through `sudo -n pkill -f ...`), so
        // this reuses the exact same disconnect path with no special-casing.
        if await processManager.detectOrphan() {
            status = .connected(since: nil)
        }
    }

    @discardableResult
    func grantPrivilegeAccess() async -> VpnError? {
        do {
            try await PrivilegeService.grantAccess()
            privilegeGranted = true
            profileStore = (try? profileStoreService.load()) ?? ProfileStore()
            return nil
        } catch let err as VpnError {
            return err
        } catch {
            return .other("\(error)")
        }
    }

    // MARK: - Connect / disconnect

    func connect() {
        lifecycleTask?.cancel()
        healthCheckTask?.cancel()
        userRequestedDisconnect = false
        reconnectAttempt = 0

        guard let profile = activeProfile else {
            status = .error(.noActiveProfile)
            return
        }

        lifecycleTask = Task { [weak self] in
            await self?.runConnectionLifecycle(profile: profile)
        }
    }

    func disconnect() async {
        userRequestedDisconnect = true
        lifecycleTask?.cancel()
        healthCheckTask?.cancel()
        status = .disconnecting
        // Cancelling the Task does NOT itself kill the underlying root-owned
        // Process or unblock a stream suspended on the tunnel's output — that
        // only happens because terminate() kills the real process, which
        // makes its pipes hit EOF, which lets ProcessManager's stream finish.
        await processManager.terminate()
        status = .disconnected
    }

    func quitGracefully() async {
        if status.isConnected || status.isBusy {
            await disconnect()
        }
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Profiles

    @discardableResult
    func saveProfile(_ profile: VpnProfile, password: String?) throws -> VpnProfile {
        var store = profileStore
        let saved = profileStoreService.upsert(profile, in: &store)
        try profileStoreService.save(store)
        profileStore = store
        if let password, !password.isEmpty {
            try KeychainService.savePassword(password, forProfile: saved.id)
        }
        return saved
    }

    func deleteProfile(id: String) throws {
        var store = profileStore
        profileStoreService.delete(id: id, from: &store)
        try profileStoreService.save(store)
        profileStore = store
        try? KeychainService.deletePassword(forProfile: id)
    }

    func setActiveProfile(id: String) throws {
        var store = profileStore
        try profileStoreService.setActive(id: id, in: &store)
        try profileStoreService.save(store)
        profileStore = store
    }

    func discoverForticlientProfiles() throws -> [ForticlientProfile] {
        try ForticlientImporter.discoverProfiles()
    }

    /// Creates a brand-new local profile from an imported FortiClient entry —
    /// host/port/username only, password always left empty. Never reads or
    /// carries over anything password-shaped from FortiClient's own storage.
    @discardableResult
    func createProfile(fromForticlient fc: ForticlientProfile) throws -> VpnProfile {
        var profile = VpnProfile.blank(name: fc.name ?? "Imported")
        profile.host = fc.server ?? ""
        if let port = fc.serverPort, port > 0, port <= Int(UInt16.max) {
            profile.port = UInt16(port)
        }
        profile.username = fc.user ?? ""
        return try saveProfile(profile, password: nil)
    }

    // MARK: - Lifecycle

    private func runConnectionLifecycle(profile: VpnProfile) async {
        guard !Task.isCancelled, !userRequestedDisconnect else { return }

        guard !profile.host.isEmpty, !profile.username.isEmpty else {
            status = .error(.incompleteProfile)
            return
        }

        let password: String
        do {
            password = try KeychainService.loadPassword(forProfile: profile.id)
        } catch {
            guard !Task.isCancelled else { return }
            status = .error(.noPasswordSaved)
            return
        }

        guard !Task.isCancelled else { return }
        status = .connecting("Starting…")

        var terminalOutcome: TerminalOutcome?
        for await event in processManager.startTunnel(profile: profile, password: password) {
            guard !Task.isCancelled else { return }
            switch event {
            case .progress(let message):
                status = .connecting(message)
            case .connected:
                reconnectAttempt = 0
                status = .connected(since: Date())
                startHealthCheck(profile: profile)
            case .nonFatalLog(let line):
                appendLog(line)
            case .terminal(let outcome):
                terminalOutcome = outcome
            }
        }
        healthCheckTask?.cancel()
        guard !Task.isCancelled else { return }

        switch terminalOutcome {
        case .fatal(let err):
            // Permanent config problems (bad credentials, untrusted cert) —
            // never auto-reconnect, retrying fails identically forever.
            status = .error(err)

        case .exited, .none:
            await scheduleReconnectOrStop(profile: profile)
        }
    }

    /// Shared by a normal process exit and a health-check-detected dead link:
    /// both land here needing the same "reconnect with backoff, unless the
    /// user asked to disconnect or the profile has auto-reconnect off" logic.
    private func scheduleReconnectOrStop(profile: VpnProfile) async {
        if userRequestedDisconnect {
            status = .disconnected
            return
        }
        guard profile.autoReconnect else {
            status = .disconnected
            return
        }

        reconnectAttempt += 1
        let shift = min(reconnectAttempt - 1, 5)
        let delay = min(60, 3 * (1 << shift))
        status = .connecting("Reconnecting in \(delay)s (attempt \(reconnectAttempt))…")

        do {
            try await Task.sleep(for: .seconds(delay))
        } catch {
            return // cancelled mid-backoff — a fresh connect()/disconnect() already owns status now
        }
        guard !Task.isCancelled, !userRequestedDisconnect else { return }
        await runConnectionLifecycle(profile: profile)
    }

    // MARK: - Health check

    private func startHealthCheck(profile: VpnProfile) {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            await self?.runHealthCheckLoop(profile: profile)
        }
    }

    private func runHealthCheckLoop(profile: VpnProfile) async {
        var consecutiveFailures = 0
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: healthCheckInterval)
            } catch {
                return
            }
            guard !Task.isCancelled, status.isConnected else { return }

            if await Self.probeGateway(host: profile.host, port: profile.port) {
                consecutiveFailures = 0
                continue
            }

            consecutiveFailures += 1
            if consecutiveFailures >= healthCheckFailureThreshold {
                await handleLinkDown(profile: profile)
                return
            }
        }
    }

    /// The tunnel's process is still running but has stopped responding —
    /// openfortivpn never noticed the network drop, so we force it: kill the
    /// stuck process ourselves (same path `disconnect()` uses) and hand off
    /// to the normal reconnect/stop decision.
    private func handleLinkDown(profile: VpnProfile) async {
        guard status.isConnected else { return }
        lifecycleTask?.cancel()
        await processManager.terminate()
        guard !Task.isCancelled else { return }

        lifecycleTask = Task { [weak self] in
            await self?.scheduleReconnectOrStop(profile: profile)
        }
    }

    /// Quick TCP reachability probe against the gateway host:port openfortivpn
    /// itself connects to — the same endpoint the live tunnel depends on, so
    /// it failing is a good proxy for "the tunnel's transport is actually dead."
    private static func probeGateway(host: String, port: UInt16) async -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)

        final class ResumeGuard: @unchecked Sendable {
            private let lock = NSLock()
            private var didResume = false
            func resumeOnce(_ body: () -> Void) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                body()
            }
        }
        let resumeGuard = ResumeGuard()

        return await withCheckedContinuation { continuation in
            let finish: @Sendable (Bool) -> Void = { result in
                resumeGuard.resumeOnce {
                    connection.cancel()
                    continuation.resume(returning: result)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                finish(false)
            }
        }
    }

    private func appendLog(_ line: String) {
        recentLog.append(line)
        if recentLog.count > logLimit {
            recentLog.removeFirst(recentLog.count - logLimit)
        }
    }
}
