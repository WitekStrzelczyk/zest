import XCTest
@testable import ZestApp

/// Note: Contacts access is disabled during tests to avoid XPC connection issues
final class ZestTests: XCTestCase {

    override class func setUp() {
        // Disable contacts access during tests to avoid XPC connection issues
        // in the unit test environment
        ContactsService.isDisabled = true
    }

    override class func tearDown() {
        ContactsService.isDisabled = false
    }

    // MARK: - Calculator Tests (RED - these should FAIL first)

    func test_calculator_recognizes_simple_addition() {
        // Given
        let calculator = Calculator.shared

        // When
        let result = calculator.evaluate("2+2")

        // Then
        XCTAssertEqual(result, "4", "2+2 should equal 4")
    }

    func test_calculator_recognizes_multiplication() {
        // Given
        let calculator = Calculator.shared

        // When
        let result = calculator.evaluate("3*3")

        // Then
        XCTAssertEqual(result, "9", "3*3 should equal 9")
    }

    // MARK: - Search Engine Tests

    func test_search_returns_empty_for_empty_query() {
        // Given
        let engine = SearchEngine.shared

        // When
        let results = engine.search(query: "")

        // Then
        XCTAssertTrue(results.isEmpty, "Empty query should return empty results")
    }

    // MARK: - Clipboard Manager Tests

    func test_clipboard_manager_initializes() {
        // Given/When
        let manager = ClipboardManager.shared

        // Then - just verify it can be created
        XCTAssertNotNil(manager, "ClipboardManager should initialize")
    }
}
