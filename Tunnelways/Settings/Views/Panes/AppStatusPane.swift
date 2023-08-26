import SwiftUI

struct AppStatusPane: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 30) {
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
            }
        }
    }
}

struct AppStatusPane_Previews: PreviewProvider {
    static var previews: some View {
        AppStatusPane()
            .environmentObject(SettingsStore())
    }
}
