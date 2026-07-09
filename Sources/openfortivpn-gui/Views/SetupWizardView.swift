import SwiftUI

struct SetupWizardView: View {
    @Environment(VpnManager.self) private var vpnManager
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("設定 openfortivpn-gui")
                .font(.title2)
                .bold()
            Text("openfortivpn 需要系統管理員權限才能建立 VPN 通道並設定路由。點下面的按鈕會跳出一次 macOS 的密碼授權框，授權一次之後每次連線都不會再問。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)

            Button(busy ? "等待授權中…" : "Grant Access") {
                grant()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(busy)

            if let errorMessage {
                VStack(spacing: 8) {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                        .textSelection(.enabled)
                    Button("重試") { grant() }
                        .disabled(busy)
                }
                .padding(.top, 8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func grant() {
        busy = true
        errorMessage = nil
        Task {
            let err = await vpnManager.grantPrivilegeAccess()
            errorMessage = err?.localizedDescription
            busy = false
        }
    }
}
