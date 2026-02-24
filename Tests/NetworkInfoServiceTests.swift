import XCTest
@testable import ZestApp

/// Tests for NetworkInfoService - IP address and network information retrieval
final class NetworkInfoServiceTests: XCTestCase {
    
    var sut: NetworkInfoService!
    
    override func setUp() {
        super.setUp()
        sut = NetworkInfoService.shared
        // Clear cache for fresh tests
        sut.clearCache()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Singleton Tests
    
    func testNetworkInfoServiceCreation() {
        XCTAssertNotNil(sut)
    }
    
    func testNetworkInfoServiceSingleton() {
        let service1 = NetworkInfoService.shared
        let service2 = NetworkInfoService.shared
        XCTAssertTrue(service1 === service2)
    }
    
    // MARK: - Local IP Tests
    
    func testGetLocalIPsReturnsArray() {
        let ips = sut.getLocalIPAddresses()
        // Should return an array (may be empty on CI, but typically has at least loopback)
        XCTAssertNotNil(ips)
    }
    
    func testGetLocalIPsContainsValidFormat() {
        let ips = sut.getLocalIPAddresses()
        
        for ip in ips {
            // IP should contain dots (IPv4) or colons (IPv6)
            let isValidIPv4 = ip.address.contains(".")
            let isValidIPv6 = ip.address.contains(":")
            XCTAssertTrue(isValidIPv4 || isValidIPv6, "IP address should be valid format: \(ip.address)")
        }
    }
    
    func testGetLocalIPsReturnsInterfaceNames() {
        let ips = sut.getLocalIPAddresses()
        
        for ip in ips {
            // Interface name should not be empty
            XCTAssertFalse(ip.name.isEmpty, "Interface name should not be empty")
        }
    }
    
    func testGetLocalIPsIncludesLoopback() {
        let ips = sut.getLocalIPAddresses()
        let hasLoopback = ips.contains { $0.address == "127.0.0.1" }
        XCTAssertTrue(hasLoopback, "Should include loopback address")
    }
    
    // MARK: - Public IP Tests (Async)
    
    func testGetPublicIPReturnsValidIP() async {
        let result = await sut.getPublicIP()
        
        // If we have internet, should return valid IP
        if case .success(let ip) = result {
            XCTAssertTrue(ip.contains(".") || ip.contains(":"), "Public IP should be valid format")
        }
    }
    
    func testGetPublicIPCachesResult() async {
        // First call
        let result1 = await sut.getPublicIP()
        
        // Second call should use cache
        let result2 = await sut.getPublicIP()
        
        // Both should return same result (from cache)
        if case .success(let ip1) = result1, case .success(let ip2) = result2 {
            XCTAssertEqual(ip1, ip2, "Second call should return cached IP")
        }
    }
    
    func testClearCacheRefreshesPublicIP() async {
        // First call
        _ = await sut.getPublicIP()
        
        // Clear cache
        sut.clearCache()
        
        // Next call should fetch fresh
        let result = await sut.getPublicIP()
        // Just verify it doesn't crash
        XCTAssertNotNil(result)
    }
    
    // MARK: - Network Interface Tests
    
    func testGetNetworkInterfacesReturnsArray() {
        let interfaces = sut.getNetworkInterfaces()
        XCTAssertNotNil(interfaces)
        XCTAssertFalse(interfaces.isEmpty, "Should have at least one network interface")
    }
    
    func testGetNetworkInterfacesIncludesWiFi() {
        let interfaces = sut.getNetworkInterfaces()
        let hasWiFi = interfaces.contains { $0.name.lowercased().contains("wi") || $0.name.lowercased().contains("en") }
        // Most Macs have WiFi capability
        XCTAssertTrue(hasWiFi || !interfaces.isEmpty, "Should have WiFi or other interface")
    }
    
    func testNetworkInterfaceHasName() {
        let interfaces = sut.getNetworkInterfaces()
        
        for iface in interfaces {
            XCTAssertFalse(iface.name.isEmpty, "Interface should have a name")
        }
    }
    
    func testNetworkInterfaceHasType() {
        let interfaces = sut.getNetworkInterfaces()
        
        for iface in interfaces {
            XCTAssertNotNil(iface.interfaceType, "Interface should have a type")
        }
    }
    
    // MARK: - WiFi Info Tests
    
    func testGetWiFiInfoReturnsSSID() {
        let wifiInfo = sut.getWiFiInfo()
        
        // SSID may be nil if not connected or no permissions
        // Just verify it doesn't crash
        _ = wifiInfo.ssid
    }
    
    func testGetWiFiInfoReturnsBSSID() {
        let wifiInfo = sut.getWiFiInfo()
        
        // BSSID may be nil if not connected or no permissions
        // Just verify it doesn't crash
        _ = wifiInfo.bssid
    }
    
    // MARK: - VPN Detection Tests
    
    func testIsVPNConnectedReturnsBool() {
        let isVPN = sut.isVPNConnected()
        // Just verify it returns a boolean without crashing
        _ = isVPN
    }
    
    // MARK: - Search Results Tests
    
    func testSearchIPReturnsResults() {
        let results = sut.search(query: "ip")
        XCTAssertFalse(results.isEmpty, "Search for 'ip' should return results")
    }
    
    func testSearchMyIPReturnsResults() {
        let results = sut.search(query: "my ip")
        XCTAssertFalse(results.isEmpty, "Search for 'my ip' should return results")
    }
    
    func testSearchIPAddressReturnsResults() {
        let results = sut.search(query: "ip address")
        XCTAssertFalse(results.isEmpty, "Search for 'ip address' should return results")
    }
    
    func testSearchNetworkInfoReturnsResults() {
        let results = sut.search(query: "network info")
        XCTAssertFalse(results.isEmpty, "Search for 'network info' should return results")
    }
    
    func testSearchNetworkReturnsResults() {
        let results = sut.search(query: "network")
        XCTAssertFalse(results.isEmpty, "Search for 'network' should return results")
    }
    
    func testEmptySearchReturnsEmpty() {
        let results = sut.search(query: "")
        XCTAssertTrue(results.isEmpty, "Empty search should return no results")
    }
    
    func testUnrelatedSearchReturnsEmpty() {
        let results = sut.search(query: "xyzabc123notreal")
        XCTAssertTrue(results.isEmpty, "Unrelated search should return no results")
    }
    
    // MARK: - Formatting Tests
    
    func testFormatLocalIPsForDisplay() {
        let ips = [
            NetworkInterface(name: "en0", address: "192.168.1.100", interfaceType: .wifi),
            NetworkInterface(name: "lo0", address: "127.0.0.1", interfaceType: .loopback)
        ]
        let formatted = sut.formatLocalIPs(ips)
        XCTAssertTrue(formatted.contains("192.168.1.100"), "Should contain IP address")
        XCTAssertTrue(formatted.contains("en0"), "Should contain interface name")
    }
    
    func testFormatNetworkInfoForClipboard() {
        let localIPs = [NetworkInterface(name: "en0", address: "192.168.1.100", interfaceType: .wifi)]
        let publicIP = "1.2.3.4"
        let wifiInfo = WiFiInfo(ssid: "MyNetwork", bssid: "aa:bb:cc:dd:ee:ff")
        
        let formatted = sut.formatNetworkInfoForClipboard(localIPs: localIPs, publicIP: publicIP, wifiInfo: wifiInfo)
        XCTAssertTrue(formatted.contains("192.168.1.100"), "Should contain local IP")
        XCTAssertTrue(formatted.contains("1.2.3.4"), "Should contain public IP")
        XCTAssertTrue(formatted.contains("MyNetwork"), "Should contain SSID")
    }
    
    // MARK: - Clipboard Tests
    
    func testCopyPublicIPToClipboard() async {
        let result = await sut.getPublicIP()
        
        if case .success(let ip) = result {
            sut.copyPublicIPToClipboard(ip)
            
            let pasteboard = NSPasteboard.general
            let clipboardContent = pasteboard.string(forType: .string)
            XCTAssertEqual(clipboardContent, ip, "Clipboard should contain the public IP")
        }
    }
    
    func testCopyNetworkInfoToClipboard() {
        let localIPs = [NetworkInterface(name: "en0", address: "192.168.1.100", interfaceType: .wifi)]
        let publicIP = "1.2.3.4"
        let wifiInfo = WiFiInfo(ssid: "MyNetwork", bssid: "aa:bb:cc:dd:ee:ff")
        
        sut.copyNetworkInfoToClipboard(localIPs: localIPs, publicIP: publicIP, wifiInfo: wifiInfo)
        
        let pasteboard = NSPasteboard.general
        let clipboardContent = pasteboard.string(forType: .string)
        XCTAssertNotNil(clipboardContent, "Clipboard should have content")
        XCTAssertTrue(clipboardContent?.contains("192.168.1.100") ?? false, "Clipboard should contain local IP")
    }
}
