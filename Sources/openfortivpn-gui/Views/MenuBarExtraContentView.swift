import SwiftUI

struct MenuBarExtraContentView: View {
    @Environment(VpnManager.self) private var vpnManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(vpnManager.status.label)

        if let activeProfile = vpnManager.activeProfile {
            Text(activeProfile.name)
        }

        Divider()

        if vpnManager.status.isConnected {
            Button(L("斷線")) {
                Task { await vpnManager.disconnect() }
            }
        } else {
            Button(L("連線")) {
                vpnManager.connect()
            }
            .disabled(vpnManager.status.isBusy || vpnManager.profileStore.profiles.isEmpty)
        }

        Button(L("開啟視窗")) {
            openWindow(id: "main")
        }

        Divider()

        Button(L("結束 openfortivpn-gui")) {
            Task { await vpnManager.quitGracefully() }
        }
    }
}
