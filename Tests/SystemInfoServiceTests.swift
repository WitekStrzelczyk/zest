import XCTest
@testable import ZestApp

/// Tests for SystemInfoService - Storage and System information retrieval
final class SystemInfoServiceTests: XCTestCase {
    
    var sut: SystemInfoService!
    
    override func setUp() {
        super.setUp()
        sut = SystemInfoService.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Singleton Tests
    
    func testSystemInfoServiceCreation() {
        XCTAssertNotNil(sut)
    }
    
    func testSystemInfoServiceSingleton() {
        let service1 = SystemInfoService.shared
        let service2 = SystemInfoService.shared
        XCTAssertTrue(service1 === service2)
    }
    
    // MARK: - Storage Info Tests
    
    func testGetStorageInfoReturnsValidTotalStorage() {
        let info = sut.getStorageInfo()
        
        // Total storage should be positive (at least a few GB)
        XCTAssertGreaterThan(info.totalBytes, 0, "Total storage should be > 0")
    }
    
    func testGetStorageInfoReturnsValidAvailableStorage() {
        let info = sut.getStorageInfo()
        
        // Available storage should be >= 0
        XCTAssertGreaterThanOrEqual(info.availableBytes, 0, "Available storage should be >= 0")
    }
    
    func testGetStorageInfoReturnsValidUsedStorage() {
        let info = sut.getStorageInfo()
        
        // Used storage should be >= 0
        XCTAssertGreaterThanOrEqual(info.usedBytes, 0, "Used storage should be >= 0")
    }
    
    func testGetStorageInfoReturnsValidUsagePercentage() {
        let info = sut.getStorageInfo()
        
        // Usage percentage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(info.usagePercentage, 0.0, "Usage percentage should be >= 0%")
        XCTAssertLessThanOrEqual(info.usagePercentage, 100.0, "Usage percentage should be <= 100%")
    }
    
    func testGetStorageInfoCalculatesCorrectly() {
        let info = sut.getStorageInfo()
        
        // Total = Available + Used (approximately)
        let calculatedTotal = info.availableBytes + info.usedBytes
        XCTAssertEqual(info.totalBytes, calculatedTotal, "Total should equal available + used")
    }
    
    // MARK: - System Info Tests
    
    func testGetSystemInfoReturnsMacOSVersion() {
        let info = sut.getSystemInfo()
        
        XCTAssertFalse(info.macOSVersion.isEmpty, "macOS version should not be empty")
        XCTAssertTrue(info.macOSVersion.contains("macOS") || info.macOSVersion.contains("."), "macOS version should contain version info")
    }
    
    func testGetSystemInfoReturnsModelName() {
        let info = sut.getSystemInfo()
        
        XCTAssertFalse(info.modelName.isEmpty, "Model name should not be empty")
    }
    
    func testGetSystemInfoReturnsChipInfo() {
        let info = sut.getSystemInfo()
        
        // Chip info may be empty on older Intel Macs
        // Just verify it doesn't crash
        _ = info.chipInfo
    }
    
    func testGetSystemInfoReturnsMemory() {
        let info = sut.getSystemInfo()
        
        XCTAssertFalse(info.memory.isEmpty, "Memory should not be empty")
        XCTAssertTrue(info.memory.contains("GB") || info.memory.contains("MB"), "Memory should contain GB or MB")
    }
    
    func testGetSystemInfoReturnsHostName() {
        let info = sut.getSystemInfo()
        
        XCTAssertFalse(info.hostName.isEmpty, "Host name should not be empty")
    }
    
    // MARK: - Warning Status Tests
    
    func testIsStorageNearlyFullReturnsCorrectValue() {
        let info = sut.getStorageInfo()
        
        if info.usagePercentage > 90 {
            XCTAssertTrue(sut.isStorageNearlyFull(info), "Should be nearly full at > 90%")
        } else {
            XCTAssertFalse(sut.isStorageNearlyFull(info), "Should not be nearly full at <= 90%")
        }
    }
    
    // MARK: - Search Results Tests - Storage
    
    func testSearchStorageReturnsResults() {
        let results = sut.search(query: "storage")
        XCTAssertFalse(results.isEmpty, "Search for 'storage' should return results")
    }
    
    func testSearchDiskReturnsResults() {
        let results = sut.search(query: "disk")
        XCTAssertFalse(results.isEmpty, "Search for 'disk' should return results")
    }
    
    func testSearchSpaceReturnsResults() {
        let results = sut.search(query: "space")
        XCTAssertFalse(results.isEmpty, "Search for 'space' should return results")
    }
    
    // MARK: - Search Results Tests - System Info
    
    func testSearchSystemInfoReturnsResults() {
        let results = sut.search(query: "system info")
        XCTAssertFalse(results.isEmpty, "Search for 'system info' should return results")
    }
    
    func testSearchAboutReturnsResults() {
        let results = sut.search(query: "about")
        XCTAssertFalse(results.isEmpty, "Search for 'about' should return results")
    }
    
    func testSearchMacReturnsResults() {
        let results = sut.search(query: "mac")
        XCTAssertFalse(results.isEmpty, "Search for 'mac' should return results")
    }
    
    func testSearchSpecsReturnsResults() {
        let results = sut.search(query: "specs")
        XCTAssertFalse(results.isEmpty, "Search for 'specs' should return results")
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
    
    func testFormatStorageInfoIncludesAvailable() {
        // Use exact GB values (1 GB = 1_073_741_824 bytes)
        let info = StorageInfo(
            totalBytes: 536_870_912_000, // 500 GB exactly
            availableBytes: 107_374_182_400, // 100 GB exactly
            usedBytes: 429_496_729_600
        )
        let formatted = sut.formatStorageInfo(info)
        XCTAssertTrue(formatted.contains("GB"), "Should include GB unit")
        XCTAssertTrue(formatted.contains("available"), "Should mention available")
    }
    
    func testFormatStorageInfoIncludesTotal() {
        // Use exact GB values (1 GB = 1_073_741_824 bytes)
        let info = StorageInfo(
            totalBytes: 536_870_912_000, // 500 GB exactly
            availableBytes: 107_374_182_400, // 100 GB exactly
            usedBytes: 429_496_729_600
        )
        let formatted = sut.formatStorageInfo(info)
        XCTAssertTrue(formatted.contains("GB"), "Should include GB unit")
        XCTAssertTrue(formatted.contains("of"), "Should format as 'X of Y'")
    }
    
    func testFormatBytesGB() {
        let formatted = sut.formatBytes(500_000_000_000)
        XCTAssertTrue(formatted.contains("GB"), "Should format as GB")
    }
    
    func testFormatBytesTB() {
        let formatted = sut.formatBytes(2_000_000_000_000)
        XCTAssertTrue(formatted.contains("TB"), "Should format as TB")
    }
    
    func testFormatBytesMB() {
        let formatted = sut.formatBytes(500_000_000)
        XCTAssertTrue(formatted.contains("MB"), "Should format as MB")
    }
    
    func testFormatSystemInfoForClipboard() {
        let systemInfo = SystemInfo(
            macOSVersion: "macOS 14.0",
            modelName: "MacBook Pro",
            chipInfo: "Apple M1 Pro",
            memory: "16 GB",
            hostName: "MyMac"
        )
        let storageInfo = StorageInfo(
            totalBytes: 500_000_000_000,
            availableBytes: 100_000_000_000,
            usedBytes: 400_000_000_000
        )
        
        let formatted = sut.formatSystemInfoForClipboard(systemInfo: systemInfo, storageInfo: storageInfo)
        XCTAssertTrue(formatted.contains("macOS"), "Should contain macOS version")
        XCTAssertTrue(formatted.contains("MacBook Pro"), "Should contain model name")
        XCTAssertTrue(formatted.contains("16 GB"), "Should contain memory")
    }
    
    // MARK: - Copy to Clipboard Tests
    
    func testCopySystemInfoToClipboard() {
        let info = SystemInfo(
            macOSVersion: "macOS 14.0",
            modelName: "MacBook Pro",
            chipInfo: "Apple M1 Pro",
            memory: "16 GB",
            hostName: "MyMac"
        )
        
        sut.copyToClipboard(info)
        
        // Verify clipboard contains system info
        let pasteboard = NSPasteboard.general
        let clipboardContent = pasteboard.string(forType: .string)
        XCTAssertNotNil(clipboardContent, "Clipboard should have content")
        XCTAssertTrue(clipboardContent?.contains("MacBook Pro") ?? false, "Clipboard should contain model name")
    }
    
    func testCopyStorageInfoToClipboard() {
        let info = StorageInfo(
            totalBytes: 500_000_000_000,
            availableBytes: 100_000_000_000,
            usedBytes: 400_000_000_000
        )
        
        sut.copyToClipboard(info)
        
        // Verify clipboard contains storage info
        let pasteboard = NSPasteboard.general
        let clipboardContent = pasteboard.string(forType: .string)
        XCTAssertNotNil(clipboardContent, "Clipboard should have content")
        XCTAssertTrue(clipboardContent?.contains("Storage") ?? false, "Clipboard should contain storage info")
    }
}
