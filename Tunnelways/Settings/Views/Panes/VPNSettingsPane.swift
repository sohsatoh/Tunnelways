import SwiftUI

struct VPNSettingsPane: View {
    @EnvironmentObject var settings: SettingsStore
    private let vpnServices = VPNUtil.sharedInstance.getAllVPNServices()

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 30) {
                Group {
                    Toggle(
                        NSLocalizedString("ENABLE_AUTO_CONNECT", comment: ""),
                        isOn: $settings.enableAutoConnection)
                    Picker(NSLocalizedString("VPN_NAME", comment: ""), selection: $settings.vpnName)
                    {
                        ForEach(vpnServices.keys.sorted(), id: \.self) { vpnName in
                            Text(vpnName)
                        }
                    }
                }
            }
        }
    }
}

struct VPNSettingsPane_Previews: PreviewProvider {
    static var previews: some View {
        VPNSettingsPane()
            .environmentObject(SettingsStore())
    }
}
