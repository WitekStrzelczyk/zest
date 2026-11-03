import AppKit
import Testing
@testable import ZestApp

final class ZestTests {
    init() {
        ContactsService.isDisabled = true
    }

    deinit {
        ContactsService.isDisabled = false
    }

    @Test func test_calculator_recognizes_simple_addition() {
        let calculator = Calculator.shared

        let result = calculator.evaluate("2+2")

        #expect(result == "4", "2+2 should equal 4")
    }

    @Test func test_calculator_recognizes_multiplication() {
        let calculator = Calculator.shared

        let result = calculator.evaluate("3*3")

        #expect(result == "9", "3*3 should equal 9")
    }

    @Test func test_search_returns_empty_for_empty_query() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "")

        #expect(results.isEmpty, "Empty query should return empty results")
    }
}
