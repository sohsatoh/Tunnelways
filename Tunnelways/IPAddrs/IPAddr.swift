 import Network

 struct IPAddr: Equatable {
     let address: String
     var isIPv4: Bool
     var isLoopback: Bool
     var isMulticast: Bool
     var isLinkLocal: Bool

     init(address: String) {
         self.address = address
         
         let addr: IPAddress = IPv4Address(address) ?? IPv6Address(address)!
         self.isIPv4 = String(describing: type(of: addr)) == "IPv4Address"
         self.isLoopback = addr.isLoopback
         self.isMulticast = addr.isMulticast
         self.isLinkLocal = addr.isLinkLocal
     }
 }
