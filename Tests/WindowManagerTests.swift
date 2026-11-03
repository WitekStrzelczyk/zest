import AppKit
import Testing
@testable import ZestApp

@MainActor
final class WindowManagerTests {
    var windowManager: WindowManager!

    init() {
        windowManager = WindowManager.shared
    }

    isolated deinit {
        windowManager = nil
    }

    @Test func test_tileLeft_calculatesCorrectFrameForLeftHalf() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let leftFrame = WindowManager.calculateTileFrame(for: .leftHalf, on: screenFrame)

        #expect(leftFrame.origin.x == 0, "Left tile should start at x=0")
        #expect(leftFrame.origin.y == 0, "Left tile should start at y=0")
        #expect(leftFrame.width == 960, "Left tile should be half the screen width")
        #expect(leftFrame.height == 1080, "Left tile should be full screen height")
    }

    @Test func test_tileRight_calculatesCorrectFrameForRightHalf() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let rightFrame = WindowManager.calculateTileFrame(for: .rightHalf, on: screenFrame)

        #expect(rightFrame.origin.x == 960, "Right tile should start at x=screenWidth/2")
        #expect(rightFrame.origin.y == 0, "Right tile should start at y=0")
        #expect(rightFrame.width == 960, "Right tile should be half the screen width")
        #expect(rightFrame.height == 1080, "Right tile should be full screen height")
    }

    @Test func test_maximize_calculatesCorrectFrameForFullScreen() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let maximizedFrame = WindowManager.calculateTileFrame(for: .maximize, on: screenFrame)

        #expect(maximizedFrame == screenFrame, "Maximized window should fill the screen")
    }

    @Test func test_tileOptions_includesLeftRightAndMaximize() {
        let options = WindowManager.TilingOption.allCases
        #expect(options.count == 3, "Should have 3 tiling options")
        #expect(options.contains(.leftHalf), "Should include leftHalf")
        #expect(options.contains(.rightHalf), "Should include rightHalf")
        #expect(options.contains(.maximize), "Should include maximize")
    }
}

@MainActor
final class WindowFrameCalculationTests {
    @Test func test_leftHalfFrame_calculation() {
        let testCases: [(screen: CGRect, expectedLeft: CGRect)] = [
            (
                screen: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                expectedLeft: CGRect(x: 0, y: 0, width: 960, height: 1080)
            ),
            (
                screen: CGRect(x: 0, y: 0, width: 1440, height: 900),
                expectedLeft: CGRect(x: 0, y: 0, width: 720, height: 900)
            ),
            (
                screen: CGRect(x: 0, y: 0, width: 2560, height: 1440),
                expectedLeft: CGRect(x: 0, y: 0, width: 1280, height: 1440)
            )
        ]

        for testCase in testCases {
            let result = WindowManager.calculateTileFrame(for: .leftHalf, on: testCase.screen)
            #expect(result == testCase.expectedLeft, "Left half calculation failed for screen \(testCase.screen)")
        }
    }

    @Test func test_rightHalfFrame_calculation() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let expected = CGRect(x: 960, y: 0, width: 960, height: 1080)

        let result = WindowManager.calculateTileFrame(for: .rightHalf, on: screen)
        #expect(result == expected)
    }

    @Test func test_maximizeFrame_calculation() {
        let screen = CGRect(x: 100, y: 200, width: 1920, height: 1080)

        let result = WindowManager.calculateTileFrame(for: .maximize, on: screen)
        #expect(result == screen)
    }
}
