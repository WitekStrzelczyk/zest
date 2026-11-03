import AppKit
import CoreWLAN
import Foundation
import os.log
import SystemConfiguration

enum InterfaceType: String {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case loopback = "Loopback"
    case vpn = "VPN"
    case other = "Other"
}

struct NetworkInterface {
    let name: String

    let address: String

    let interfaceType: InterfaceType
}

struct WiFiInfo {
    let ssid: String?

    let bssid: String?
}

enum PublicIPResult: Equatable {
    case success(String)
    case noInternet
    case error(String)
}

final class NetworkInfoService {
    static let shared = NetworkInfoService()

    private let logger = Logger(subsystem: "com.zest.app", category: "NetworkInfo")

    private var cachedPublicIP: String?
    private var publicIPCacheTime: Date?
    private let publicIPCacheTimeout: TimeInterval = 300

    private let publicIPAPIs = [
        "https://api.ipify.org?format=text",
        "https://api.ip.sb/ip",
        "https://ifconfig.me/ip",
    ]

    private static let wifiInterfaceNames = Set(CWWiFiClient.shared().interfaceNames() ?? [])
    private static let ipIcon = NSImage(systemSymbolName: "network", accessibilityDescription: "IP Address")
    private static let publicIPIcon = NSImage(systemSymbolName: "globe", accessibilityDescription: "Public IP")
    private static let wifiIcon = NSImage(systemSymbolName: "wifi", accessibilityDescription: "Network")
    private static let noWifiIcon = NSImage(systemSymbolName: "wifi.slash", accessibilityDescription: "No WiFi")
    private static let interfaceIcons: [InterfaceType: NSImage?] = [
        .wifi: NSImage(systemSymbolName: "wifi", accessibilityDescription: "Wi-Fi"),
        .ethernet: NSImage(systemSymbolName: "cable.connector", accessibilityDescription: "Ethernet"),
        .vpn: NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "VPN"),
        .loopback: NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Loopback"),
        .other: NSImage(systemSymbolName: "network", accessibilityDescription: "Other"),
    ]

    private let cacheLock = NSLock()

    private init() {}

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

            if addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: ptr!.pointee.ifa_name)

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

        return interfaces.sorted { a, b in
            let orderA = interfaceTypeOrder(a.interfaceType)
            let orderB = interfaceTypeOrder(b.interfaceType)
            return orderA < orderB
        }
    }

    private func interfaceTypeOrder(_ type: InterfaceType) -> Int {
        switch type {
        case .wifi: 0
        case .ethernet: 1
        case .vpn: 2
        case .other: 3
        case .loopback: 4
        }
    }

    private func determineInterfaceType(name: String, address: String) -> InterfaceType {
        if address == "127.0.0.1" || name.hasPrefix("lo") {
            return .loopback
        }

        if name.hasPrefix("utun") || name.hasPrefix("tun") || name.hasPrefix("ppp") || name.hasPrefix("ipsec") {
            return .vpn
        }

        if Self.wifiInterfaceNames.contains(name) {
            return .wifi
        }

        if name.hasPrefix("en") || name.hasPrefix("bridge") {
            return .ethernet
        }

        return .other
    }

    func getPublicIP() async -> PublicIPResult {
        if let cached = freshCachedPublicIP() {
            return .success(cached)
        }

        let result = await fetchPublicIP()

        if case .success(let ip) = result {
            cacheLock.withLock {
                cachedPublicIP = ip
                publicIPCacheTime = Date()
            }
        }

        return result
    }

    private func freshCachedPublicIP() -> String? {
        cacheLock.withLock {
            guard let cached = cachedPublicIP, let cacheTime = publicIPCacheTime,
                  Date().timeIntervalSince(cacheTime) < publicIPCacheTimeout else { return nil }
            return cached
        }
    }

    private func fetchPublicIP() async -> PublicIPResult {
        var offline = false
        for apiURL in publicIPAPIs {
            do {
                let ip = try await fetchFromAPI(url: apiURL, timeout: 5)
                let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)

                if isValidIP(trimmedIP) {
                    logger.info("Fetched public IP: \(trimmedIP) from \(apiURL)")
                    return .success(trimmedIP)
                }
            } catch {
                logger.debug("API \(apiURL) failed: \(error.localizedDescription)")
                if (error as? URLError)?.code == .notConnectedToInternet {
                    offline = true
                }
                continue
            }
        }

        if offline {
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
        let ipv4Pattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#
        let ipv6Pattern = #"^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$"#

        return ip.range(of: ipv4Pattern, options: .regularExpression) != nil ||
            ip.range(of: ipv6Pattern, options: .regularExpression) != nil
    }

    func clearCache() {
        cacheLock.withLock {
            cachedPublicIP = nil
            publicIPCacheTime = nil
        }
    }

    func getNetworkInterfaces() -> [NetworkInterface] {
        getLocalIPAddresses()
    }

    func getWiFiInfo() -> WiFiInfo {
        var ssid: String?
        var bssid: String?

        let client = CWWiFiClient.shared()
        if let interface = client.interface() {
            ssid = interface.ssid()
            bssid = interface.bssid()
        }

        return WiFiInfo(ssid: ssid, bssid: bssid)
    }

    func isVPNConnected() -> Bool {
        let interfaces = getLocalIPAddresses()
        return interfaces.contains { $0.interfaceType == .vpn }
    }

    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()

        guard !lowercasedQuery.isEmpty else { return [] }

        let ipKeywords = ["ip", "address", "my ip", "local ip", "public ip", "wan", "lan"]
        let networkKeywords = ["network", "wifi", "wi-fi", "ssid", "interface", "dns", "bssid"]

        let ipMatch = matchesKeyword(lowercasedQuery, in: ipKeywords)
        let networkMatch = matchesKeyword(lowercasedQuery, in: networkKeywords)

        guard ipMatch || networkMatch else { return [] }

        let localIPs = getLocalIPAddresses()
        let vpnConnected = localIPs.contains { $0.interfaceType == .vpn }
        var results: [SearchResult] = []

        if ipMatch {
            results.append(contentsOf: createIPResults(
                query: lowercasedQuery,
                localIPs: localIPs,
                vpnConnected: vpnConnected
            ))
        }

        if networkMatch {
            results.append(contentsOf: createNetworkInfoResults(query: lowercasedQuery, vpnConnected: vpnConnected))
        }

        return results
    }

    private func createIPResults(query: String, localIPs: [NetworkInterface], vpnConnected: Bool) -> [SearchResult] {
        var results: [SearchResult] = []

        let displayIPs = localIPs.filter { $0.interfaceType != .loopback }

        let score = SearchScoreCalculator.shared.calculateScore(
            query: query,
            title: "IP Address",
            category: .action
        )

        results.append(buildMainIPResult(
            displayIPs: displayIPs,
            vpnConnected: vpnConnected,
            score: score,
            localIPs: localIPs
        ))

        if displayIPs.count > 1 {
            let ipResults = buildAdditionalIPResults(
                displayIPs: displayIPs,
                score: score
            )
            results.append(contentsOf: ipResults)
        }

        results.append(buildPublicIPResult(score: score))

        return results
    }

    private func buildMainIPResult(
        displayIPs: [NetworkInterface],
        vpnConnected: Bool,
        score: Int,
        localIPs: [NetworkInterface]
    ) -> SearchResult {
        let subtitle: String
        if let primaryIP = displayIPs.first {
            let vpnIndicator = vpnConnected ? " • 🔒 VPN" : ""
            subtitle = "\(primaryIP.address)\(vpnIndicator)"
        } else {
            subtitle = "No network connection"
        }

        return SearchResult(
            title: "My IP Address",
            subtitle: subtitle,
            icon: Self.ipIcon,
            category: .action,
            action: { [weak self] in
                self?.copyLocalIPToClipboard(localIPs)
            },
            score: max(score, 100)
        )
    }

    private func buildAdditionalIPResults(displayIPs: [NetworkInterface], score: Int) -> [SearchResult] {
        displayIPs.map { ip in
            SearchResult(
                title: "\(ip.interfaceType.rawValue): \(ip.address)",
                subtitle: "Interface: \(ip.name)",
                icon: Self.interfaceIcons[ip.interfaceType] ?? nil,
                category: .action,
                action: { [weak self] in
                    self?.copySingleIPToClipboard(ip)
                },
                score: max(score - 10, 50)
            )
        }
    }

    private func buildPublicIPResult(score: Int) -> SearchResult {
        SearchResult(
            title: "Public IP (WAN)",
            subtitle: freshCachedPublicIP() ?? "Press Enter to fetch",
            icon: Self.publicIPIcon,
            category: .action,
            action: { [weak self] in
                Task {
                    if let self {
                        let result = await self.getPublicIP()
                        switch result {
                        case .success(let ip):
                            self.copyPublicIPToClipboard(ip)
                        case .noInternet, .error:
                            break
                        }
                    }
                }
            },
            score: max(score - 5, 80)
        )
    }

    private func createNetworkInfoResults(query: String, vpnConnected: Bool) -> [SearchResult] {
        var results: [SearchResult] = []
        let wifiInfo = getWiFiInfo()

        let score = SearchScoreCalculator.shared.calculateScore(
            query: query,
            title: "Network Info",
            category: .action
        )

        if let ssid = wifiInfo.ssid {
            let subtitle = "Connected to: \(ssid)"
                + (wifiInfo.bssid != nil ? " • BSSID: \(wifiInfo.bssid!)" : "")
                + (vpnConnected ? " • 🔒 VPN" : "")

            results.append(SearchResult(
                title: "Network Info",
                subtitle: subtitle,
                icon: Self.wifiIcon,
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
                icon: Self.noWifiIcon,
                category: .action,
                action: { [weak self] in
                    self?.copyNetworkInfoToClipboard(wifiInfo: wifiInfo, vpnConnected: vpnConnected)
                },
                score: max(score - 20, 50)
            ))
        }

        return results
    }

    func formatLocalIPs(_ ips: [NetworkInterface]) -> String {
        ips.map { "\($0.name): \($0.address)" }.joined(separator: "\n")
    }

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

        if let publicIP {
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

    func copyPublicIPToClipboard(_ ip: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip, forType: .string)
        logger.info("Public IP copied to clipboard: \(ip)")
    }

    func copyLocalIPToClipboard(_ ips: [NetworkInterface]) {
        let nonLoopback = ips.filter { $0.interfaceType != .loopback }
        let text = nonLoopback.map { "\($0.interfaceType.rawValue): \($0.address)" }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        logger.info("Local IPs copied to clipboard")
    }

    func copySingleIPToClipboard(_ ip: NetworkInterface) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip.address, forType: .string)
        logger.info("IP copied to clipboard: \(ip.address)")
    }

    func copyNetworkInfoToClipboard(
        localIPs: [NetworkInterface]? = nil,
        publicIP: String? = nil,
        wifiInfo: WiFiInfo? = nil,
        vpnConnected _: Bool = false
    ) {
        let ips = localIPs ?? getLocalIPAddresses()
        let wifi = wifiInfo ?? getWiFiInfo()

        let text = formatNetworkInfoForClipboard(
            localIPs: ips,
            publicIP: publicIP ?? freshCachedPublicIP(),
            wifiInfo: wifi
        )

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        logger.info("Network info copied to clipboard")
    }

    func copyNetworkInfoToClipboard(wifiInfo: WiFiInfo, vpnConnected: Bool) {
        copyNetworkInfoToClipboard(localIPs: nil, publicIP: nil, wifiInfo: wifiInfo, vpnConnected: vpnConnected)
    }
}

extension NetworkInfoService: SearchTool {
    var name: String { "Network Info" }

    func search(_ context: QueryContext) -> [SearchResult] {
        search(query: context.normalized)
    }
}
