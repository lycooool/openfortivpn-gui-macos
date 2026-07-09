import SwiftUI

struct ContentView: View {
    @Environment(VpnManager.self) private var vpnManager

    var body: some View {
        Group {
            if vpnManager.privilegeGranted {
                ConnectionView()
            } else {
                SetupWizardView()
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }
}
