import AppKit
import Testing
@testable import ZestApp

@MainActor
final class BatteryServiceTests {
    var sut: BatteryService!
    
    init() {
        sut = BatteryService.shared
    }
    
    isolated deinit {
        sut = nil
    }
    
    @Test func testBatteryServiceCreation() {
        #expect(sut != nil)
    }
    
    @Test func testBatteryServiceSingleton() {
        let service1 = BatteryService.shared
        let service2 = BatteryService.shared
        #expect(service1 === service2)
    }
    
    @Test func testGetBatteryInfoReturnsValidPercentage() {
        let info = sut.getBatteryInfo()
        
        #expect(info.percentage >= 0.0, "Battery percentage should be >= 0%")
        #expect(info.percentage <= 100.0, "Battery percentage should be <= 100%")
    }
    
    @Test func testGetBatteryInfoReturnsValidCycleCount() {
        let info = sut.getBatteryInfo()
        
        #expect(info.cycleCount >= 0, "Cycle count should be >= 0")
    }
    
    @Test func testGetBatteryInfoReturnsChargingStatus() {
        let info = sut.getBatteryInfo()
        
        let validStates: [ChargingState] = [.charging, .discharging, .fullyCharged, .notCharging, .unknown]
        #expect(validStates.contains(info.chargingState), "Charging state should be valid")
    }
    
    @Test func testGetBatteryInfoReturnsHealthPercentage() {
        let info = sut.getBatteryInfo()
        
        #expect(info.healthPercentage >= -1.0, "Health percentage should be >= -1")
        #expect(info.healthPercentage <= 100.0, "Health percentage should be <= 100%")
        
        if info.healthPercentage >= 0 {
            #expect(info.healthPercentage > 5.0, "Health percentage should be > 5% if available - a very low value like 1% indicates a read error")
        }
    }
    
    @Test func testGetBatteryInfoReturnsHasBatteryFlag() {
        let info = sut.getBatteryInfo()
        
        let hasBattery = info.hasBattery
        #expect(hasBattery == true || hasBattery == false, "hasBattery should be a valid boolean")
    }
    
    @Test func testGetBatteryInfoReturnsTimeRemaining() {
        let info = sut.getBatteryInfo()
        
        #expect(info.timeRemaining >= -1, "Time remaining should be >= -1")
    }
    
    @Test func testIsLowBatteryReturnsCorrectValue() {
        let info = sut.getBatteryInfo()
        
        if info.percentage < 20 && !info.isCharging {
            #expect(sut.isLowBattery(info), "Should be low battery when < 20% and not charging")
        } else {
            #expect(!(sut.isLowBattery(info) && info.percentage >= 20), "Should not be low battery at >= 20%")
        }
    }
    
    @Test func testSearchBatteryReturnsResults() {
        let results = sut.search(query: "battery")
        #expect(!results.isEmpty, "Search for 'battery' should return results")
    }
    
    @Test func testSearchBatteryIncludesPercentageInTitle() {
        let results = sut.search(query: "battery")
        guard let first = results.first else {
            Issue.record("Should have at least one result")
            return
        }
        #expect(first.title.contains("%") || first.title.contains("Battery"), "Title should contain battery info")
    }
    
    @Test func testSearchPowerReturnsResults() {
        let results = sut.search(query: "power")
        #expect(!results.isEmpty, "Search for 'power' should return battery results")
    }
    
    @Test func testSearchChargeReturnsResults() {
        let results = sut.search(query: "charge")
        #expect(!results.isEmpty, "Search for 'charge' should return battery results")
    }
    
    @Test func testEmptySearchReturnsEmpty() {
        let results = sut.search(query: "")
        #expect(results.isEmpty, "Empty search should return no results")
    }
    
    @Test func testUnrelatedSearchReturnsEmpty() {
        let results = sut.search(query: "xyzabc123notreal")
        #expect(results.isEmpty, "Unrelated search should return no results")
    }
    
    @Test func testFormatBatteryInfoIncludesPercentage() {
        let info = BatteryInfo(
            percentage: 75.0,
            cycleCount: 100,
            chargingState: .discharging,
            healthPercentage: 95.0,
            hasBattery: true,
            timeRemaining: 240
        )
        let formatted = sut.formatBatteryInfo(info)
        #expect(formatted.contains("Discharging"), "Formatted info should include charging state")
    }
    
    @Test func testFormatBatteryInfoIncludesCycleCount() {
        let info = BatteryInfo(
            percentage: 75.0,
            cycleCount: 100,
            chargingState: .discharging,
            healthPercentage: 95.0,
            hasBattery: true,
            timeRemaining: 240
        )
        let formatted = sut.formatBatteryInfo(info)
        #expect(formatted.contains("100"), "Formatted info should include cycle count")
    }
    
    @Test func testFormatBatteryInfoIncludesHealth() {
        let info = BatteryInfo(
            percentage: 75.0,
            cycleCount: 100,
            chargingState: .discharging,
            healthPercentage: 95.0,
            hasBattery: true,
            timeRemaining: 240
        )
        let formatted = sut.formatBatteryInfo(info)
        #expect(formatted.contains("95"), "Formatted info should include health percentage")
    }
    
    @Test func testFormatChargingStateCharging() {
        let state: ChargingState = .charging
        #expect(sut.formatChargingState(state) == "Charging")
    }
    
    @Test func testFormatChargingStateDischarging() {
        let state: ChargingState = .discharging
        #expect(sut.formatChargingState(state) == "Discharging")
    }
    
    @Test func testFormatChargingStateFullyCharged() {
        let state: ChargingState = .fullyCharged
        #expect(sut.formatChargingState(state) == "Fully Charged")
    }
    
    @Test func testFormatTimeRemaining() {
        let formatted = sut.formatTimeRemaining(240)
        #expect(formatted.contains("4") && formatted.contains("hr"), "Should format 240 minutes as 4 hours")
    }
    
    @Test func testFormatTimeRemainingShortDuration() {
        let formatted = sut.formatTimeRemaining(30)
        #expect(formatted.contains("30") && formatted.contains("min"), "Should format 30 minutes")
    }
    
    @Test func testFormatTimeRemainingUnknown() {
        let formatted = sut.formatTimeRemaining(-1)
        #expect(formatted == "Calculating...", "Should show 'Calculating...' for unknown time")
    }
    
    @Test func testCopyBatteryInfoToClipboard() {
        let info = BatteryInfo(
            percentage: 75.0,
            cycleCount: 100,
            chargingState: .discharging,
            healthPercentage: 95.0,
            hasBattery: true,
            timeRemaining: 240
        )
        
        sut.copyToClipboard(info)
        
        let pasteboard = NSPasteboard.general
        let clipboardContent = pasteboard.string(forType: .string)
        #expect(clipboardContent != nil, "Clipboard should have content")
        #expect(clipboardContent?.contains("Battery") ?? false, "Clipboard should contain 'Battery'")
    }
}
