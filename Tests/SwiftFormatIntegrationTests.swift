import AppKit
import Testing

@MainActor
final class SwiftFormatIntegrationTests {
    @Test func test_swiftformat_config_file_exists() {
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath

        let swiftformatPath = (projectDir as NSString).appendingPathComponent(".swiftformat")

        #expect(fileManager.fileExists(atPath: swiftformatPath), ".swiftformat configuration file should exist in project root")
    }

    @Test func test_swiftformat_config_contains_indentation_rule() {
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let swiftformatPath = (projectDir as NSString).appendingPathComponent(".swiftformat")

        guard let content = fileManager.contents(atPath: swiftformatPath) else {
            Issue.record(".swiftformat file should exist")
            return
        }

        let configString = String(data: content, encoding: .utf8) ?? ""

        #expect(configString.contains("--indent") || configString.contains("indent"), ".swiftformat should specify indentation rule")
    }

    @Test func test_quality_script_uses_swiftformat_config() {
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let scriptPath = (projectDir as NSString).appendingPathComponent("scripts/quality.sh")

        guard let content = fileManager.contents(atPath: scriptPath) else {
            Issue.record("quality.sh should exist")
            return
        }

        let scriptString = String(data: content, encoding: .utf8) ?? ""

        let usesConfigFlag = scriptString.contains("--config")
        let reliesOnConfigFile = !scriptString.contains("swiftformat Sources") ||
            (scriptString.contains("swiftformat Sources") &&
             !scriptString.contains("--indent"))

        #expect(usesConfigFlag || reliesOnConfigFile, "quality.sh should use .swiftformat config file")
    }

    @Test func test_swiftformat_is_available_or_warning_shown() {
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let scriptPath = (projectDir as NSString).appendingPathComponent("scripts/quality.sh")

        guard let content = fileManager.contents(atPath: scriptPath) else {
            Issue.record("quality.sh should exist")
            return
        }

        let scriptString = String(data: content, encoding: .utf8) ?? ""

        #expect(scriptString.contains("command -v swiftformat") ||
            scriptString.contains("which swiftformat"), "quality.sh should check if swiftformat is installed")

        #expect(scriptString.contains("brew install swiftformat") ||
            scriptString.contains("warning") ||
            scriptString.contains("Warning"), "quality.sh should show warning with installation instructions")
    }
}
