import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 15) {
                Group {
                    Group {
                        Toggle(
                            NSLocalizedString("ENABLE_STATUS_CHECK", comment: ""),
                            isOn: $settings.enableAppStatusCheck)
                        Toggle(
                            NSLocalizedString("ENABLE_AUTO_DISCONNECTION", comment: ""),
                            isOn: $settings.enableAutoDisconnection)
                    }
                    Group {
                        TextField(
                            NSLocalizedString("APP_NAME_FOR_CHECK", comment: ""),
                            text: $settings.applicationName)
                    }
                }
                Divider().padding(5)
                Group {
                    Toggle(
                        NSLocalizedString("ENABLE_BYPASS_SSID", comment: ""),
                        isOn: $settings.enableBypassForSSID)
                    TextField("SSID (Regex): ", text: $settings.ssid)
                }
                Divider().padding(5)
                Group {
                    Toggle(
                        NSLocalizedString("ENABLE_AUTO_CONNECT", comment: ""),
                        isOn: $settings.enableAutoConnection)
                    Divider().padding(5)
                    TextField(NSLocalizedString("VPN_NAME", comment: ""), text: $settings.vpnName)
                }
            }
            .padding(20)
        }
        .padding(20)
        .frame(width: 625, height: 250)
        .onWillDisappear {
            print("Settigs closed")
            let center = NotificationCenter.default
            let settingsChangedNotification = Notification.Name("jp.soh.Tunnelways.settingsChanged")
            center.post(name: settingsChangedNotification, object: nil)
        }
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
            .environmentObject(SettingsStore())
    }
}
