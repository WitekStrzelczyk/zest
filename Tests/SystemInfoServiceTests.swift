import AppKit
import Testing
@testable import ZestApp

@MainActor
final class SystemInfoServiceTests {
    var sut: SystemInfoService!
    
    init() {
        sut = SystemInfoService.shared
    }
    
    isolated deinit {
        sut = nil
    }
    
    @Test func testSystemInfoServiceCreation() {
        #expect(sut != nil)
    }
    
    @Test func testSystemInfoServiceSingleton() {
        let service1 = SystemInfoService.shared
        let service2 = SystemInfoService.shared
        #expect(service1 === service2)
    }
    
    @Test func testGetStorageInfoReturnsValidTotalStorage() {
        let info = sut.getStorageInfo()
        
        #expect(info.totalBytes > 0, "Total storage should be > 0")
    }
    
    @Test func testGetStorageInfoReturnsValidAvailableStorage() {
        let info = sut.getStorageInfo()
        
        #expect(info.availableBytes >= 0, "Available storage should be >= 0")
    }
    
    @Test func testGetStorageInfoReturnsValidUsedStorage() {
        let info = sut.getStorageInfo()
        
        #expect(info.usedBytes >= 0, "Used storage should be >= 0")
    }
    
    @Test func testGetStorageInfoReturnsValidUsagePercentage() {
        let info = sut.getStorageInfo()
        
        #expect(info.usagePercentage >= 0.0, "Usage percentage should be >= 0%")
        #expect(info.usagePercentage <= 100.0, "Usage percentage should be <= 100%")
    }
    
    @Test func testGetStorageInfoCalculatesCorrectly() {
        let info = sut.getStorageInfo()
        
        let calculatedTotal = info.availableBytes + info.usedBytes
        #expect(info.totalBytes == calculatedTotal, "Total should equal available + used")
    }
    
    @Test func testGetSystemInfoReturnsMacOSVersion() {
        let info = sut.getSystemInfo()
        
        #expect(!info.macOSVersion.isEmpty, "macOS version should not be empty")
        #expect(info.macOSVersion.contains("macOS") || info.macOSVersion.contains("."), "macOS version should contain version info")
    }
    
    @Test func testGetSystemInfoReturnsModelName() {
        let info = sut.getSystemInfo()
        
        #expect(!info.modelName.isEmpty, "Model name should not be empty")
    }
    
    @Test func testGetSystemInfoReturnsChipInfo() {
        let info = sut.getSystemInfo()
        
        _ = info.chipInfo
    }
    
    @Test func testGetSystemInfoReturnsMemory() {
        let info = sut.getSystemInfo()
        
        #expect(!info.memory.isEmpty, "Memory should not be empty")
        #expect(info.memory.contains("GB") || info.memory.contains("MB"), "Memory should contain GB or MB")
    }
    
    @Test func testGetSystemInfoReturnsHostName() {
        let info = sut.getSystemInfo()
        
        #expect(!info.hostName.isEmpty, "Host name should not be empty")
    }
    
    @Test func testIsStorageNearlyFullReturnsCorrectValue() {
        let info = sut.getStorageInfo()
        
        if info.usagePercentage > 90 {
            #expect(sut.isStorageNearlyFull(info), "Should be nearly full at > 90%")
        } else {
            #expect(!sut.isStorageNearlyFull(info), "Should not be nearly full at <= 90%")
        }
    }
    
    @Test func testSearchStorageReturnsResults() {
        let results = sut.search(query: "storage")
        #expect(!results.isEmpty, "Search for 'storage' should return results")
    }
    
    @Test func testSearchDiskReturnsResults() {
        let results = sut.search(query: "disk")
        #expect(!results.isEmpty, "Search for 'disk' should return results")
    }
    
    @Test func testSearchSpaceReturnsResults() {
        let results = sut.search(query: "space")
        #expect(!results.isEmpty, "Search for 'space' should return results")
    }
    
    @Test func testSearchSystemInfoReturnsResults() {
        let results = sut.search(query: "system info")
        #expect(!results.isEmpty, "Search for 'system info' should return results")
    }
    
    @Test func testSearchAboutReturnsResults() {
        let results = sut.search(query: "about")
        #expect(!results.isEmpty, "Search for 'about' should return results")
    }
    
    @Test func testSearchMacReturnsResults() {
        let results = sut.search(query: "mac")
        #expect(!results.isEmpty, "Search for 'mac' should return results")
    }
    
    @Test func testSearchSpecsReturnsResults() {
        let results = sut.search(query: "specs")
        #expect(!results.isEmpty, "Search for 'specs' should return results")
    }
    
    @Test func testEmptySearchReturnsEmpty() {
        let results = sut.search(query: "")
        #expect(results.isEmpty, "Empty search should return no results")
    }
    
    @Test func testUnrelatedSearchReturnsEmpty() {
        let results = sut.search(query: "xyzabc123notreal")
        #expect(results.isEmpty, "Unrelated search should return no results")
    }
    
    @Test func testFormatStorageInfoIncludesAvailable() {
        let info = StorageInfo(
            totalBytes: 536_870_912_000,
            availableBytes: 107_374_182_400,
            usedBytes: 429_496_729_600
        )
        let formatted = sut.formatStorageInfo(info)
        #expect(formatted.contains("GB"), "Should include GB unit")
        #expect(formatted.contains("available"), "Should mention available")
    }
    
    @Test func testFormatStorageInfoIncludesTotal() {
        let info = StorageInfo(
            totalBytes: 536_870_912_000,
            availableBytes: 107_374_182_400,
            usedBytes: 429_496_729_600
        )
        let formatted = sut.formatStorageInfo(info)
        #expect(formatted.contains("GB"), "Should include GB unit")
        #expect(formatted.contains("of"), "Should format as 'X of Y'")
    }
    
    @Test func testFormatBytesGB() {
        let formatted = sut.formatBytes(500_000_000_000)
        #expect(formatted.contains("GB"), "Should format as GB")
    }
    
    @Test func testFormatBytesTB() {
        let formatted = sut.formatBytes(2_000_000_000_000)
        #expect(formatted.contains("TB"), "Should format as TB")
    }
    
    @Test func testFormatBytesMB() {
        let formatted = sut.formatBytes(500_000_000)
        #expect(formatted.contains("MB"), "Should format as MB")
    }
    
    @Test func testFormatSystemInfoForClipboard() {
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
        #expect(formatted.contains("macOS"), "Should contain macOS version")
        #expect(formatted.contains("MacBook Pro"), "Should contain model name")
        #expect(formatted.contains("16 GB"), "Should contain memory")
    }
    
    @Test func testCopySystemInfoToClipboard() {
        let info = SystemInfo(
            macOSVersion: "macOS 14.0",
            modelName: "MacBook Pro",
            chipInfo: "Apple M1 Pro",
            memory: "16 GB",
            hostName: "MyMac"
        )
        
        sut.copyToClipboard(info)
        
        let pasteboard = NSPasteboard.general
        let clipboardContent = pasteboard.string(forType: .string)
        #expect(clipboardContent != nil, "Clipboard should have content")
        #expect(clipboardContent?.contains("MacBook Pro") ?? false, "Clipboard should contain model name")
    }
    
    @Test func testCopyStorageInfoToClipboard() {
        let info = StorageInfo(
            totalBytes: 500_000_000_000,
            availableBytes: 100_000_000_000,
            usedBytes: 400_000_000_000
        )
        
        sut.copyToClipboard(info)
        
        let pasteboard = NSPasteboard.general
        let clipboardContent = pasteboard.string(forType: .string)
        #expect(clipboardContent != nil, "Clipboard should have content")
        #expect(clipboardContent?.contains("Storage") ?? false, "Clipboard should contain storage info")
    }
}
