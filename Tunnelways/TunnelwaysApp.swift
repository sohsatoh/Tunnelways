import SwiftUI
import UserNotifications

@main
struct TunnelwaysApp: App {
    #if os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif
    var body: some Scene {
        #if os(macOS)
            Settings {
                SettingsView()
                    .environmentObject(SettingsStore())
            }
        #endif
        WindowGroup {}
    }
}

#if os(macOS)
    class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
        private var statusItem: NSStatusItem!
        private var isObserverRegistered = false
        private var disabledUntilDate: Date?
        private var isEnabled = true

        func applicationDidFinishLaunching(_: Notification) {
            NSApp.windows.forEach { $0.close() }
            NSApp.setActivationPolicy(.accessory)

            // Setup NotificationCenter
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound]) {
                    granted, _ in
                    if granted {
                        UNUserNotificationCenter.current().delegate = self
                    }
                }

            setupStatusbarItem()
            registerObservers()
        }

        private func setupStatusbarItem() {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

            let button = statusItem.button!
            button.image = NSImage(
                systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: nil)

            let menu: NSMenu = {
                let menu = NSMenu()
                menu.autoenablesItems = false
                menu.addItem(
                    withTitle: NSLocalizedString("TOGGLE", comment: "Enable/Disable Tunnelways"),
                    action: #selector(toggleAppState),
                    keyEquivalent: ""
                )
                menu.addItem(
                    withTitle: NSLocalizedString(
                        "DISABLE_APP_FOR_SPECIFIC_TIME", comment: "Disable for specific time"),
                    action: #selector(showDisableAppAlert),
                    keyEquivalent: ""
                )
                menu.addItem(
                    withTitle: NSLocalizedString("SETTINGS", comment: "Show settings window"),
                    action: #selector(openPreferencesWindow),
                    keyEquivalent: ""
                )
                menu.addItem(.separator())
                menu.addItem(
                    withTitle: NSLocalizedString("QUIT", comment: "Quit app"),
                    action: #selector(terminate),
                    keyEquivalent: ""
                )
                return menu
            }()
            statusItem.menu = menu
        }

        @objc private func registerObservers() {
            if isObserverRegistered {
                Logger.debug("remove all notifications because settings changed")
                unregisterObservers()
            }
            isObserverRegistered = true

            let vpnUtil = VPNUtil.sharedInstance
            vpnUtil.registerObservers()

            let center = NotificationCenter.default
            let vpnChangedNotification = Notification.Name("jp.soh.Tunnelways.ChangeVPNRequest")
            center.addObserver(
                self,
                selector: #selector(vpnStateChanged(notification:)),
                name: vpnChangedNotification,
                object: nil)
            let settingsChangedNotification = Notification.Name("jp.soh.Tunnelways.settingsChanged")
            center.addObserver(
                self,
                selector: #selector(registerObservers),
                name: settingsChangedNotification,
                object: nil)
        }

        private func unregisterObservers() {
            let center = NotificationCenter.default
            center.removeObserver(self)

            let vpnUtil = VPNUtil.sharedInstance
            vpnUtil.unregisterObservers()
        }

        private func showErrorAlert(text: String) {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Tunnelways"
                alert.informativeText = text
                alert.icon = NSImage(
                    systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: nil)
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }

        private func sendNotification(body: String) {
            let content = UNMutableNotificationContent()
            content.title = "Tunnelways"
            content.body = body
            content.sound = UNNotificationSound.default

            let request = UNNotificationRequest(
                identifier: "immediately", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }

        private func changeVPNState(vpnName: String, type: VPNRequestType) {
            Logger.debug("changeVPNState: \(vpnName), type: \(type)")
            let vpnUtil = VPNUtil.sharedInstance
            let result = vpnUtil.changeVPNState(vpnName: vpnName, type: type)

            if !result {
                showErrorAlert(text: "Could not \(type.rawValue)\n\(vpnName)")
            } else {
                sendNotification(body: "Successfully \(type.rawValue)\n\(vpnName)")
            }
        }

        @objc private func vpnStateChanged(notification: Notification) {
            Logger.debug("vpnStateChanged")
            let settingsStore = SettingsStore()
            let enableAutoConnection = settingsStore.enableAutoConnection
            let vpnName = settingsStore.vpnName

            let requestType: VPNRequestType = notification.object as! VPNRequestType

            if requestType == .connectionRequest {
                if enableAutoConnection {
                    changeVPNState(vpnName: vpnName, type: requestType)
                } else {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Tunnelways"
                        alert.informativeText = String(
                            NSLocalizedString("NO_VPN_TEXT", comment: "") + vpnName)
                        alert.icon = NSImage(
                            systemSymbolName: "bolt.horizontal.circle",
                            accessibilityDescription: nil)
                        alert.addButton(withTitle: "Connect")
                        alert.addButton(withTitle: "Cancel")
                        let response = alert.runModal()
                        if response == .alertFirstButtonReturn {
                            self.changeVPNState(vpnName: vpnName, type: requestType)
                        }
                    }
                }
            } else if requestType == .disconnectionRequest {
                changeVPNState(vpnName: vpnName, type: requestType)
            }
        }

        private func updateStatusBarMenuItem() {
            DispatchQueue.main.async {
                self.statusItem.button!.appearsDisabled = !self.isEnabled

                guard let disableMenuItem = self.statusItem.menu?.item(at: 1) else { return }
                disableMenuItem.isEnabled = self.isEnabled
                let disableMenuTitle: String = {
                    if self.isEnabled {
                        self.disabledUntilDate = nil
                        return NSLocalizedString("DISABLE_APP_FOR_SPECIFIC_TIME", comment: "")
                    } else {
                        return self.disabledUntilDate != nil
                            ? String(
                                NSLocalizedString("DISABLED_UNTIL", comment: "")
                                    + self.disabledUntilDate!.description(with: .current))
                            : NSLocalizedString("APP_DISABLED", comment: "")
                    }
                }()
                disableMenuItem.title = disableMenuTitle
            }
        }

        @objc func toggleAppState() {
            isEnabled = !isEnabled

            if isEnabled {
                registerObservers()
            } else {
                unregisterObservers()
            }

            updateStatusBarMenuItem()
        }

        private func disableAppFor(minutes: Int) {
            let day = Date()
            let untilDate = Calendar.current.date(byAdding: .minute, value: minutes, to: day)!
            disabledUntilDate = untilDate

            toggleAppState()

            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(minutes * 60)) {
                if !self.isEnabled, self.disabledUntilDate != nil {
                    self.toggleAppState()
                    self.sendNotification(body: NSLocalizedString("RE_ENABLED", comment: ""))
                }
            }
        }

        @objc func showDisableAppAlert() {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Tunnelways"
                alert.informativeText = NSLocalizedString("DISABLE_ALERT_TEXT", comment: "")
                alert.icon = NSImage(
                    systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: nil)
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Cancel")

                let txtInput = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                txtInput.stringValue = ""
                alert.accessoryView = txtInput

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    guard let minVal = Int(txtInput.stringValue) else { return }
                    self.disableAppFor(minutes: minVal)
                }
            }
        }

        @objc private func openPreferencesWindow() {
            Logger.debug("open Prefs")
            if #available(macOS 13, *) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } else {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
            NSApp.windows.forEach { if $0.canBecomeMain { $0.orderFrontRegardless() } }
        }

        @objc func terminate() {
            NSApp.terminate(self)
        }
    }
#endif
