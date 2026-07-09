import SwiftUI

struct ImportFromFortiClientView: View {
    @Environment(VpnManager.self) private var vpnManager
    @Environment(\.dismiss) private var dismiss
    var onImport: (ForticlientProfile) -> Void

    @State private var profiles: [ForticlientProfile] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("從 FortiClient 匯入")
                .font(.headline)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else if profiles.isEmpty {
                Text("沒有找到設定檔。")
                    .foregroundStyle(.secondary)
            } else {
                List(profiles.indices, id: \.self) { index in
                    let profile = profiles[index]
                    Button {
                        onImport(profile)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(profile.name ?? "未命名")
                            Text("\(profile.server ?? "")\(profile.serverPort.map { ":\($0)" } ?? "")｜\(profile.user ?? "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("關閉") { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 420, height: 360)
        .onAppear { load() }
    }

    private func load() {
        do {
            profiles = try vpnManager.discoverForticlientProfiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
