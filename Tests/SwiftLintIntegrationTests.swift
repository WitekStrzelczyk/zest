import AppKit
import Testing

@MainActor
final class SwiftLintIntegrationTests {
    @Test func test_swiftlint_config_file_exists() {
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath

        let swiftlintPath = (projectDir as NSString).appendingPathComponent(".swiftlint.yml")

        #expect(fileManager.fileExists(atPath: swiftlintPath), ".swiftlint.yml configuration file should exist in project root")
    }

    @Test func test_swiftlint_config_disables_unused_code_rule() {
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let swiftlintPath = (projectDir as NSString).appendingPathComponent(".swiftlint.yml")

        guard let content = fileManager.contents(atPath: swiftlintPath) else {
            Issue.record(".swiftlint.yml file should exist")
            return
        }

        let configString = String(data: content, encoding: .utf8) ?? ""

        #expect(configString.contains("unused_code") || configString.contains("unused_declaration"), ".swiftlint.yml should configure unused code rules")
    }

    @Test func test_quality_script_uses_swiftlint() {
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let scriptPath = (projectDir as NSString).appendingPathComponent("scripts/quality.sh")

        guard let content = fileManager.contents(atPath: scriptPath) else {
            Issue.record("quality.sh should exist")
            return
        }

        let scriptString = String(data: content, encoding: .utf8) ?? ""

        #expect(scriptString.contains("swiftlint"), "quality.sh should run swiftlint")
    }

    @Test func test_swiftlint_is_available_or_warning_shown() {
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let scriptPath = (projectDir as NSString).appendingPathComponent("scripts/quality.sh")

        guard let content = fileManager.contents(atPath: scriptPath) else {
            Issue.record("quality.sh should exist")
            return
        }

        let scriptString = String(data: content, encoding: .utf8) ?? ""

        #expect(scriptString.contains("command -v swiftlint") ||
            scriptString.contains("which swiftlint"), "quality.sh should check if swiftlint is installed")

        #expect(scriptString.contains("brew install swiftlint") ||
            scriptString.contains("warning") ||
            scriptString.contains("Warning"), "quality.sh should show warning with installation instructions")
    }

    @Test func test_swiftlint_runs_on_sources_directory() {
        let fileManager = FileManager.default
        let projectDir = fileManager.currentDirectoryPath
        let scriptPath = (projectDir as NSString).appendingPathComponent("scripts/quality.sh")

        guard let content = fileManager.contents(atPath: scriptPath) else {
            Issue.record("quality.sh should exist")
            return
        }

        let scriptString = String(data: content, encoding: .utf8) ?? ""

        #expect(scriptString.contains("swiftlint --strict Sources"), "quality.sh should run swiftlint on Sources directory")
    }
}
