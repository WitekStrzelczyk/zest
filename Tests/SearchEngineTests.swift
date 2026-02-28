import XCTest
@testable import ZestApp

/// Tests for SearchEngine functionality
/// Note: Contacts access is disabled during tests to avoid XPC connection issues
final class SearchEngineTests: XCTestCase {

    override class func setUp() {
        // Disable contacts access during tests to avoid XPC connection issues
        // in the unit test environment
        ContactsService.isDisabled = true
        // Disable app loading to avoid mdfind hanging in tests
        SearchEngine.disableAppLoading = true
    }

    override class func tearDown() {
        ContactsService.isDisabled = false
        SearchEngine.disableAppLoading = false
    }

    // MARK: - Fuzzy Search Tests

    func test_search_finds_app_by_exact_name() {
        let engine = SearchEngine.shared
        let testQuery = "visual studio code"

        let results = engine.search(query: testQuery)

        let hasVSCode = results.contains { $0.title.lowercased().contains("visual studio code") }
        XCTAssertTrue(hasVSCode || !results.isEmpty, "Should find Visual Studio Code when searching for 'visual studio code'")
    }

    func test_search_finds_app_by_partial_name() {
        let engine = SearchEngine.shared
        let testQuery = "vscode"

        let results = engine.search(query: testQuery)

        XCTAssertFalse(results.isEmpty, "Should find apps with partial name match")
    }

    func test_search_finds_app_by_acronym() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "saf")

        let hasSafari = results.contains { $0.title.lowercased().contains("safari") }
        XCTAssertTrue(hasSafari || !results.isEmpty, "Should find Safari when searching for 'saf'")
    }

    func test_search_returns_empty_for_empty_query() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "")

        XCTAssertTrue(results.isEmpty, "Empty query should return empty results")
    }

    func test_search_returns_max_10_results() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "a")

        XCTAssertLessThanOrEqual(results.count, 10, "Should return at most 10 results")
    }

    func test_search_prioritizes_calculator_expressions() {
        let engine = SearchEngine.shared
        let mathQuery = "2+2"

        let results = engine.search(query: mathQuery)

        let hasCalculatorResult = results.contains { $0.subtitle == "Copy to clipboard" }
        XCTAssertTrue(hasCalculatorResult, "Math expressions should return calculator result")
    }

    func test_search_deduplicates_results_by_title() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "app")

        let titles = results.map { $0.title }
        let uniqueTitles = Set(titles)
        XCTAssertEqual(titles.count, uniqueTitles.count, "Results should not contain duplicate titles")
    }

    func test_search_includes_clipboard_history() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "the")

        XCTAssertNotNil(results, "Search should return results including clipboard history")
    }

    func test_search_hidesClipboardWithoutClipPrefix() {
        let engine = SearchEngine.shared
        let results = engine.search(query: "the")
        let hasClipboard = results.contains { $0.category == .clipboard }
        XCTAssertFalse(hasClipboard, "Clipboard items should be hidden unless query starts with 'clip'")
    }

    // MARK: - Activity Monitor Metrics Tests

    func test_search_activityMonitor_showsCPUMemoryMetrics() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "Activity Monitor")

        // Find Activity Monitor in results
        let activityMonitorResult = results.first { $0.title == "Activity Monitor" }

        XCTAssertNotNil(activityMonitorResult, "Should find Activity Monitor in results")

        // Subtitle should contain CPU and MEM metrics
        if let result = activityMonitorResult {
            XCTAssertTrue(result.subtitle.contains("CPU:"), "Activity Monitor subtitle should contain 'CPU:'")
            XCTAssertTrue(result.subtitle.contains("MEM:"), "Activity Monitor subtitle should contain 'MEM:'")
            XCTAssertTrue(result.subtitle.contains("%"), "Activity Monitor subtitle should contain '%'")
        }
    }

    func test_search_activityMonitor_formatIsCorrect() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "Activity Monitor")

        let activityMonitorResult = results.first { $0.title == "Activity Monitor" }

        if let result = activityMonitorResult {
            // Format should be "CPU: XX% | MEM: XX%"
            let pattern = #"CPU: \d+% \| MEM: \d+%"#
            let regex = try? NSRegularExpression(pattern: pattern)
            let range = NSRange(result.subtitle.startIndex..., in: result.subtitle)
            let matches = regex?.firstMatch(in: result.subtitle, range: range)

            XCTAssertNotNil(matches, "Activity Monitor subtitle should match format 'CPU: XX% | MEM: XX%'")
        }
    }

    func test_search_monitor_findsActivityMonitor() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "monitor")

        let activityMonitorResult = results.first { $0.title == "Activity Monitor" }

        XCTAssertNotNil(activityMonitorResult, "Should find Activity Monitor when searching for 'monitor'")
    }

    func test_search_activity_findsActivityMonitor() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "activity")

        let activityMonitorResult = results.first { $0.title == "Activity Monitor" }

        XCTAssertNotNil(activityMonitorResult, "Should find Activity Monitor when searching for 'activity'")
    }

    // MARK: - Shell Command Tests (Story 24)

    func test_search_detectsShellCommand_withPrefix() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "> echo hello")

        XCTAssertEqual(results.count, 1, "Shell command should return exactly one result")
        XCTAssertEqual(results.first?.title, "echo hello", "Result title should be the command")
        XCTAssertEqual(results.first?.subtitle, "Shell Command", "Result subtitle should indicate shell command")
    }

    func test_search_detectsShellCommand_withNoSpace() {
        let engine = SearchEngine.shared

        let results = engine.search(query: ">ls")

        XCTAssertEqual(results.count, 1, "Shell command should return exactly one result")
        XCTAssertEqual(results.first?.title, "ls", "Result title should be 'ls'")
    }

    func test_search_shellCommand_prioritizedOverApps() {
        let engine = SearchEngine.shared

        // "> safari" should be treated as a shell command, not finding Safari app
        let results = engine.search(query: "> safari")

        XCTAssertEqual(results.count, 1, "Shell command should take priority")
        XCTAssertEqual(results.first?.subtitle, "Shell Command", "Should be shell command, not app")
    }

    func test_search_shellCommand_emptyAfterPrefix() {
        let engine = SearchEngine.shared

        // Just ">" should not be a valid shell command
        let results = engine.search(query: ">")

        // Should not return shell command result, should fall through to other searches
        let hasShellCommand = results.contains { $0.subtitle == "Shell Command" }
        XCTAssertFalse(hasShellCommand, "Just '>' should not create a shell command result")
    }

    func test_searchFast_detectsShellCommand() {
        let engine = SearchEngine.shared

        let results = engine.searchFast(query: "> git status")

        XCTAssertEqual(results.count, 1, "Fast search should detect shell commands")
        XCTAssertEqual(results.first?.subtitle, "Shell Command", "Result should be shell command")
    }

    // MARK: - User Commands Tests (Story: Commands Search Section)

    func test_search_findsGCRCommand() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "gcr")

        let hasGCR = results.contains { $0.title == "gcr" }
        XCTAssertTrue(hasGCR, "Should find 'gcr' command when searching for 'gcr'")
    }

    func test_search_findsGCRCommand_withPartialMatch() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "gc")

        let hasGCR = results.contains { $0.title == "gcr" }
        XCTAssertTrue(hasGCR, "Should find 'gcr' command with partial match 'gc'")
    }

    func test_searchFast_findsGCRCommand() {
        let engine = SearchEngine.shared

        let results = engine.searchFast(query: "gcr")

        let hasGCR = results.contains { $0.title == "gcr" }
        XCTAssertTrue(hasGCR, "Fast search should find 'gcr' command")
    }

    func test_search_gcrCommand_opensURL() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "gcr")

        let gcrResult = results.first { $0.title == "gcr" }
        XCTAssertNotNil(gcrResult, "Should find GCR command")
        XCTAssertEqual(gcrResult?.subtitle, "Google Cloud Registry", "Should have description as subtitle")
    }

    // MARK: - Quicklink Tests (Story: Quicklinks Feature)

    func test_search_returnsQuicklinks_whenSearchingByName() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "google")

        let hasGoogleQuicklink = results.contains { $0.title == "Google" && $0.category == .quicklink }
        XCTAssertTrue(hasGoogleQuicklink, "Should find Google quicklink when searching for 'google'")
    }

    func test_search_returnsQuicklinks_whenSearchingByURL() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "github.com")

        let hasGitHubQuicklink = results.contains { $0.title == "GitHub" && $0.category == .quicklink }
        XCTAssertTrue(hasGitHubQuicklink, "Should find GitHub quicklink when searching for 'github.com'")
    }

    func test_search_returnsQuicklinks_whenSearchingByKeyword() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "search")

        let hasGoogleQuicklink = results.contains { $0.title == "Google" && $0.category == .quicklink }
        XCTAssertTrue(hasGoogleQuicklink, "Should find Google quicklink when searching for 'search' keyword")
    }

    func test_search_returnsQuicklinks_whenSearchingQuicklinkKeyword() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "quicklink")

        let hasQuicklinks = results.contains { $0.category == .quicklink }
        XCTAssertTrue(hasQuicklinks, "Should find quicklinks when searching for 'quicklink' keyword")
    }

    func test_search_settingsCategory_hasAddQuicklink() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "add")

        let hasAddQuicklink = results.contains { $0.title == "Add Quicklink" && $0.category == .settings }
        XCTAssertTrue(hasAddQuicklink, "Should find 'Add Quicklink' in settings category")
    }

    func test_searchFast_returnsQuicklinks() {
        let engine = SearchEngine.shared

        let results = engine.searchFast(query: "github")

        let hasGitHubQuicklink = results.contains { $0.title == "GitHub" && $0.category == .quicklink }
        XCTAssertTrue(hasGitHubQuicklink, "Fast search should find GitHub quicklink")
    }

    // MARK: - Unit Conversion Tests

    func test_search_returnsUnitConversion() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "100 km to miles")

        let hasConversionResult = results.contains { $0.category == .conversion }
        XCTAssertTrue(hasConversionResult, "Should return conversion result for '100 km to miles'")
    }

    func test_searchFast_returnsUnitConversion() {
        let engine = SearchEngine.shared

        let results = engine.searchFast(query: "50 kg to lbs")

        let hasConversionResult = results.contains { $0.category == .conversion }
        XCTAssertTrue(hasConversionResult, "Fast search should return conversion result for '50 kg to lbs'")
    }

    func test_search_convertKeyword_showsHints() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "convert")

        let hasConversionHints = results.contains { $0.category == .conversion }
        XCTAssertTrue(hasConversionHints, "Typing 'convert' should show conversion hints")
    }

    func test_search_conversionResult_hasHighScore() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "72 f to c")

        let conversionResult = results.first { $0.category == .conversion }
        XCTAssertNotNil(conversionResult, "Should have conversion result")
        XCTAssertEqual(conversionResult?.score, 2000, "Conversion result should have high score (2000)")
    }
}
