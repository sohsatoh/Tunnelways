import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            AppStatusPane()
                .tabItem {
                    Label("App Status Check", systemImage: "app")
                }
            WifiStatusPane()
                .tabItem {
                    Label("Wi-Fi Status Check", systemImage: "wifi")
                }
            VPNSettingsPane()
                .tabItem {
                    Label("VPN", systemImage: "network")
                }
        }
        .padding(20)
        .frame(minWidth: 300, minHeight: 200)
        .onWillDisappear {
            print("Settigs closed")
            let center = NotificationCenter.default
            let settingsChangedNotification = Notification.Name("jp.soh.Tunnelways.settingsChanged")
            center.post(name: settingsChangedNotification, object: nil)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SettingsStore())
    }
}
