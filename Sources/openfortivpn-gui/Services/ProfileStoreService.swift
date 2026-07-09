import Foundation

/// Loads/saves `~/Library/Application Support/com.liyancen.openfortivpn-gui/profiles.json`
/// — the exact same path and JSON shape the previous Tauri/Rust version used,
/// so existing profiles keep working with zero migration code.
final class ProfileStoreService {
    func load() throws -> ProfileStore {
        guard FileManager.default.fileExists(atPath: Constants.profilesFileURL.path) else {
            return ProfileStore()
        }
        let data = try Data(contentsOf: Constants.profilesFileURL)
        return try JSONDecoder().decode(ProfileStore.self, from: data)
    }

    func save(_ store: ProfileStore) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(store)
        try data.write(to: Constants.profilesFileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Constants.profilesFileURL.path)
    }

    /// Assigns a fresh id if `profile.id` is empty, and auto-activates the
    /// profile if it's the first one ever or if there's currently no active
    /// profile — identical semantics to the previous Rust version.
    @discardableResult
    func upsert(_ profile: VpnProfile, in store: inout ProfileStore) -> VpnProfile {
        var profile = profile
        if profile.id.isEmpty {
            profile.id = UUID().uuidString
        }
        let isFirstProfile = store.profiles.isEmpty

        if let index = store.profiles.firstIndex(where: { $0.id == profile.id }) {
            store.profiles[index] = profile
        } else {
            store.profiles.append(profile)
        }

        if isFirstProfile || store.activeProfileId == nil {
            store.activeProfileId = profile.id
        }

        return profile
    }

    func delete(id: String, from store: inout ProfileStore) {
        store.profiles.removeAll { $0.id == id }
        if store.activeProfileId == id {
            store.activeProfileId = store.profiles.first?.id
        }
    }

    func setActive(id: String, in store: inout ProfileStore) throws {
        guard store.profiles.contains(where: { $0.id == id }) else {
            throw VpnError.other("No such profile.")
        }
        store.activeProfileId = id
    }
}
