import SwiftUI

struct WiFiControlsView: View {
    @ObservedObject var wifi: WiFiController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Wi-Fi", systemImage: wifi.poweredOn == false ? "wifi.slash" : "wifi")
                Spacer()
                if let poweredOn = wifi.poweredOn {
                    Toggle("Wi-Fi", isOn: Binding(get: { poweredOn }, set: { wifi.setPower($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small).disabled(wifi.isBusy)
                } else {
                    Text("Unavailable").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button { SystemSettings.open(.wifi) } label: {
                HStack {
                    Text("Connect to a network…")
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(.secondary)
            if let error = wifi.errorMessage {
                Text("\(error) You can also change Wi-Fi in System Settings.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.font(.callout)
            .onAppear { wifi.refresh() }
    }
}
