import Carbon
import AppKit
import Testing
@testable import ZestApp

@MainActor
final class GlobalCommandsServiceTests {
    var commandsService: GlobalCommandsService!

    init() {
        commandsService = GlobalCommandsService.shared
    }

    isolated deinit {
        commandsService = nil
    }

    @Test func test_commands_returnsListOfAvailableCommands() {
        let commands = commandsService.availableCommands

        #expect(commands.count > 0, "Should have available commands")
    }

    @Test func test_commands_includesOpenSpotify() {
        let commands = commandsService.availableCommands

        #expect(commands.contains { $0.name == "Open Spotify" }, "Should include Open Spotify command")
    }

    @Test func test_commands_includesMaximizeWindow() {
        let commands = commandsService.availableCommands

        #expect(commands.contains { $0.name == "Maximize Window" }, "Should include Maximize Window command")
    }

    @Test func test_globalCommand_hasCorrectProperties() {
        let command = GlobalCommand(
            name: "Test Command",
            keyCode: 46,
            modifiers: UInt32(optionKey | cmdKey),
            description: "A test command",
            shortcutDisplay: "⌥⌘P"
        ) {}

        #expect(command.name == "Test Command")
        #expect(command.keyCode == 46)
        #expect(command.modifiers == UInt32(optionKey | cmdKey))
        #expect(command.description == "A test command")
    }
}
