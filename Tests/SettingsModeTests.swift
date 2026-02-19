import XCTest
@testable import ZestApp

/// Tests for settings mode functionality in CommandPaletteWindow
final class SettingsModeTests: XCTestCase {
    
    var window: CommandPaletteWindow!
    
    override func setUp() {
        super.setUp()
        window = CommandPaletteWindow()
    }
    
    override func tearDown() {
        window.close()
        window = nil
        super.tearDown()
    }
    
    // MARK: - Mode State Tests
    
    func test_settingsModeDefaultsToFalse() {
        XCTAssertFalse(window.isSettingsMode)
    }
    
    func test_enterSettingsMode_setsIsSettingsModeTrue() {
        // Given: Window is in normal mode
        XCTAssertFalse(window.isSettingsMode)
        
        // When: Entering settings mode
        window.enterSettingsMode()
        
        // Then: isSettingsMode should be true
        XCTAssertTrue(window.isSettingsMode)
    }
    
    func test_exitSettingsMode_setsIsSettingsModeFalse() {
        // Given: Window is in settings mode
        window.enterSettingsMode()
        XCTAssertTrue(window.isSettingsMode)
        
        // When: Exiting settings mode
        window.exitSettingsMode()
        
        // Then: isSettingsMode should be false
        XCTAssertFalse(window.isSettingsMode)
    }
    
    func test_cannotEnterSettingsModeTwice() {
        // Given: Already in settings mode
        window.enterSettingsMode()
        XCTAssertTrue(window.isSettingsMode)
        
        // When: Try to enter again
        window.enterSettingsMode()
        
        // Then: Should still be in settings mode (no crash)
        XCTAssertTrue(window.isSettingsMode)
    }
    
    func test_cannotExitSettingsModeWhenNotInSettingsMode() {
        // Given: Not in settings mode
        XCTAssertFalse(window.isSettingsMode)
        
        // When: Try to exit
        window.exitSettingsMode()
        
        // Then: Should still not be in settings mode (no crash)
        XCTAssertFalse(window.isSettingsMode)
    }
    
    // MARK: - Search Results Clearing Tests
    
    func test_enterSettingsMode_clearsSearchResults() {
        // Given: Window is shown
        window.show()
        
        // When: Entering settings mode
        window.enterSettingsMode()
        
        // Then: Search results should be cleared
        XCTAssertTrue(window.searchResults.isEmpty)
    }
    
    func test_exitSettingsMode_clearsSearchResults() {
        // Given: In settings mode
        window.enterSettingsMode()
        
        // When: Exiting settings mode
        window.exitSettingsMode()
        
        // Then: Search results should be cleared
        XCTAssertTrue(window.searchResults.isEmpty)
    }
    
    func test_close_clearsSearchResults() {
        // Given: Window is shown
        window.show()
        
        // When: Closing window
        window.close()
        
        // Then: Search results should be cleared for next open
        XCTAssertTrue(window.searchResults.isEmpty)
    }
    
    // MARK: - UI Visibility Tests
    
    func test_enterSettingsMode_hidesSearchField() {
        // Given: Window is shown
        window.show()
        
        // When: Entering settings mode
        window.enterSettingsMode()
        
        // Then: Search field should be hidden
        XCTAssertTrue(window.searchField.isHidden)
    }
    
    func test_exitSettingsMode_showsSearchField() {
        // Given: In settings mode
        window.enterSettingsMode()
        
        // When: Exiting settings mode
        window.exitSettingsMode()
        
        // Then: Search field should be visible
        XCTAssertFalse(window.searchField.isHidden)
    }
    
    // MARK: - Escape Handling Tests
    
    func test_escapeInSettingsMode_exitsSettings() {
        // Given: In settings mode
        window.enterSettingsMode()
        XCTAssertTrue(window.isSettingsMode)
        
        // When: Escape is pressed
        window.handleEscape()
        
        // Then: Should exit settings mode
        XCTAssertFalse(window.isSettingsMode)
    }
    
    func test_escapeOutsideSettingsMode_closesWindow() {
        // Given: Window is shown but not in settings mode
        window.show()
        
        // When: Escape is pressed
        window.handleEscape()
        
        // Then: Window should close (isVisible will be false)
        XCTAssertFalse(window.isVisible)
    }
}
