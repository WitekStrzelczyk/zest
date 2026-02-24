import AppKit
import CoreWLAN
import Foundation
import os.log
import SystemConfiguration

// MARK: - Network Interface Type

/// Type of network interface
enum InterfaceType: String {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case loopback = "Loopback"
    case vpn = "VPN"
    case other = "Other"
}

// MARK: - Network Interface

/// Contains information about a network interface
struct NetworkInterface {
    /// Interface name (e.g., "en0", "lo0")
    let name: String
    
    /// IP address
    let address: String
    
    /// Interface type
    let interfaceType: InterfaceType
}

// MARK: - WiFi Info

/// Contains WiFi connection information
struct WiFiInfo {
    /// Network name (SSID)
    let ssid: String?
    
    /// MAC address of the access point (BSSID)
    let bssid: String?
}

// MARK: - Public IP Result

/// Result of public IP fetch
enum PublicIPResult: Equatable {
    case success(String)
    case noInternet
    case error(String)
}

// MARK: - Network Info Service

/// Service for retrieving network information including IP addresses and WiFi details
final class NetworkInfoService {
    // MARK: - Singleton
    
    static let shared = NetworkInfoService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.zest.app", category: "NetworkInfo")
    
    /// Cached public IP (5 minute cache)
    private var cachedPublicIP: String?
    private var publicIPCacheTime: Date?
    private let publicIPCacheTimeout: TimeInterval = 300 // 5 minutes
    
    /// API endpoints for public IP (fallback chain)
    private let publicIPAPIs = [
        "https://api.ipify.org?format=text",
        "https://api.ip.sb/ip",
        "https://ifconfig.me/ip"
    ]
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public API - Local IPs
    
    /// Get all local IP addresses
    /// - Returns: Array of NetworkInterface with interface name and IP address
    func getLocalIPAddresses() -> [NetworkInterface] {
        var interfaces: [NetworkInterface] = []
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else {
            logger.error("Failed to get interface addresses")
            return interfaces
        }
        
        defer {
            freeifaddrs(ifaddr)
        }
        
        var ptr = ifaddr
        while ptr != nil {
            guard let addr = ptr?.pointee.ifa_addr else {
                ptr = ptr?.pointee.ifa_next
                continue
            }
            
            // Only IPv4 addresses
            if addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: ptr!.pointee.ifa_name)
                
                // Convert socket address to IP string
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    addr,
                    socklen_t(addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                
                if result == 0 {
                    let ipAddress = String(cString: hostname)
                    let interfaceType = determineInterfaceType(name: name, address: ipAddress)
                    
                    interfaces.append(NetworkInterface(
                        name: name,
                        address: ipAddress,
                        interfaceType: interfaceType
                    ))
                }
            }
            
            ptr = ptr?.pointee.ifa_next
        }
        
        // Sort: WiFi first, then Ethernet, then others, loopback last
        return interfaces.sorted { a, b in
            let orderA = interfaceTypeOrder(a.interfaceType)
            let orderB = interfaceTypeOrder(b.interfaceType)
            return orderA < orderB
        }
    }
    
    private func interfaceTypeOrder(_ type: InterfaceType) -> Int {
        switch type {
        case .wifi: return 0
        case .ethernet: return 1
        case .vpn: return 2
        case .other: return 3
        case .loopback: return 4
        }
    }
    
    private func determineInterfaceType(name: String, address: String) -> InterfaceType {
        // Loopback
        if address == "127.0.0.1" || name.hasPrefix("lo") {
            return .loopback
        }
        
        // VPN interfaces (common prefixes)
        if name.hasPrefix("utun") || name.hasPrefix("tun") || name.hasPrefix("ppp") || name.hasPrefix("ipsec") {
            return .vpn
        }
        
        // WiFi interfaces (en0, en1 typically)
        if name.hasPrefix("en") {
            // Check if it's actually WiFi or Ethernet
            // On MacBooks, en0 is usually WiFi
            return .wifi
        }
        
        // Ethernet
        if name.hasPrefix("en") && name != "en0" {
            return .ethernet
        }
        
        // Thunderbolt Ethernet
        if name.hasPrefix("bridge") {
            return .ethernet
        }
        
        return .other
    }
    
    // MARK: - Public API - Public IP
    
    /// Get public IP address (with caching)
    /// - Returns: PublicIPResult with the IP or error
    func getPublicIP() async -> PublicIPResult {
        // Check cache
        if let cached = cachedPublicIP, let cacheTime = publicIPCacheTime {
            if Date().timeIntervalSince(cacheTime) < publicIPCacheTimeout {
                logger.debug("Returning cached public IP")
                return .success(cached)
            }
        }
        
        // Fetch fresh
        let result = await fetchPublicIP()
        
        if case .success(let ip) = result {
            cachedPublicIP = ip
            publicIPCacheTime = Date()
        }
        
        return result
    }
    
    /// Fetch public IP from API with timeout
    private func fetchPublicIP() async -> PublicIPResult {
        // Try each API endpoint in order
        for apiURL in publicIPAPIs {
            do {
                let ip = try await fetchFromAPI(url: apiURL, timeout: 5)
                let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Validate IP format (basic check)
                if isValidIP(trimmedIP) {
                    logger.info("Fetched public IP: \(trimmedIP) from \(apiURL)")
                    return .success(trimmedIP)
                }
            } catch {
                logger.debug("API \(apiURL) failed: \(error.localizedDescription)")
                continue
            }
        }
        
        // All APIs failed - check if we have internet
        if !hasInternetConnection() {
            return .noInternet
        }
        
        return .error("Failed to fetch public IP")
    }
    
    private func fetchFromAPI(url: String, timeout: TimeInterval) async throws -> String {
        guard let url = URL(string: url) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func isValidIP(_ ip: String) -> Bool {
        // Basic IPv4 validation
        let ipv4Pattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#
        // Basic IPv6 validation (simplified)
        let ipv6Pattern = #"^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$"#
        
        return ip.range(of: ipv4Pattern, options: .regularExpression) != nil ||
               ip.range(of: ipv6Pattern, options: .regularExpression) != nil
    }
    
    private func hasInternetConnection() -> Bool {
        // Use SystemConfiguration to check reachability
        let reachability = SCNetworkReachabilityCreateWithName(nil, "api.ipify.org")
        var flags = SCNetworkReachabilityFlags()
        
        guard let reachability = reachability,
              SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return false
        }
        
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }
    
    /// Clear cached public IP
    func clearCache() {
        cachedPublicIP = nil
        publicIPCacheTime = nil
    }
    
    // MARK: - Public API - Network Interfaces
    
    /// Get list of network interfaces
    /// - Returns: Array of NetworkInterface
    func getNetworkInterfaces() -> [NetworkInterface] {
        getLocalIPAddresses()
    }
    
    // MARK: - Public API - WiFi Info
    
    /// Get current WiFi information
    /// - Returns: WiFiInfo with SSID and BSSID (may be nil if not connected or no permissions)
    func getWiFiInfo() -> WiFiInfo {
        // Use CoreWLAN framework for WiFi info
        // Note: On macOS 14+, this may require special entitlements
        
        var ssid: String?
        var bssid: String?
        
        // Use CoreWLAN interface
        let client = CWWiFiClient.shared()
        if let interface = client.interface() {
            ssid = interface.ssid()
            bssid = interface.bssid()
        }
        
        return WiFiInfo(ssid: ssid, bssid: bssid)
    }
    
    // MARK: - Public API - VPN Detection
    
    /// Check if VPN is connected
    /// - Returns: true if VPN appears to be connected
    func isVPNConnected() -> Bool {
        let interfaces = getLocalIPAddresses()
        return interfaces.contains { $0.interfaceType == .vpn }
    }
    
    // MARK: - Search
    
    /// Search for network info commands
    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()
        
        guard !lowercasedQuery.isEmpty else { return [] }
        
        // Keywords that trigger network results
        let ipKeywords = ["ip", "address", "my ip", "local ip", "public ip", "wan", "lan"]
        let networkKeywords = ["network", "wifi", "wi-fi", "ssid", "interface", "dns", "bssid"]
        
        let ipMatch = ipKeywords.contains { keyword in
            lowercasedQuery.contains(keyword)
        }
        
        let networkMatch = networkKeywords.contains { keyword in
            lowercasedQuery.contains(keyword)
        }
        
        guard ipMatch || networkMatch else { return [] }
        
        var results: [SearchResult] = []
        
        // Main IP result
        if ipMatch {
            results.append(contentsOf: createIPResults(query: lowercasedQuery))
        }
        
        // Network info result
        if networkMatch {
            results.append(contentsOf: createNetworkInfoResults(query: lowercasedQuery))
        }
        
        return results
    }
    
    private func createIPResults(query: String) -> [SearchResult] {
        var results: [SearchResult] = []
        let localIPs = getLocalIPAddresses()
        let vpnConnected = isVPNConnected()
        
        // Filter to non-loopback IPs for display
        let displayIPs = localIPs.filter { $0.interfaceType != .loopback }
        
        let score = SearchScoreCalculator.shared.calculateScore(
            query: query,
            title: "IP Address",
            category: .action
        )
        
        // Format subtitle
        let subtitle: String
        if let primaryIP = displayIPs.first {
            let vpnIndicator = vpnConnected ? " • 🔒 VPN" : ""
            subtitle = "\(primaryIP.address)\(vpnIndicator)"
        } else {
            subtitle = "No network connection"
        }
        
        results.append(SearchResult(
            title: "My IP Address",
            subtitle: subtitle,
            icon: NSImage(systemSymbolName: "network", accessibilityDescription: "IP Address"),
            category: .action,
            action: { [weak self] in
                self?.copyLocalIPToClipboard(localIPs)
            },
            score: max(score, 100)
        ))
        
        // Show all local IPs
        if displayIPs.count > 1 {
            for ip in displayIPs {
                results.append(SearchResult(
                    title: "\(ip.interfaceType.rawValue): \(ip.address)",
                    subtitle: "Interface: \(ip.name)",
                    icon: NSImage(systemSymbolName: iconForInterfaceType(ip.interfaceType), accessibilityDescription: ip.interfaceType.rawValue),
                    category: .action,
                    action: { [weak self] in
                        self?.copySingleIPToClipboard(ip)
                    },
                    score: max(score - 10, 50)
                ))
            }
        }
        
        // Public IP result (will show cached or fetch)
        results.append(SearchResult(
            title: "Public IP (WAN)",
            subtitle: cachedPublicIP ?? "Press Enter to fetch",
            icon: NSImage(systemSymbolName: "globe", accessibilityDescription: "Public IP"),
            category: .action,
            action: { [weak self] in
                Task {
                    if let self = self {
                        let result = await self.getPublicIP()
                        switch result {
                        case .success(let ip):
                            self.copyPublicIPToClipboard(ip)
                        case .noInternet:
                            // Show notification or update subtitle
                            break
                        case .error:
                            break
                        }
                    }
                }
            },
            score: max(score - 5, 80)
        ))
        
        return results
    }
    
    private func createNetworkInfoResults(query: String) -> [SearchResult] {
        var results: [SearchResult] = []
        let wifiInfo = getWiFiInfo()
        let vpnConnected = isVPNConnected()
        
        let score = SearchScoreCalculator.shared.calculateScore(
            query: query,
            title: "Network Info",
            category: .action
        )
        
        // WiFi info
        if let ssid = wifiInfo.ssid {
            let subtitle = "Connected to: \(ssid)"
            + (wifiInfo.bssid != nil ? " • BSSID: \(wifiInfo.bssid!)" : "")
            + (vpnConnected ? " • 🔒 VPN" : "")
            
            results.append(SearchResult(
                title: "Network Info",
                subtitle: subtitle,
                icon: NSImage(systemSymbolName: "wifi", accessibilityDescription: "Network"),
                category: .action,
                action: { [weak self] in
                    self?.copyNetworkInfoToClipboard(wifiInfo: wifiInfo, vpnConnected: vpnConnected)
                },
                score: max(score, 100)
            ))
        } else {
            results.append(SearchResult(
                title: "Network Info",
                subtitle: vpnConnected ? "No WiFi • 🔒 VPN Active" : "Not connected to WiFi",
                icon: NSImage(systemSymbolName: "wifi.slash", accessibilityDescription: "No WiFi"),
                category: .action,
                action: { [weak self] in
                    self?.copyNetworkInfoToClipboard(wifiInfo: wifiInfo, vpnConnected: vpnConnected)
                },
                score: max(score - 20, 50)
            ))
        }
        
        return results
    }
    
    private func iconForInterfaceType(_ type: InterfaceType) -> String {
        switch type {
        case .wifi: return "wifi"
        case .ethernet: return "cable.connector"
        case .vpn: return "lock.shield"
        case .loopback: return "arrow.triangle.2.circlepath"
        case .other: return "network"
        }
    }
    
    // MARK: - Formatting
    
    /// Format local IPs for display
    func formatLocalIPs(_ ips: [NetworkInterface]) -> String {
        ips.map { "\($0.name): \($0.address)" }.joined(separator: "\n")
    }
    
    /// Format network info for clipboard
    func formatNetworkInfoForClipboard(localIPs: [NetworkInterface], publicIP: String?, wifiInfo: WiFiInfo) -> String {
        var text = """
        Network Information
        ===================
        
        Local IP Addresses
        ------------------
        """
        
        for ip in localIPs where ip.interfaceType != .loopback {
            text += "\n\(ip.interfaceType.rawValue) (\(ip.name)): \(ip.address)"
        }
        
        if let publicIP = publicIP {
            text += "\n\nPublic IP: \(publicIP)"
        }
        
        if let ssid = wifiInfo.ssid {
            text += "\n\nWiFi: \(ssid)"
        }
        
        if let bssid = wifiInfo.bssid {
            text += "\nBSSID: \(bssid)"
        }
        
        if isVPNConnected() {
            text += "\n\n🔒 VPN: Connected"
        }
        
        return text
    }
    
    // MARK: - Clipboard
    
    /// Copy public IP to clipboard
    func copyPublicIPToClipboard(_ ip: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip, forType: .string)
        logger.info("Public IP copied to clipboard: \(ip)")
    }
    
    /// Copy local IPs to clipboard
    func copyLocalIPToClipboard(_ ips: [NetworkInterface]) {
        let nonLoopback = ips.filter { $0.interfaceType != .loopback }
        let text = nonLoopback.map { "\($0.interfaceType.rawValue): \($0.address)" }.joined(separator: "\n")
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        logger.info("Local IPs copied to clipboard")
    }
    
    /// Copy single IP to clipboard
    func copySingleIPToClipboard(_ ip: NetworkInterface) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip.address, forType: .string)
        logger.info("IP copied to clipboard: \(ip.address)")
    }
    
    /// Copy network info to clipboard
    func copyNetworkInfoToClipboard(localIPs: [NetworkInterface]? = nil, publicIP: String? = nil, wifiInfo: WiFiInfo? = nil, vpnConnected: Bool = false) {
        let ips = localIPs ?? getLocalIPAddresses()
        let wifi = wifiInfo ?? getWiFiInfo()
        
        let text = formatNetworkInfoForClipboard(localIPs: ips, publicIP: publicIP ?? cachedPublicIP, wifiInfo: wifi)
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        logger.info("Network info copied to clipboard")
    }
    
    /// Copy network info to clipboard (convenience method)
    func copyNetworkInfoToClipboard(wifiInfo: WiFiInfo, vpnConnected: Bool) {
        copyNetworkInfoToClipboard(localIPs: nil, publicIP: nil, wifiInfo: wifiInfo, vpnConnected: vpnConnected)
    }
}
