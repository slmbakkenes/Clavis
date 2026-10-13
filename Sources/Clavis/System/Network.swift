import Darwin

enum Network {
  /// IPv4 address of en0, the built-in Wi-Fi or Ethernet interface, as the
  /// previous build's `ip` answer showed.
  static func localIPv4Address(interface: String = "en0") -> String? {
    var first: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&first) == 0, let first else { return nil }
    defer { freeifaddrs(first) }

    var cursor: UnsafeMutablePointer<ifaddrs>? = first
    while let current = cursor {
      defer { cursor = current.pointee.ifa_next }
      guard let address = current.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
        String(cString: current.pointee.ifa_name) == interface
      else { continue }
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      let status = getnameinfo(
        address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
      if status == 0 {
        return String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
      }
    }
    return nil
  }
}
