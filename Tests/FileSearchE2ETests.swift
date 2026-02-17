import XCTest
@testable import ZestApp

/// E2E tests for file search functionality
/// These tests verify the full search stack works correctly including:
/// - Spotlight/mdfind integration
/// - Result parsing
/// - Privacy filtering
///
/// IMPORTANT: These tests use real system resources and may take longer.
/// The test runner script enforces a timeout to detect hanging issues.
/// Run with: ./scripts/run_tests.sh 20 --filter FileSearchE2ETests
final class FileSearchE2ETests: XCTestCase {

    // MARK: - File Search E2E Tests

    /// Tests that searching for a common file type returns results
    /// This test exercises the full mdfind -> FileSearchService -> SearchResult pipeline
    func test_fileSearch_findsQuickstartMdx_returnsMoreThanZeroResults() {
        let service = FileSearchService.shared
        let query = "quickstart.mdx"

        let results = service.searchSync(query: query, maxResults: 10)

        // Verify we get results - this proves the search pipeline works
        XCTAssertGreaterThan(
            results.count,
            0,
            "Searching for 'quickstart.mdx' should return at least 1 result. " +
                "If this fails, check: 1) Spotlight has indexed the file, " +
                "2) mdfind command works in terminal, 3) File exists on system"
        )
    }

    /// Tests that results have proper metadata populated
    func test_fileSearch_resultsHaveValidMetadata() throws {
        let service = FileSearchService.shared
        let query = "quickstart.mdx"

        let results = service.searchSync(query: query, maxResults: 5)

        // Skip if no results (file may not exist on this system)
        guard !results.isEmpty else {
            throw XCTSkip("No results returned - quickstart.mdx may not exist on this system")
        }

        for result in results {
            // Every result should have a non-empty title (filename)
            XCTAssertFalse(
                result.title.isEmpty,
                "File search result should have a non-empty title (filename)"
            )

            // Every result should have subtitle "File"
            XCTAssertEqual(
                result.subtitle,
                "File",
                "File search results should have 'File' as subtitle"
            )

            // Every result should have an icon
            XCTAssertNotNil(
                result.icon,
                "File search result should have an icon"
            )
        }
    }

    /// Tests that SearchEngine integrates file search results correctly
    func test_searchEngine_includesFileResults_forFilePrefixQuery() {
        let engine = SearchEngine.shared
        let query = "file:quickstart.mdx"

        let results = engine.search(query: query)

        // With "file:" prefix, we should get file results
        let fileResults = results.filter { $0.subtitle == "File" }

        XCTAssertGreaterThan(
            fileResults.count,
            0,
            "SearchEngine with 'file:quickstart.mdx' query should return file results"
        )
    }

    /// Tests that SearchEngine includes file results in general search
    func test_searchEngine_includesFileResults_inGeneralSearch() {
        let engine = SearchEngine.shared
        let query = "quickstart.mdx"

        let results = engine.search(query: query)

        // General search should also include file results
        let fileResults = results.filter { $0.subtitle == "File" }

        // Note: This test may be flaky if Spotlight hasn't indexed the file
        // or if other results (apps, clipboard) take precedence
        XCTAssertGreaterThan(
            fileResults.count,
            0,
            "General search for 'quickstart.mdx' should return file results. " +
                "Got \(results.count) total results: \(results.map { "\($0.title) (\($0.subtitle))" })"
        )
    }

    // MARK: - Privacy Filter Tests

    /// Tests that hidden directories are properly filtered
    func test_fileSearch_filtersHiddenDirectories() {
        let service = FileSearchService.shared

        // These paths should be identified as hidden
        XCTAssertTrue(
            service.isPathInHiddenDirectory("/Users/test/.ssh/config"),
            ".ssh directory should be filtered"
        )
        XCTAssertTrue(
            service.isPathInHiddenDirectory("/Users/test/project/.git/HEAD"),
            ".git directory should be filtered"
        )
        XCTAssertTrue(
            service.isPathInHiddenDirectory("/Users/test/project/node_modules/package"),
            "node_modules should be filtered"
        )

        // These paths should NOT be filtered
        XCTAssertFalse(
            service.isPathInHiddenDirectory("/Users/test/Documents/file.txt"),
            "Normal Documents path should NOT be filtered"
        )
        XCTAssertFalse(
            service.isPathInHiddenDirectory("/Users/test/projects/zest/quickstart.mdx"),
            "Normal project path should NOT be filtered"
        )
    }
}
