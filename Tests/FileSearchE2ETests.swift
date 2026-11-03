import AppKit
import Testing
@testable import ZestApp

final class FileSearchE2ETests {
    init() {
        ContactsService.isDisabled = true
    }

    deinit {
        ContactsService.isDisabled = false
    }

    @Test func test_fileSearch_findsPackageSwift_returnsMoreThanZeroResults() {
        let service = FileSearchService.shared
        let query = "Package.swift"

        let results = service.searchSync(query: query, maxResults: 10)

        #expect(results.count > 0, "Searching for 'Package.swift' should return at least 1 result. This file exists in the Zest project and should be indexed by Spotlight.")
    }

    @Test func test_fileSearch_resultsHaveValidMetadata() throws {
        let service = FileSearchService.shared
        let query = "Package.swift"

        let results = service.searchSync(query: query, maxResults: 5)

        guard !results.isEmpty else {
            try Test.cancel("No results returned - Package.swift may not be indexed by Spotlight yet")
        }

        for result in results {
            #expect(!result.title.isEmpty, "File search result should have a non-empty title (filename)")

            #expect(result.subtitle == "File", "File search results should have 'File' as subtitle")

            #expect(result.icon != nil, "File search result should have an icon")
        }
    }

    @Test func test_searchEngine_includesFileResults_forFilePrefixQuery() {
        let engine = SearchEngine.shared
        let query = "file:Package.swift"

        let results = engine.search(query: query)

        let fileResults = results.filter { $0.subtitle == "File" }

        #expect(fileResults.count > 0, "SearchEngine with 'file:Package.swift' query should return file results")
    }

    @Test func test_searchEngine_includesFileResults_inGeneralSearch() {
        let engine = SearchEngine.shared
        let query = "Package.swift"

        let results = engine.search(query: query)

        let fileResults = results.filter { $0.subtitle == "File" }

        #expect(fileResults.count > 0, "General search for 'Package.swift' should return file results. Got \(results.count) total results: \(results.map { "\($0.title) (\($0.subtitle))" })")
    }

    @Test func test_fileSearch_filtersHiddenDirectories() {
        let service = FileSearchService.shared

        #expect(service.isPathInHiddenDirectory("/Users/test/.ssh/config"), ".ssh directory should be filtered")
        #expect(service.isPathInHiddenDirectory("/Users/test/project/.git/HEAD"), ".git directory should be filtered")
        #expect(service.isPathInHiddenDirectory("/Users/test/project/node_modules/package"), "node_modules should be filtered")

        #expect(!service.isPathInHiddenDirectory("/Users/test/Documents/file.txt"), "Normal Documents path should NOT be filtered")
        #expect(!service.isPathInHiddenDirectory("/Users/test/projects/zest/quickstart.mdx"), "Normal project path should NOT be filtered")
    }
}
