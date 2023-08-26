import Cocoa
import CoreWLAN
import Foundation
import Network
import SystemConfiguration

extension String {
  func matches(pattern: String) -> Bool {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
    let matches = regex.matches(in: self, range: NSRange(location: 0, length: count))
    return matches.count > 0
  }
}

class VPNUtil: NSObject {
  static let sharedInstance = VPNUtil()

  private var isAppLaunched: Bool = false
  private var isMonitorStarted: Bool = false
  private var monitor: NWPathMonitor = .init()
  private var tokens: [NSObjectProtocol] = []

  override private init() {
    print("VPNUtil init")
  }

  func registerObservers() {
    // VPN Notification
    if monitor.queue == nil {
      monitor.pathUpdateHandler = { _ in
        DispatchQueue.main.async {
          if self.isMonitorStarted {
            self.networkStatusChanged()
          }
        }
      }
    }
    monitor.start(queue: .global(qos: .background))
    isMonitorStarted = true

    let settingsStore = SettingsStore()
    let enableAppStatusCheck = settingsStore.enableAppStatusCheck

    if enableAppStatusCheck {
      let center = NSWorkspace.shared.notificationCenter
      let applicationName = settingsStore.applicationName

      // Launch Notification
      let launchToken = center.addObserver(
        forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
      ) { (notification: Notification) in
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication
        {
          if app.localizedName?.matches(pattern: applicationName) == true {
            self.isAppLaunched = true
            self.networkStatusChanged()
          }
        }
      }

      // Exit Notification
      let exitToken = center.addObserver(
        forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
      ) { (notification: Notification) in
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication
        {
          if app.localizedName?.matches(pattern: applicationName) == true {
            self.isAppLaunched = false
            self.networkStatusChanged()
          }
        }
      }
      tokens += [launchToken, exitToken]

    } else {
      // assuming the app is running
      isAppLaunched = true
    }
  }

  func unregisterObservers() {
    let center = NotificationCenter.default
    center.removeObserver(self)

    tokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    tokens.removeAll()

    monitor.cancel()
    monitor = NWPathMonitor()
  }

  private func networkStatusChanged() {
    print("networkStatusChanged")

    let settingsStore = SettingsStore()
    let enableAutoDisconnection = settingsStore.enableAutoDisconnection
    let enableBypassForSSID = settingsStore.enableBypassForSSID
    let ssid = settingsStore.ssid
    let currentSSID = getSSID()
    let shouldBypass = enableBypassForSSID && currentSSID.matches(pattern: ssid)
    let isVPNConnected = isVPNConnected()

    // send notification
    let center = NotificationCenter.default
    let notificationName = Notification.Name("jp.soh.Tunnelways.ChangeVPNRequest")
    guard
      let obj: VPNRequestType = {
        if isAppLaunched, !isVPNConnected, !shouldBypass {
          return .connectionRequest
        } else if !isAppLaunched, isVPNConnected, enableAutoDisconnection {
          return .disconnectionRequest
        }
        return nil
      }()
    else { return }
    center.post(name: notificationName, object: obj)
  }

  func getSSID() -> String {
    guard let interface = CWWiFiClient.shared().interface() else { return "" }
    let ssid = interface.ssid() ?? ""
    return ssid
  }

  func getAllVPNServices() -> [String: SCNetworkService] {
    var vpnDict: [String: SCNetworkService] = [:]

    let processName = ProcessInfo.processInfo.processName
    guard let pref = SCPreferencesCreate(kCFAllocatorDefault, processName as CFString, nil) else {
      print("ERROR: Failed to create the SCPreferences object")
      return vpnDict
    }
    guard let netServices = SCNetworkServiceCopyAll(pref) as? [SCNetworkService] else {
      print("ERROR: Failed to obtain network services")
      return vpnDict
    }
    for netService in netServices {
      if SCNetworkServiceGetEnabled(netService) {
        guard let netInf = SCNetworkServiceGetInterface(netService) else { continue }
        guard let type = SCNetworkInterfaceGetInterfaceType(netInf) as String? else { continue }
        if type == "PPP" || type == "VPN" || type == "IPSec" || type == "utun1" {
          guard let serviceName = SCNetworkServiceGetName(netService) as String? else { continue }
          vpnDict.updateValue(netService, forKey: serviceName)
        }
      }
    }
    return vpnDict
  }

  private func getNetworkConnection(service: SCNetworkService) -> SCNetworkConnection? {
    guard let serviceId = SCNetworkServiceGetServiceID(service) else { return nil }
    guard
      let connection = SCNetworkConnectionCreateWithServiceID(
        kCFAllocatorDefault, serviceId, nil, nil)
    else {
      return nil
    }
    return connection
  }

  func isVPNConnected() -> Bool {
    let vpnDict = getAllVPNServices()
    for (_, service) in vpnDict {
      guard let connection = getNetworkConnection(service: service) else { continue }
      let connectionStatus = SCNetworkConnectionGetStatus(connection)
      if connectionStatus.rawValue == 2 {
        return true
      }
    }
    return false
  }

  func changeVPNState(vpnName: String, type: VPNRequestType) -> Bool {
    let vpnDict = getAllVPNServices()
    let filteredVPNDict = vpnDict.filter { $0.key == vpnName }
    guard let service = filteredVPNDict.values.first else { return false }

    // code obtained from /usr/sbin/networksetup
    guard let serviceId = SCNetworkServiceGetServiceID(service) else { return false }
    guard
      let conn = SCNetworkConnectionCreateWithServiceID(kCFAllocatorDefault, serviceId, nil, nil)
    else { return false }

    let result =
      type == .connectionRequest
      ? SCNetworkConnectionStart(conn, nil, true) : SCNetworkConnectionStop(conn, true)

    return result
  }
}
