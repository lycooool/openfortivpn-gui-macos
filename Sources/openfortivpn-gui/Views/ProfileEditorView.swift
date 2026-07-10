import SwiftUI

struct ProfileEditorView: View {
    @Environment(VpnManager.self) private var vpnManager
    @Environment(\.dismiss) private var dismiss

    @State private var profile: VpnProfile
    @State private var password = ""
    @State private var hasSavedPassword = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    private let isNew: Bool

    init(profile: VpnProfile) {
        _profile = State(initialValue: profile)
        isNew = profile.id.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(L("連線資訊")) {
                    TextField(L("設定檔名稱"), text: $profile.name)
                    TextField("Host", text: $profile.host)
                    TextField("Port", text: portBinding)
                    TextField("Username", text: $profile.username)
                    SecureField(hasSavedPassword ? L("Password（已儲存，留空則不變更）") : L("Password"), text: $password)
                    TextField(L("Trusted cert（選填）"), text: optionalBinding(\.trustedCert))
                }

                DisclosureGroup(L("進階選項")) {
                    Toggle(L("斷線時自動重新連線"), isOn: $profile.autoReconnect)
                    Toggle("Set routes", isOn: $profile.setRoutes)
                    Toggle("Set DNS", isOn: $profile.setDns)
                    Toggle("Half-internet routes", isOn: $profile.halfInternetRoutes)
                    Toggle("pppd use peer DNS", isOn: $profile.pppdUsePeerdns)
                    TextField(L("CA file（選填）"), text: optionalBinding(\.caFile))
                    TextField(L("User cert（選填）"), text: optionalBinding(\.userCert))
                    TextField(L("User key（選填）"), text: optionalBinding(\.userKey))
                }

                if !isNew {
                    Section {
                        Button(L("刪除此設定檔"), role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(L("取消")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("儲存")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 460, height: 540)
        .onAppear { refreshPasswordState() }
        .confirmationDialog(
            String(format: L("確定要刪除「%@」嗎？"), profile.name),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(L("刪除"), role: .destructive) { delete() }
            Button(L("取消"), role: .cancel) {}
        }
    }

    private func refreshPasswordState() {
        hasSavedPassword = !profile.id.isEmpty && KeychainService.hasPassword(forProfile: profile.id)
    }

    private func save() {
        errorMessage = nil
        do {
            _ = try vpnManager.saveProfile(profile, password: password.isEmpty ? nil : password)
            dismiss()
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func delete() {
        try? vpnManager.deleteProfile(id: profile.id)
        dismiss()
    }

    private var portBinding: Binding<String> {
        Binding(
            get: { String(profile.port) },
            set: { if let value = UInt16($0) { profile.port = value } }
        )
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<VpnProfile, String?>) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath] ?? "" },
            set: { profile[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }
}
