import XCTest
@testable import ZestApp

/// Tests for Clipboard Manager functionality
final class ClipboardManagerTests: XCTestCase {

    func testClipboardManagerCreation() {
        let manager = ClipboardManager.shared
        XCTAssertNotNil(manager)
    }

    func testClipboardManagerSingleton() {
        let manager1 = ClipboardManager.shared
        let manager2 = ClipboardManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testEmptySearchQuery() {
        let manager = ClipboardManager.shared
        let results = manager.search(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testClipboardSearchByText() {
        let manager = ClipboardManager.shared
        let results = manager.search(query: "test")
        XCTAssertNotNil(results)
    }
}
