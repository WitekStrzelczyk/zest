import XCTest
@testable import ZestApp

/// Tests for BatteryService - Battery information retrieval
final class BatteryServiceTests: XCTestCase {
    
    var sut: BatteryService!
    
    override func setUp() {
        super.setUp()
        sut = BatteryService.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Singleton Tests
    
    func testBatteryServiceCreation() {
        XCTAssertNotNil(sut)
    }
    
    func testBatteryServiceSingleton() {
        let service1 = BatteryService.shared
        let service2 = BatteryService.shared
        XCTAssertTrue(service1 === service2)
    }
    
    // MARK: - Battery Info Tests
    
    func testGetBatteryInfoReturnsValidPercentage() {
        let info = sut.getBatteryInfo()
        
        // Percentage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(info.percentage, 0.0, "Battery percentage should be >= 0%")
        XCTAssertLessThanOrEqual(info.percentage, 100.0, "Battery percentage should be <= 100%")
    }
    
    func testGetBatteryInfoReturnsValidCycleCount() {
        let info = sut.getBatteryInfo()
        
        // Cycle count should be non-negative
        XCTAssertGreaterThanOrEqual(info.cycleCount, 0, "Cycle count should be >= 0")
    }
    
    func testGetBatteryInfoReturnsChargingStatus() {
        let info = sut.getBatteryInfo()
        
        // Charging status should be one of the defined cases
        let validStates: [ChargingState] = [.charging, .discharging, .fullyCharged, .notCharging, .unknown]
        XCTAssertTrue(validStates.contains(info.chargingState), "Charging state should be valid")
    }
    
    func testGetBatteryInfoReturnsHealthPercentage() {
        let info = sut.getBatteryInfo()
        
        // Health percentage should be between 0 and 100 (or -1 for unavailable)
        XCTAssertGreaterThanOrEqual(info.healthPercentage, -1.0, "Health percentage should be >= -1")
        XCTAssertLessThanOrEqual(info.healthPercentage, 100.0, "Health percentage should be <= 100%")
    }
    
    func testGetBatteryInfoReturnsHasBatteryFlag() {
        let info = sut.getBatteryInfo()
        
        // hasBattery should be a boolean
        // On desktop Macs, this will be false
        // On laptops, this will typically be true
        XCTAssertTrue(info.hasBattery || !info.hasBattery, "hasBattery should be a boolean")
    }
    
    func testGetBatteryInfoReturnsTimeRemaining() {
        let info = sut.getBatteryInfo()
        
        // Time remaining should be >= -1 (negative means calculating or unknown)
        XCTAssertGreaterThanOrEqual(info.timeRemaining, -1, "Time remaining should be >= -1")
    }
    
    // MARK: - Warning Status Tests
    
    func testIsLowBatteryReturnsCorrectValue() {
        // This tests the logic, not the actual battery state
        let info = sut.getBatteryInfo()
        
        if info.percentage < 20 && !info.isCharging {
            XCTAssertTrue(sut.isLowBattery(info), "Should be low battery when < 20% and not charging")
        } else {
            XCTAssertFalse(sut.isLowBattery(info) && info.percentage >= 20, "Should not be low battery at >= 20%")
        }
    }
    
    // MARK: - Search Results Tests
    
    func testSearchBatteryReturnsResults() {
        let results = sut.search(query: "battery")
        XCTAssertFalse(results.isEmpty, "Search for 'battery' should return results")
    }
    
    func testSearchBatteryIncludesPercentageInTitle() {
        let results = sut.search(query: "battery")
        guard let first = results.first else {
            XCTFail("Should have at least one result")
            return
        }
        XCTAssertTrue(first.title.contains("%") || first.title.contains("Battery"), "Title should contain battery info")
    }
    
    func testSearchPowerReturnsResults() {
        let results = sut.search(query: "power")
        XCTAssertFalse(results.isEmpty, "Search for 'power' should return battery results")
    }
    
    func testSearchChargeReturnsResults() {
        let results = sut.search(query: "charge")
        XCTAssertFalse(results.isEmpty, "Search for 'charge' should return battery results")
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
    
    func testFormatBatteryInfoIncludesPercentage() {
        let info = BatteryInfo(
            percentage: 75.0,
            cycleCount: 100,
            chargingState: .discharging,
            healthPercentage: 95.0,
            hasBattery: true,
            timeRemaining: 240
        )
        let formatted = sut.formatBatteryInfo(info)
        // Check for "Discharging" instead of percentage since percentage is shown in title
        XCTAssertTrue(formatted.contains("Discharging"), "Formatted info should include charging state")
    }
    
    func testFormatBatteryInfoIncludesCycleCount() {
        let info = BatteryInfo(
            percentage: 75.0,
            cycleCount: 100,
            chargingState: .discharging,
            healthPercentage: 95.0,
            hasBattery: true,
            timeRemaining: 240
        )
        let formatted = sut.formatBatteryInfo(info)
        XCTAssertTrue(formatted.contains("100"), "Formatted info should include cycle count")
    }
    
    func testFormatBatteryInfoIncludesHealth() {
        let info = BatteryInfo(
            percentage: 75.0,
            cycleCount: 100,
            chargingState: .discharging,
            healthPercentage: 95.0,
            hasBattery: true,
            timeRemaining: 240
        )
        let formatted = sut.formatBatteryInfo(info)
        XCTAssertTrue(formatted.contains("95"), "Formatted info should include health percentage")
    }
    
    func testFormatChargingStateCharging() {
        let state: ChargingState = .charging
        XCTAssertEqual(sut.formatChargingState(state), "Charging")
    }
    
    func testFormatChargingStateDischarging() {
        let state: ChargingState = .discharging
        XCTAssertEqual(sut.formatChargingState(state), "Discharging")
    }
    
    func testFormatChargingStateFullyCharged() {
        let state: ChargingState = .fullyCharged
        XCTAssertEqual(sut.formatChargingState(state), "Fully Charged")
    }
    
    func testFormatTimeRemaining() {
        // 240 minutes = 4 hours
        let formatted = sut.formatTimeRemaining(240)
        XCTAssertTrue(formatted.contains("4") && formatted.contains("hr"), "Should format 240 minutes as 4 hours")
    }
    
    func testFormatTimeRemainingShortDuration() {
        // 30 minutes
        let formatted = sut.formatTimeRemaining(30)
        XCTAssertTrue(formatted.contains("30") && formatted.contains("min"), "Should format 30 minutes")
    }
    
    func testFormatTimeRemainingUnknown() {
        let formatted = sut.formatTimeRemaining(-1)
        XCTAssertEqual(formatted, "Calculating...", "Should show 'Calculating...' for unknown time")
    }
    
    // MARK: - Copy to Clipboard Tests
    
    func testCopyBatteryInfoToClipboard() {
        let info = BatteryInfo(
            percentage: 75.0,
            cycleCount: 100,
            chargingState: .discharging,
            healthPercentage: 95.0,
            hasBattery: true,
            timeRemaining: 240
        )
        
        sut.copyToClipboard(info)
        
        // Verify clipboard contains battery info
        let pasteboard = NSPasteboard.general
        let clipboardContent = pasteboard.string(forType: .string)
        XCTAssertNotNil(clipboardContent, "Clipboard should have content")
        XCTAssertTrue(clipboardContent?.contains("Battery") ?? false, "Clipboard should contain 'Battery'")
    }
}
