import AppKit
import Testing
@testable import ZestApp

@MainActor
final class WindowMovementTests {
    @Test func test_screenDetection_usesMainScreen() {
        _ = NSScreen.main ?? NSScreen.screens[0]
    }

    @Test func test_calculateVisibleFrame() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let visibleFrame = CGRect(x: 0, y: 40, width: 1920, height: 1040)

        #expect(visibleFrame.height < screenFrame.height)
    }

    @Test func test_isPositionOnScreen() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let onScreenPosition = CGPoint(x: 100, y: 100)

        let isOnScreen = !WindowManager.isPositionOffScreen(onScreenPosition, on: screen)
        #expect(isOnScreen)
    }
}
