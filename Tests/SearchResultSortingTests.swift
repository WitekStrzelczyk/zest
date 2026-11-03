import AppKit
import Testing
@testable import ZestApp

@MainActor
final class SearchResultSortingTests {
    @Test func test_sorting_higherScoreAppearsFirst() {
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

        #expect(sorted[0].title == "High Score App")
        #expect(sorted[1].title == "Medium Score App")
        #expect(sorted[2].title == "Low Score App")
    }

    @Test func test_sorting_sameScore_usesCategoryOrder() {
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

        #expect(sorted[0].category == .application)
        #expect(sorted[1].category == .action)
        #expect(sorted[2].category == .file)
    }

    @Test func test_merging_fastResultsAndFileResults_sortedByScore() {
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

        for fileResult in fileResults {
            if !fastResults.contains(where: { $0.title == fileResult.title }) {
                fastResults.append(fileResult)
            }
        }

        let sorted = fastResults.sorted { (a, b) -> Bool in
            SearchResult.rankedBefore(a, b)
        }

        #expect(sorted[0].title == "Safari")
        #expect(sorted[1].title == "package.swift")
        #expect(sorted[2].title == "Slack")
        #expect(sorted[3].title == "screenshot.png")
    }

    @Test func test_sorting_toolSourceBoostsAboveHigherScoreStandard() {
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
        #expect(sorted.first?.title == "Tool Lower")
    }
}
