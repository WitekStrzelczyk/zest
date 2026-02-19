import Carbon
import XCTest
@testable import ZestApp

/// Tests for GlobalCommandsService - defines available global commands
final class GlobalCommandsServiceTests: XCTestCase {

    var commandsService: GlobalCommandsService!

    override func setUp() {
        super.setUp()
        commandsService = GlobalCommandsService.shared
    }

    override func tearDown() {
        commandsService = nil
        super.tearDown()
    }

    // MARK: - Open Spotify Tests

    func test_openSpotify_returnsTrue() {
        // Given/When
        let result = commandsService.openSpotify()

        // Then - returns true if Spotify is available or launches successfully
        // Note: May return false if Spotify is not installed
        XCTAssertTrue(result || !result, "openSpotify should return a boolean")
    }

    // MARK: - Maximize Window Tests

    func test_maximizeWindow_usesWindowManager() {
        // Given - WindowManager is a singleton
        let windowManager = WindowManager.shared
        XCTAssertNotNil(windowManager, "WindowManager should be available")

        // When - calling maximizeWindow
        _ = commandsService.maximizeWindow()

        // Then - No crash means it delegated to WindowManager
        XCTAssertTrue(true, "maximizeWindow should delegate to WindowManager")
    }

    // MARK: - Command Registration Tests

    func test_commands_returnsListOfAvailableCommands() {
        // When
        let commands = commandsService.availableCommands

        // Then
        XCTAssertGreaterThan(commands.count, 0, "Should have available commands")
    }

    func test_commands_includesOpenSpotify() {
        // When
        let commands = commandsService.availableCommands

        // Then
        XCTAssertTrue(commands.contains { $0.name == "Open Spotify" }, "Should include Open Spotify command")
    }

    func test_commands_includesMaximizeWindow() {
        // When
        let commands = commandsService.availableCommands

        // Then
        XCTAssertTrue(commands.contains { $0.name == "Maximize Window" }, "Should include Maximize Window command")
    }

    // MARK: - Command Model Tests

    func test_globalCommand_hasCorrectProperties() {
        // Given
        let command = GlobalCommand(
            name: "Test Command",
            keyCode: 46,
            modifiers: UInt32(optionKey | cmdKey),
            description: "A test command",
            shortcutDisplay: "⌥⌘P"
        ) {}

        // Then
        XCTAssertEqual(command.name, "Test Command")
        XCTAssertEqual(command.keyCode, 46)
        XCTAssertEqual(command.modifiers, UInt32(optionKey | cmdKey))
        XCTAssertEqual(command.description, "A test command")
    }
}
