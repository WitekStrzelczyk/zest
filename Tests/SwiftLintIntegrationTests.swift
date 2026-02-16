import XCTest

final class SwiftLintIntegrationTests: XCTestCase {

    // MARK: - SwiftLint Configuration Tests (RED first - QA requirements)

    func test_swiftlint_config_file_exists() {
        // Given - we need a .swiftlint.yml config file
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath

        // When - check for .swiftlint.yml in project root
        let swiftlintPath = (projectDir as NSString).appendingPathComponent(".swiftlint.yml")

        // Then - the config file should exist
        XCTAssertTrue(
            fileManager.fileExists(atPath: swiftlintPath),
            ".swiftlint.yml configuration file should exist in project root"
        )
    }

    func test_swiftlint_config_disables_unused_code_rule() {
        // Given
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let swiftlintPath = (projectDir as NSString).appendingPathComponent(".swiftlint.yml")

        // When - read the config file
        guard let content = fileManager.contents(atPath: swiftlintPath) else {
            XCTFail(".swiftlint.yml file should exist")
            return
        }

        let configString = String(data: content, encoding: .utf8) ?? ""

        // Then - config should handle unused code rules
        XCTAssertTrue(
            configString.contains("unused_code") || configString.contains("unused_declaration"),
            ".swiftlint.yml should configure unused code rules"
        )
    }

    func test_quality_script_uses_swiftlint() {
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

        // Then - script should run swiftlint
        XCTAssertTrue(
            scriptString.contains("swiftlint"),
            "quality.sh should run swiftlint"
        )
    }

    func test_swiftlint_is_available_or_warning_shown() {
        // Given - quality.sh should handle missing SwiftLint gracefully
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let scriptPath = (projectDir as NSString).appendingPathComponent("scripts/quality.sh")

        // When
        guard let content = fileManager.contents(atPath: scriptPath) else {
            XCTFail("quality.sh should exist")
            return
        }

        let scriptString = String(data: content, encoding: .utf8) ?? ""

        // Then - script should check for swiftlint and show warning if not installed
        XCTAssertTrue(
            scriptString.contains("command -v swiftlint") ||
            scriptString.contains("which swiftlint"),
            "quality.sh should check if swiftlint is installed"
        )

        XCTAssertTrue(
            scriptString.contains("brew install swiftlint") ||
            scriptString.contains("warning") ||
            scriptString.contains("Warning"),
            "quality.sh should show warning with installation instructions"
        )
    }

    func test_swiftlint_runs_on_sources_directory() {
        // Given
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let scriptPath = (projectDir as NSString).appendingPathComponent("scripts/quality.sh")

        // When
        guard let content = fileManager.contents(atPath: scriptPath) else {
            XCTFail("quality.sh should exist")
            return
        }

        let scriptString = String(data: content, encoding: .utf8) ?? ""

        // Then - swiftlint should run on Sources directory
        XCTAssertTrue(
            scriptString.contains("swiftlint Sources") ||
            scriptString.contains("swiftlint\\ Sources"),
            "quality.sh should run swiftlint on Sources directory"
        )
    }
}
