import SwiftUI

@main
struct OpenFortiVPNGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var vpnManager = VpnManager()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(vpnManager)
                .task { await vpnManager.bootstrap() }
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit openfortivpn-gui") {
                    Task { await vpnManager.quitGracefully() }
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarExtraContentView()
                .environment(vpnManager)
        } label: {
            // AppKit auto-templates (forces monochrome) NSImage-based status
            // item labels regardless of SwiftUI color hints, so status is
            // differentiated by symbol shape here, not color.
            Image(systemName: vpnManager.status.menuBarSymbolName)
        }
        .menuBarExtraStyle(.menu)
    }
}
