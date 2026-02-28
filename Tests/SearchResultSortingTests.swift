import XCTest
@testable import ZestApp

/// Tests for search result sorting behavior
/// Verifies that when results are merged, they are sorted by score (descending), then by category
final class SearchResultSortingTests: XCTestCase {

    /// Tests that results with higher scores appear before lower scores
    func test_sorting_higherScoreAppearsFirst() {
        let results: [SearchResult] = [
            SearchResult(
                title: "Low Score App",
                subtitle: "Application",
                icon: nil,
                category: .application,
                action: {},
                score: 10
            ),
            SearchResult(
                title: "High Score App",
                subtitle: "Application",
                icon: nil,
                category: .application,
                action: {},
                score: 100
            ),
            SearchResult(
                title: "Medium Score App",
                subtitle: "Application",
                icon: nil,
                category: .application,
                action: {},
                score: 50
            )
        ]

        let sorted = results.sorted { (a, b) -> Bool in
            SearchResult.rankedBefore(a, b)
        }

        XCTAssertEqual(sorted[0].title, "High Score App")
        XCTAssertEqual(sorted[1].title, "Medium Score App")
        XCTAssertEqual(sorted[2].title, "Low Score App")
    }

    /// Tests that when scores are equal, category determines order
    func test_sorting_sameScore_usesCategoryOrder() {
        let results: [SearchResult] = [
            SearchResult(
                title: "Action Result",
                subtitle: "Action",
                icon: nil,
                category: .action,
                action: {},
                score: 50
            ),
            SearchResult(
                title: "Application Result",
                subtitle: "Application",
                icon: nil,
                category: .application,
                action: {},
                score: 50
            ),
            SearchResult(
                title: "File Result",
                subtitle: "File",
                icon: nil,
                category: .file,
                action: {},
                score: 50
            )
        ]

        let sorted = results.sorted { (a, b) -> Bool in
            SearchResult.rankedBefore(a, b)
        }

        // Category order: application < action < file
        XCTAssertEqual(sorted[0].category, .application)
        XCTAssertEqual(sorted[1].category, .action)
        XCTAssertEqual(sorted[2].category, .file)
    }

    /// Tests merging fast results with file results and sorting by score
    func test_merging_fastResultsAndFileResults_sortedByScore() {
        // Simulate fast results (apps) - already have scores
        var fastResults: [SearchResult] = [
            SearchResult(
                title: "Slack",
                subtitle: "Application",
                icon: nil,
                category: .application,
                action: {},
                score: 80
            ),
            SearchResult(
                title: "Safari",
                subtitle: "Application",
                icon: nil,
                category: .application,
                action: {},
                score: 95
            )
        ]

        // Simulate file results from Spotlight
        let fileResults: [SearchResult] = [
            SearchResult(
                title: "screenshot.png",
                subtitle: "File",
                icon: nil,
                category: .file,
                action: {},
                score: 60
            ),
            SearchResult(
                title: "package.swift",
                subtitle: "File",
                icon: nil,
                category: .file,
                action: {},
                score: 90
            )
        ]

        // Merge results (simulating what happens in CommandPaletteWindow)
        for fileResult in fileResults {
            if !fastResults.contains(where: { $0.title == fileResult.title }) {
                fastResults.append(fileResult)
            }
        }

        // Sort by score descending, then by category
        let sorted = fastResults.sorted { (a, b) -> Bool in
            SearchResult.rankedBefore(a, b)
        }

        // Expected order: Safari(95) > package.swift(90) > Slack(80) > screenshot.png(60)
        XCTAssertEqual(sorted[0].title, "Safari")
        XCTAssertEqual(sorted[1].title, "package.swift")
        XCTAssertEqual(sorted[2].title, "Slack")
        XCTAssertEqual(sorted[3].title, "screenshot.png")
    }

    func test_sorting_toolSourceBoostsAboveHigherScoreStandard() {
        let standardHigh = SearchResult(
            title: "Standard High",
            subtitle: "Application",
            icon: nil,
            category: .application,
            action: {},
            score: 500,
            source: .standard
        )
        let toolLower = SearchResult(
            title: "Tool Lower",
            subtitle: "Action",
            icon: nil,
            category: .action,
            action: {},
            score: 50,
            source: .tool
        )

        let sorted = [standardHigh, toolLower].sorted(by: SearchResult.rankedBefore)
        XCTAssertEqual(sorted.first?.title, "Tool Lower")
    }
}
