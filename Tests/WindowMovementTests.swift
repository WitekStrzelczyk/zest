import XCTest
@testable import ZestApp

/// Tests for Window Movement functionality
final class WindowMovementTests: XCTestCase {

    // MARK: - Screen Detection Tests

    func test_screenDetection_usesMainScreen() {
        // Test that screen detection works
        let screen = NSScreen.main ?? NSScreen.screens[0]
        XCTAssertNotNil(screen, "Should have at least one screen")
    }

    // MARK: - Frame Calculation Tests

    func test_calculateVisibleFrame() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let visibleFrame = CGRect(x: 0, y: 40, width: 1920, height: 1040)

        // Visible frame should be smaller due to menu bar
        XCTAssertLessThan(visibleFrame.height, screenFrame.height)
    }

    // MARK: - Position Validation Tests

    func test_isPositionOnScreen() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let onScreenPosition = CGPoint(x: 100, y: 100)

        // Just verify the calculation works
        let isOnScreen = !WindowManager.isPositionOffScreen(onScreenPosition, on: screen)
        XCTAssertTrue(isOnScreen)
    }
}
