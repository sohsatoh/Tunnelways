import Cocoa
import CoreWLAN
import Foundation
import Network
import OrderedCollections
import SystemConfiguration

extension String {
    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: count))
        return matches.count > 0
    }
}

class VPNUtil: NSObject {
    static let sharedInstance: VPNUtil = VPNUtil()

    private var isAppLaunched: Bool = false
    private var isMonitorStarted: Bool = false
    private var monitor: NWPathMonitor = .init()
    private var tokens: [NSObjectProtocol] = []
    private var previousIfsAddrs: OrderedDictionary<String, [IPAddr]> = [:]

    override private init() {
        Logger.debug("VPNUtil init")
    }

    func registerObservers() {
        // Network Status Notification
        startMonitor()

        // Sleep notification
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(sleepListener(_:)), name: .init("com.apple.screenIsLocked"),
            object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(sleepListener(_:)), name: .init("com.apple.screenIsUnlocked"),
            object: nil)

        // App Status Check
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

    private func startMonitor() {
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
    }

    private func stopMonitor() {
        monitor.cancel()
        monitor = NWPathMonitor()
    }

    @objc private func sleepListener(_ aNotification: Notification) {
        if aNotification.name.rawValue == "com.apple.screenIsLocked" {
            Logger.debug("Going to sleep...")
            stopMonitor()
        } else if aNotification.name.rawValue == "com.apple.screenIsUnlocked" {
            Logger.debug("Woke up...")
            startMonitor()
        }
    }

    private func networkStatusChanged() {
        Logger.debug("networkStatusChanged")

        let ifsAddrs: OrderedDictionary<String, [IPAddr]> = getAllInterfaceIPAddresses()
        let filteredIfsAddrs = ifsAddrs.mapValues { value in
            value.filter { $0.isIPv4 }
        }

        let allArraysAreEmpty = filteredIfsAddrs.allSatisfy { addrs in
            addrs.value.allSatisfy { (addr: IPAddr) in
                !addr.isLoopback && !addr.isMulticast
            }
        }
        if allArraysAreEmpty {
            Logger.debug("Could not find IP Addrs")
            return
        } else if filteredIfsAddrs != previousIfsAddrs {
            Logger.debug(
                "\nifsAddrs = ", filteredIfsAddrs, "\n", "previousIfsAddrs = ", previousIfsAddrs)
            previousIfsAddrs = filteredIfsAddrs
        } else {
            Logger.debug("IP Addrs not changed")
            return
        }

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

    func getAllInterfaceIPAddresses() -> OrderedDictionary<String, [IPAddr]> {
        var ipAddresses: OrderedDictionary<String, [IPAddr]> = [:]

        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else { return OrderedDictionary() }
        guard let firstAddr = ifaddr else { return OrderedDictionary() }

        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                // Convert interface address to a human readable string:
                var addr = interface.ifa_addr.pointee
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(
                    &addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname, socklen_t(hostname.count),
                    nil, socklen_t(0), NI_NUMERICHOST)

                let address = String(cString: hostname)
                let interfaceName = String(cString: interface.ifa_name)

                if ipAddresses[interfaceName] == nil {
                    ipAddresses[interfaceName] = []
                }
                if address != "" {
                    ipAddresses[interfaceName]?.append(IPAddr(address: address))
                }
            }
        }
        freeifaddrs(ifaddr)
        ipAddresses.sort()

        return ipAddresses
    }

    func getSSID() -> String {
        guard let interface = CWWiFiClient.shared().interface() else { return "" }
        let ssid = interface.ssid() ?? ""
        return ssid
    }

    func getAllVPNServices() -> [String: SCNetworkService] {
        var vpnDict: [String: SCNetworkService] = [:]

        let processName = ProcessInfo.processInfo.processName
        guard let pref = SCPreferencesCreate(kCFAllocatorDefault, processName as CFString, nil)
        else {
            Logger.debug("ERROR: Failed to create the SCPreferences object")
            return vpnDict
        }
        guard let netServices = SCNetworkServiceCopyAll(pref) as? [SCNetworkService] else {
            Logger.debug("ERROR: Failed to obtain network services")
            return vpnDict
        }
        for netService in netServices {
            if SCNetworkServiceGetEnabled(netService) {
                guard let netInf = SCNetworkServiceGetInterface(netService) else { continue }
                guard let type = SCNetworkInterfaceGetInterfaceType(netInf) as String? else {
                    continue
                }
                if type == "PPP" || type == "VPN" || type == "IPSec" || type == "utun1" {
                    guard let serviceName = SCNetworkServiceGetName(netService) as String? else {
                        continue
                    }
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

        // code "obtained" from /usr/sbin/networksetup
        guard let serviceId = SCNetworkServiceGetServiceID(service) else { return false }
        guard
            let conn = SCNetworkConnectionCreateWithServiceID(
                kCFAllocatorDefault, serviceId, nil, nil)
        else { return false }

        let result =
            type == .connectionRequest
            ? SCNetworkConnectionStart(conn, nil, true) : SCNetworkConnectionStop(conn, true)

        return result
    }
}
