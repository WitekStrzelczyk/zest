import AppKit
import XCTest
@testable import ZestApp

/// Tests for MenuBarManager - Story 18: Menu Bar Presence
final class MenuBarManagerTests: XCTestCase {

    var menuBarManager: MenuBarManager!

    override func setUp() {
        super.setUp()
        menuBarManager = MenuBarManager()
    }

    override func tearDown() {
        menuBarManager.removeStatusItem()
        menuBarManager = nil
        super.tearDown()
    }

    // MARK: - Status Item Tests

    func test_setupStatusItem_createsVisibleStatusItem() {
        // Given - a new MenuBarManager

        // When - setting up status item
        menuBarManager.setupStatusItem()

        // Then - status item should exist
        XCTAssertNotNil(menuBarManager.statusItem, "Status item should be created")

        // And - button should have an image
        XCTAssertNotNil(menuBarManager.statusItem?.button?.image, "Status item button should have an image")
    }

    func test_statusItem_usesTemplateImage() {
        // Given - a MenuBarManager with status item set up
        menuBarManager.setupStatusItem()

        // Then - image should be a template for dark/light mode adaptation
        XCTAssertTrue(menuBarManager.statusItem?.button?.image?.isTemplate ?? false,
                      "Status bar image should be template for dark/light mode adaptation")
    }

    func test_removeStatusItem_removesItemFromStatusBar() {
        // Given - a MenuBarManager with status item
        menuBarManager.setupStatusItem()
        XCTAssertNotNil(menuBarManager.statusItem)

        // When - removing status item
        menuBarManager.removeStatusItem()

        // Then - status item should be nil
        XCTAssertNil(menuBarManager.statusItem, "Status item should be removed")
    }

    // MARK: - Menu Items Tests

    func test_menu_containsOpenMenuItem() {
        // Given - a MenuBarManager with status item
        menuBarManager.setupStatusItem()

        // When - getting the menu
        let menu = menuBarManager.statusItem?.menu

        // Then - menu should exist and contain "Open" item
        XCTAssertNotNil(menu, "Menu should exist")
        let hasOpenItem = menu?.items.contains { $0.title.contains("Open") } ?? false
        XCTAssertTrue(hasOpenItem, "Menu should contain an 'Open' menu item")
    }

    func test_openMenuItem_hasOShortcut() {
        // Given - a MenuBarManager with status item
        menuBarManager.setupStatusItem()

        // When - finding the open menu item
        let menu = menuBarManager.statusItem?.menu
        let openItem = menu?.items.first { $0.title.contains("Open") }

        // Then - should have Cmd+O shortcut
        XCTAssertEqual(openItem?.keyEquivalent, "o", "Open should have Cmd+O shortcut")
    }

    func test_menu_containsPreferencesMenuItem() {
        // Given - a MenuBarManager with status item
        menuBarManager.setupStatusItem()

        // When - getting the menu
        let menu = menuBarManager.statusItem?.menu

        // Then - menu should contain "Preferences" item
        let hasPreferencesItem = menu?.items.contains { $0.title.contains("Preferences") } ?? false
        XCTAssertTrue(hasPreferencesItem, "Menu should contain a 'Preferences' menu item")
    }

    func test_menu_containsQuitMenuItem() {
        // Given - a MenuBarManager with status item
        menuBarManager.setupStatusItem()

        // When - getting the menu
        let menu = menuBarManager.statusItem?.menu

        // Then - menu should contain "Quit" item
        let hasQuitItem = menu?.items.contains { $0.title.contains("Quit") } ?? false
        XCTAssertTrue(hasQuitItem, "Menu should contain a 'Quit' menu item")
    }

    func test_preferencesMenuItem_hasCommaShortcut() {
        // Given - a MenuBarManager with status item
        menuBarManager.setupStatusItem()

        // When - finding the preferences menu item
        let menu = menuBarManager.statusItem?.menu
        let preferencesItem = menu?.items.first { $0.title.contains("Preferences") }

        // Then - should have Cmd+, shortcut
        XCTAssertEqual(preferencesItem?.keyEquivalent, ",", "Preferences should have Cmd+, shortcut")
    }

    func test_quitMenuItem_hasQShortcut() {
        // Given - a MenuBarManager with status item
        menuBarManager.setupStatusItem()

        // When - finding the quit menu item
        let menu = menuBarManager.statusItem?.menu
        let quitItem = menu?.items.first { $0.title.contains("Quit") }

        // Then - should have Cmd+Q shortcut
        XCTAssertEqual(quitItem?.keyEquivalent, "q", "Quit should have Cmd+Q shortcut")
    }

    // MARK: - Callback Tests

    func test_onMenuBarClick_isCalledWhenClicked() {
        // Given - a MenuBarManager with callback set up
        menuBarManager.setupStatusItem()

        // When - verifying button has proper action/target set
        let button = menuBarManager.statusItem?.button
        XCTAssertNotNil(button?.target, "Button should have a target")
        XCTAssertNotNil(button?.action, "Button should have an action")
    }

    func test_onPreferencesSelected_isCallable() {
        // Given - a MenuBarManager with callback
        menuBarManager.setupStatusItem()

        var preferencesCalled = false
        menuBarManager.onPreferencesSelected = {
            preferencesCalled = true
        }

        // When - triggering preferences callback directly
        menuBarManager.onPreferencesSelected?()

        // Then - callback should have been called
        XCTAssertTrue(preferencesCalled, "Preferences callback should be called")
    }

    func test_onQuitSelected_isCallable() {
        // Given - a MenuBarManager with callback
        menuBarManager.setupStatusItem()

        var quitCalled = false
        menuBarManager.onQuitSelected = {
            quitCalled = true
        }

        // When - triggering quit callback directly
        menuBarManager.onQuitSelected?()

        // Then - callback should have been called
        XCTAssertTrue(quitCalled, "Quit callback should be called")
    }

    func test_onOpenSelected_isCallable() {
        // Given - a MenuBarManager with callback
        menuBarManager.setupStatusItem()

        var openCalled = false
        menuBarManager.onOpenSelected = {
            openCalled = true
        }

        // When - triggering open callback directly
        menuBarManager.onOpenSelected?()

        // Then - callback should have been called
        XCTAssertTrue(openCalled, "Open callback should be called")
    }

    // MARK: - Recent Items Tests

    func test_updateRecentItems_updatesRecentItemsSubmenu() {
        // Given - a MenuBarManager with status item
        menuBarManager.setupStatusItem()

        // When - updating recent items
        let recentItems = ["Chrome", "Safari", "Finder"]
        menuBarManager.updateRecentItems(recentItems)

        // Then - recent items submenu should contain the items
        let menu = menuBarManager.statusItem?.menu
        let recentMenuItem = menu?.items.first { $0.title == "Recent Items" }
        let submenu = recentMenuItem?.submenu

        XCTAssertEqual(submenu?.items.count, 3, "Recent items submenu should have 3 items")
        XCTAssertEqual(submenu?.items.first?.title, "Chrome", "First recent item should be Chrome")
    }

    func test_updateRecentItems_emptyShowsNoRecentItems() {
        // Given - a MenuBarManager with status item
        menuBarManager.setupStatusItem()

        // When - updating with empty array
        menuBarManager.updateRecentItems([])

        // Then - should show "No recent items"
        let menu = menuBarManager.statusItem?.menu
        let recentMenuItem = menu?.items.first { $0.title == "Recent Items" }
        let submenu = recentMenuItem?.submenu

        XCTAssertEqual(submenu?.items.count, 1, "Empty recent items should show placeholder")
        XCTAssertEqual(submenu?.items.first?.title, "No recent items", "Should show 'No recent items' placeholder")
        XCTAssertFalse(submenu?.items.first?.isEnabled ?? true, "Placeholder should be disabled")
    }
}
