import SwiftUI

struct StatusIndicatorView: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.tintColor)
                .frame(width: 12, height: 12)
            Text(status.label)
        }
    }
}
