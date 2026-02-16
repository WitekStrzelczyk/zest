import XCTest

final class SwiftFormatIntegrationTests: XCTestCase {

    // MARK: - SwiftFormat Configuration Tests

    func test_swiftformat_config_file_exists() {
        // Given - we need a .swiftformat config file
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath

        // When - check for .swiftformat in project root
        let swiftformatPath = (projectDir as NSString).appendingPathComponent(".swiftformat")

        // Then - the config file should exist
        XCTAssertTrue(
            fileManager.fileExists(atPath: swiftformatPath),
            ".swiftformat configuration file should exist in project root"
        )
    }

    func test_swiftformat_config_contains_indentation_rule() {
        // Given
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let swiftformatPath = (projectDir as NSString).appendingPathComponent(".swiftformat")

        // When - read the config file
        guard let content = fileManager.contents(atPath: swiftformatPath) else {
            XCTFail(".swiftformat file should exist")
            return
        }

        let configString = String(data: content, encoding: .utf8) ?? ""

        // Then - config should contain indentation settings
        XCTAssertTrue(
            configString.contains("--indent") || configString.contains("indent"),
            ".swiftformat should specify indentation rule"
        )
    }

    func test_quality_script_uses_swiftformat_config() {
        // Given
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let scriptPath = (projectDir as NSString).appendingPathComponent("scripts/quality.sh")

        // When - read the quality.sh script
        guard let content = fileManager.contents(atPath: scriptPath) else {
            XCTFail("quality.sh should exist")
            return
        }

        let scriptString = String(data: content, encoding: .utf8) ?? ""

        // Then - script should reference .swiftformat config (or use swiftformat with config flag)
        // The script should either:
        // 1. Use --config flag, OR
        // 2. Run swiftformat without inline options (relying on .swiftformat)
        let usesConfigFlag = scriptString.contains("--config")
        let reliesOnConfigFile = !scriptString.contains("swiftformat Sources") ||
            (scriptString.contains("swiftformat Sources") &&
             !scriptString.contains("--indent"))

        XCTAssertTrue(
            usesConfigFlag || reliesOnConfigFile,
            "quality.sh should use .swiftformat config file"
        )
    }

    func test_swiftformat_is_available_or_warning_shown() {
        // Given - quality.sh should handle missing SwiftFormat gracefully
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let scriptPath = (projectDir as NSString).appendingPathComponent("scripts/quality.sh")

        // When
        guard let content = fileManager.contents(atPath: scriptPath) else {
            XCTFail("quality.sh should exist")
            return
        }

        let scriptString = String(data: content, encoding: .utf8) ?? ""

        // Then - script should check for swiftformat and show warning if not installed
        XCTAssertTrue(
            scriptString.contains("command -v swiftformat") ||
            scriptString.contains("which swiftformat"),
            "quality.sh should check if swiftformat is installed"
        )

        XCTAssertTrue(
            scriptString.contains("brew install swiftformat") ||
            scriptString.contains("warning") ||
            scriptString.contains("Warning"),
            "quality.sh should show warning with installation instructions"
        )
    }
}
