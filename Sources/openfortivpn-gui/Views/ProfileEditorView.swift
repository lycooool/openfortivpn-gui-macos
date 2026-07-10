import SwiftUI

struct ProfileEditorView: View {
    @Environment(VpnManager.self) private var vpnManager
    @Environment(\.dismiss) private var dismiss

    @State private var profile: VpnProfile
    @State private var password = ""
    @State private var hasSavedPassword = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var advancedExpanded = false

    private let isNew: Bool

    init(profile: VpnProfile) {
        _profile = State(initialValue: profile)
        isNew = profile.id.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sectionBox {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                            gridRow(L("設定檔名稱")) { TextField("", text: $profile.name) }
                            gridRow("Host") { TextField("", text: $profile.host) }
                            gridRow("Port") { TextField("", text: portBinding) }
                            gridRow("Username") { TextField("", text: $profile.username) }
                            gridRow(L("Password")) {
                                VStack(alignment: .leading, spacing: 4) {
                                    SecureField("", text: $password)
                                        .textFieldStyle(.roundedBorder)
                                    if hasSavedPassword {
                                        Text(L("已儲存，留空則不變更"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            gridRow(L("Trusted cert（選填）")) { TextField("", text: optionalBinding(\.trustedCert)) }

                            // "進階選項" and "刪除此設定檔" live as rows in this
                            // same grid (not a separate box) so their label and
                            // vertical spacing line up exactly like every field
                            // above — both the label text AND the chevron toggle
                            // expansion, so there's no tiny hard-to-hit hitbox.
                            GridRow {
                                Text(L("進階選項"))
                                    .foregroundStyle(.secondary)
                                    .contentShape(Rectangle())
                                    .onTapGesture { withAnimation { advancedExpanded.toggle() } }
                                Image(systemName: advancedExpanded ? "chevron.down" : "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .contentShape(Rectangle())
                                    .onTapGesture { withAnimation { advancedExpanded.toggle() } }
                            }

                            if advancedExpanded {
                                gridRow(L("斷線時自動重新連線")) { Toggle("", isOn: $profile.autoReconnect).labelsHidden() }
                                gridRow("Set routes") { Toggle("", isOn: $profile.setRoutes).labelsHidden() }
                                gridRow("Set DNS") { Toggle("", isOn: $profile.setDns).labelsHidden() }
                                gridRow("Half-internet routes") { Toggle("", isOn: $profile.halfInternetRoutes).labelsHidden() }
                                gridRow("pppd use peer DNS") { Toggle("", isOn: $profile.pppdUsePeerdns).labelsHidden() }
                                gridRow(L("CA file（選填）")) { TextField("", text: optionalBinding(\.caFile)) }
                                gridRow(L("User cert（選填）")) { TextField("", text: optionalBinding(\.userCert)) }
                                gridRow(L("User key（選填）")) { TextField("", text: optionalBinding(\.userKey)) }
                            }

                            if !isNew {
                                gridRow(L("刪除此設定檔")) {
                                    Button(L("刪除"), role: .destructive) {
                                        showDeleteConfirm = true
                                    }
                                }
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .padding(20)
            }

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
        .frame(width: 480, height: 560)
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

    /// Every field lives in a two-column Grid (description leading, input
    /// leading in its own column right after) instead of Form's default
    /// macOS row style, which right-aligns values — this keeps every input
    /// box starting from the same indented left edge instead.
    @ViewBuilder
    private func sectionBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func gridRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
            content()
                .textFieldStyle(.roundedBorder)
                .gridColumnAlignment(.leading)
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
