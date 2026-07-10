import AppKit
import SwiftUI

struct ConnectionView: View {
    @Environment(VpnManager.self) private var vpnManager
    @State private var copiedDigest = false
    @State private var editingProfile: VpnProfile?
    @State private var showImportSheet = false

    var body: some View {
        // The controls block is centered within the FULL window bounds, and the
        // status/error section is an .overlay — overlays are a purely visual
        // layer that don't participate in the parent's layout sizing, so no
        // matter how tall the error/digest content below gets, it can never
        // push or shrink the centered controls above it (a plain sibling
        // Spacer-based layout, tried before this, does get squeezed by growing
        // content since both Spacers share the shrinkage).
        VStack(spacing: 16) {
            if vpnManager.profileStore.profiles.isEmpty {
                Text(L("尚未設定任何連線。"))
                    .foregroundStyle(.secondary)
            } else {
                Picker(L("設定檔"), selection: activeProfileBinding) {
                    ForEach(vpnManager.profileStore.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
                .disabled(vpnManager.status.isConnected || vpnManager.status.isBusy)
                .overlay(alignment: .trailing) {
                    Button {
                        if let current = currentProfile {
                            editingProfile = current
                        }
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .disabled(currentProfile == nil)
                    .help(L("編輯設定檔"))
                    .offset(x: 44)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(spacing: 8) {
                Button {
                    editingProfile = .blank(name: newProfileDefaultName())
                } label: {
                    Label(L("新增連線"), systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                Button {
                    showImportSheet = true
                } label: {
                    Label(L("從 FortiClient 匯入"), systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.small)
            .frame(width: 220)

            Button(connectButtonLabel) {
                toggle()
            }
            .disabled(connectButtonDisabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .overlay(alignment: .bottom) {
            statusSection
                .padding(.bottom, 20)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $editingProfile) { profile in
            ProfileEditorView(profile: profile)
        }
        .sheet(isPresented: $showImportSheet) {
            ImportFromFortiClientView { imported in
                if let created = try? vpnManager.createProfile(fromForticlient: imported) {
                    editingProfile = created
                }
                showImportSheet = false
            }
        }
    }

    /// All status text (connecting/connected/disconnected/progress messages)
    /// and error/diagnostic output (auth failures, untrusted-cert digest, etc.)
    /// renders through this one spot pinned to the bottom of the window, so it
    /// never shifts the main controls above regardless of what's showing.
    @ViewBuilder
    private var statusSection: some View {
        VStack(spacing: 8) {
            StatusIndicatorView(status: vpnManager.status)
                .font(.title3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .textSelection(.enabled)

            if case .error(let err) = vpnManager.status, case .certUntrusted(let digest?) = err {
                VStack(spacing: 8) {
                    Text(digest)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        copyToClipboard(digest)
                    } label: {
                        Label(copiedDigest ? L("已複製") : L("複製指紋"), systemImage: copiedDigest ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: 360)
            }
        }
    }

    private var currentProfile: VpnProfile? {
        vpnManager.profileStore.profiles.first { $0.id == vpnManager.profileStore.activeProfileId }
    }

    private func newProfileDefaultName() -> String {
        String(format: L("設定檔 %d"), vpnManager.profileStore.profiles.count + 1)
    }

    private var activeProfileBinding: Binding<String> {
        Binding(
            get: { vpnManager.profileStore.activeProfileId ?? vpnManager.profileStore.profiles.first?.id ?? "" },
            set: { newValue in try? vpnManager.setActiveProfile(id: newValue) }
        )
    }

    /// Connecting can genuinely hang (slow/unreachable gateway, stuck PPP
    /// negotiation, etc.) — the button must stay actionable as "取消連線"
    /// during that state, not just once fully Connected, or a stuck attempt
    /// becomes impossible to get out of from the UI.
    private var connectButtonLabel: String {
        switch vpnManager.status {
        case .connected: return L("斷線")
        case .connecting: return L("取消連線")
        case .disconnecting: return L("斷線中…")
        default: return L("連線")
        }
    }

    private var connectButtonDisabled: Bool {
        if case .disconnecting = vpnManager.status { return true }
        if case .connected = vpnManager.status { return false }
        if case .connecting = vpnManager.status { return false }
        return vpnManager.profileStore.profiles.isEmpty
    }

    private func toggle() {
        switch vpnManager.status {
        case .connected, .connecting:
            Task { await vpnManager.disconnect() }
        default:
            vpnManager.connect()
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let ok = pasteboard.setString(text, forType: .string)
        guard ok else { return }
        copiedDigest = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copiedDigest = false
        }
    }
}
