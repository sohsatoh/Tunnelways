import Combine
import SwiftUI

enum Keys {
    static let enableAppStatusCheck = "enableAppStatusCheck"
    static let enableAutoDisconnection = "enableAutoDisconnection"
    static let applicationName = "applicationName"
    static let enableAutoConnection = "enableAutoConnection"
    static let vpnName = "vpnName"
    static let enableBypassForSSID = "enableBypassForSSID"
    static let ssid = "ssid"
}

final class SettingsStore: ObservableObject {
    private let cancellable: Cancellable
    private let defaults: UserDefaults

    let objectWillChange = PassthroughSubject<Void, Never>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Keys.enableAppStatusCheck: true,
            Keys.enableAutoDisconnection: false,
            Keys.applicationName: "Burp Suite Professional|OWASP ZAP",
            Keys.enableAutoConnection: false,
            Keys.vpnName: "VPN",
            Keys.enableBypassForSSID: false,
            Keys.ssid: "ENTER_SSID_REGEX_HERE.*",
        ])

        cancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .map { _ in () }
            .subscribe(objectWillChange)
    }

    var enableAppStatusCheck: Bool {
        set { defaults.set(newValue, forKey: Keys.enableAppStatusCheck) }
        get { defaults.bool(forKey: Keys.enableAppStatusCheck) }
    }

    var enableAutoDisconnection: Bool {
        set { defaults.set(newValue, forKey: Keys.enableAutoDisconnection) }
        get { defaults.bool(forKey: Keys.enableAutoDisconnection) }
    }

    var applicationName: String {
        set { defaults.set(newValue, forKey: Keys.applicationName) }
        get { defaults.string(forKey: Keys.applicationName)! }
    }

    var enableAutoConnection: Bool {
        set { defaults.set(newValue, forKey: Keys.enableAutoConnection) }
        get { defaults.bool(forKey: Keys.enableAutoConnection) }
    }

    var vpnName: String {
        set { defaults.set(newValue, forKey: Keys.vpnName) }
        get { defaults.string(forKey: Keys.vpnName)! }
    }

    var enableBypassForSSID: Bool {
        set { defaults.set(newValue, forKey: Keys.enableBypassForSSID) }
        get { defaults.bool(forKey: Keys.enableBypassForSSID) }
    }

    var ssid: String {
        set { defaults.set(newValue, forKey: Keys.ssid) }
        get { defaults.string(forKey: Keys.ssid)! }
    }
}
