import SwiftUI

struct WifiStatusPane: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 30) {
                Group {
                    Group {
                        Toggle(
                            NSLocalizedString("ENABLE_BYPASS_SSID", comment: ""),
                            isOn: $settings.enableBypassForSSID)
                        TextField("SSID (Regex): ", text: $settings.ssid)
                    }
                }
            }
        }
    }
}

struct WifiStatusPane_Previews: PreviewProvider {
    static var previews: some View {
        WifiStatusPane()
            .environmentObject(SettingsStore())
    }
}
