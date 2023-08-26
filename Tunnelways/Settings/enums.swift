import Foundation

enum VPNRequestType: String {
  case connectionRequest = "connect to"
  case disconnectionRequest = "disconnect"
}

enum Keys {
  static let enableAppStatusCheck = "enableAppStatusCheck"
  static let enableAutoDisconnection = "enableAutoDisconnection"
  static let applicationName = "applicationName"
  static let enableAutoConnection = "enableAutoConnection"
  static let vpnName = "vpnName"
  static let enableBypassForSSID = "enableBypassForSSID"
  static let ssid = "ssid"
}
