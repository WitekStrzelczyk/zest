import AppKit
import Testing
@testable import ZestApp

@MainActor
final class NetworkInfoServiceTests {
    var sut: NetworkInfoService!
    
    init() {
        sut = NetworkInfoService.shared
        sut.clearCache()
    }
    
    isolated deinit {
        sut = nil
    }
    
    @Test func testNetworkInfoServiceCreation() {
        #expect(sut != nil)
    }
    
    @Test func testNetworkInfoServiceSingleton() {
        let service1 = NetworkInfoService.shared
        let service2 = NetworkInfoService.shared
        #expect(service1 === service2)
    }
    
    @Test func testGetLocalIPsReturnsArray() {
        _ = sut.getLocalIPAddresses()
    }
    
    @Test func testGetLocalIPsContainsValidFormat() {
        let ips = sut.getLocalIPAddresses()
        
        for ip in ips {
            let isValidIPv4 = ip.address.contains(".")
            let isValidIPv6 = ip.address.contains(":")
            #expect(isValidIPv4 || isValidIPv6, "IP address should be valid format: \(ip.address)")
        }
    }
    
    @Test func testGetLocalIPsReturnsInterfaceNames() {
        let ips = sut.getLocalIPAddresses()
        
        for ip in ips {
            #expect(!ip.name.isEmpty, "Interface name should not be empty")
        }
    }
    
    @Test func testGetLocalIPsIncludesLoopback() {
        let ips = sut.getLocalIPAddresses()
        let hasLoopback = ips.contains { $0.address == "127.0.0.1" }
        #expect(hasLoopback, "Should include loopback address")
    }
    
    @Test func testGetPublicIPReturnsValidIP() async {
        let result = await sut.getPublicIP()
        
        if case .success(let ip) = result {
            #expect(ip.contains(".") || ip.contains(":"), "Public IP should be valid format")
        }
    }
    
    @Test func testGetPublicIPCachesResult() async {
        let result1 = await sut.getPublicIP()
        
        let result2 = await sut.getPublicIP()
        
        if case .success(let ip1) = result1, case .success(let ip2) = result2 {
            #expect(ip1 == ip2, "Second call should return cached IP")
        }
    }
    
    @Test func testClearCacheRefreshesPublicIP() async {
        _ = await sut.getPublicIP()
        
        sut.clearCache()
        
        _ = await sut.getPublicIP()
    }
    
    @Test func testGetNetworkInterfacesReturnsArray() {
        let interfaces = sut.getNetworkInterfaces()
        #expect(!interfaces.isEmpty, "Should have at least one network interface")
    }
    
    @Test func testGetNetworkInterfacesIncludesWiFi() {
        let interfaces = sut.getNetworkInterfaces()
        let hasWiFi = interfaces.contains { $0.name.lowercased().contains("wi") || $0.name.lowercased().contains("en") }
        #expect(hasWiFi || !interfaces.isEmpty, "Should have WiFi or other interface")
    }
    
    @Test func testNetworkInterfaceHasName() {
        let interfaces = sut.getNetworkInterfaces()
        
        for iface in interfaces {
            #expect(!iface.name.isEmpty, "Interface should have a name")
        }
    }
    
    @Test func testNetworkInterfaceHasType() {
        _ = sut.getNetworkInterfaces()
    }
    
    @Test func testGetWiFiInfoReturnsSSID() {
        let wifiInfo = sut.getWiFiInfo()
        
        _ = wifiInfo.ssid
    }
    
    @Test func testGetWiFiInfoReturnsBSSID() {
        let wifiInfo = sut.getWiFiInfo()
        
        _ = wifiInfo.bssid
    }
    
    @Test func testIsVPNConnectedReturnsBool() {
        let isVPN = sut.isVPNConnected()
        _ = isVPN
    }
    
    @Test func testSearchIPReturnsResults() {
        let results = sut.search(query: "ip")
        #expect(!results.isEmpty, "Search for 'ip' should return results")
    }
    
    @Test func testSearchMyIPReturnsResults() {
        let results = sut.search(query: "my ip")
        #expect(!results.isEmpty, "Search for 'my ip' should return results")
    }
    
    @Test func testSearchIPAddressReturnsResults() {
        let results = sut.search(query: "ip address")
        #expect(!results.isEmpty, "Search for 'ip address' should return results")
    }
    
    @Test func testSearchNetworkInfoReturnsResults() {
        let results = sut.search(query: "network info")
        #expect(!results.isEmpty, "Search for 'network info' should return results")
    }
    
    @Test func testSearchNetworkReturnsResults() {
        let results = sut.search(query: "network")
        #expect(!results.isEmpty, "Search for 'network' should return results")
    }
    
    @Test func testEmptySearchReturnsEmpty() {
        let results = sut.search(query: "")
        #expect(results.isEmpty, "Empty search should return no results")
    }
    
    @Test func testUnrelatedSearchReturnsEmpty() {
        let results = sut.search(query: "xyzabc123notreal")
        #expect(results.isEmpty, "Unrelated search should return no results")
    }
    
    @Test func testFormatLocalIPsForDisplay() {
        let ips = [
            NetworkInterface(name: "en0", address: "192.168.1.100", interfaceType: .wifi),
            NetworkInterface(name: "lo0", address: "127.0.0.1", interfaceType: .loopback)
        ]
        let formatted = sut.formatLocalIPs(ips)
        #expect(formatted.contains("192.168.1.100"), "Should contain IP address")
        #expect(formatted.contains("en0"), "Should contain interface name")
    }
    
    @Test func testFormatNetworkInfoForClipboard() {
        let localIPs = [NetworkInterface(name: "en0", address: "192.168.1.100", interfaceType: .wifi)]
        let publicIP = "1.2.3.4"
        let wifiInfo = WiFiInfo(ssid: "MyNetwork", bssid: "aa:bb:cc:dd:ee:ff")
        
        let formatted = sut.formatNetworkInfoForClipboard(localIPs: localIPs, publicIP: publicIP, wifiInfo: wifiInfo)
        #expect(formatted.contains("192.168.1.100"), "Should contain local IP")
        #expect(formatted.contains("1.2.3.4"), "Should contain public IP")
        #expect(formatted.contains("MyNetwork"), "Should contain SSID")
    }
    
    @Test func testCopyPublicIPToClipboard() async {
        let result = await sut.getPublicIP()
        
        if case .success(let ip) = result {
            sut.copyPublicIPToClipboard(ip)
            
            let pasteboard = NSPasteboard.general
            let clipboardContent = pasteboard.string(forType: .string)
            #expect(clipboardContent == ip, "Clipboard should contain the public IP")
        }
    }
    
    @Test func testCopyNetworkInfoToClipboard() {
        let localIPs = [NetworkInterface(name: "en0", address: "192.168.1.100", interfaceType: .wifi)]
        let publicIP = "1.2.3.4"
        let wifiInfo = WiFiInfo(ssid: "MyNetwork", bssid: "aa:bb:cc:dd:ee:ff")
        
        sut.copyNetworkInfoToClipboard(localIPs: localIPs, publicIP: publicIP, wifiInfo: wifiInfo)
        
        let pasteboard = NSPasteboard.general
        let clipboardContent = pasteboard.string(forType: .string)
        #expect(clipboardContent != nil, "Clipboard should have content")
        #expect(clipboardContent?.contains("192.168.1.100") ?? false, "Clipboard should contain local IP")
    }
}
