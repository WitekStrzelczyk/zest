import AppKit
import Testing
@testable import ZestApp

@MainActor
final class SettingsModeTests {
    var window: CommandPaletteWindow!
    
    init() {
        window = CommandPaletteWindow()
    }
    
    isolated deinit {
        window.close()
        window = nil
    }
    
    @Test func test_settingsModeDefaultsToFalse() {
        #expect(!window.isSettingsMode)
    }
    
    @Test func test_enterSettingsMode_setsIsSettingsModeTrue() {
        #expect(!window.isSettingsMode)
        
        window.enterSettingsMode()
        
        #expect(window.isSettingsMode)
    }
    
    @Test func test_exitSettingsMode_setsIsSettingsModeFalse() {
        window.enterSettingsMode()
        #expect(window.isSettingsMode)
        
        window.exitSettingsMode()
        
        #expect(!window.isSettingsMode)
    }
    
    @Test func test_cannotEnterSettingsModeTwice() {
        window.enterSettingsMode()
        #expect(window.isSettingsMode)
        
        window.enterSettingsMode()
        
        #expect(window.isSettingsMode)
    }
    
    @Test func test_cannotExitSettingsModeWhenNotInSettingsMode() {
        #expect(!window.isSettingsMode)
        
        window.exitSettingsMode()
        
        #expect(!window.isSettingsMode)
    }
    
    @Test func test_enterSettingsMode_clearsSearchResults() {
        window.show()
        
        window.enterSettingsMode()
        
        #expect(window.searchResults.isEmpty)
    }
    
    @Test func test_exitSettingsMode_clearsSearchResults() {
        window.enterSettingsMode()
        
        window.exitSettingsMode()
        
        #expect(window.searchResults.isEmpty)
    }
    
    @Test func test_close_clearsSearchResults() {
        window.show()
        
        window.close()
        
        #expect(window.searchResults.isEmpty)
    }
    
    @Test func test_enterSettingsMode_hidesSearchField() {
        window.show()
        
        window.enterSettingsMode()
        
        #expect(window.searchField.isHidden)
    }
    
    @Test func test_exitSettingsMode_showsSearchField() {
        window.enterSettingsMode()
        
        window.exitSettingsMode()
        
        #expect(!window.searchField.isHidden)
    }
    
    @Test func test_escapeInSettingsMode_exitsSettings() {
        window.enterSettingsMode()
        #expect(window.isSettingsMode)
        
        window.handleEscape()
        
        #expect(!window.isSettingsMode)
    }
    
    @Test func test_escapeOutsideSettingsMode_closesWindow() {
        window.show()
        
        window.handleEscape()
        
        #expect(!window.isVisible)
    }
}
