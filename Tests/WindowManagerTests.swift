import XCTest
@testable import ZestApp

/// Tests for Window Manager functionality
final class WindowManagerTests: XCTestCase {

    var windowManager: WindowManager!

    override func setUp() {
        super.setUp()
        windowManager = WindowManager.shared
    }

    override func tearDown() {
        windowManager = nil
        super.tearDown()
    }

    // MARK: - Tile Left Tests

    func test_tileLeft_calculatesCorrectFrameForLeftHalf() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let leftFrame = WindowManager.calculateTileFrame(for: .leftHalf, on: screenFrame)

        XCTAssertEqual(leftFrame.origin.x, 0, "Left tile should start at x=0")
        XCTAssertEqual(leftFrame.origin.y, 0, "Left tile should start at y=0")
        XCTAssertEqual(leftFrame.width, 960, "Left tile should be half the screen width")
        XCTAssertEqual(leftFrame.height, 1080, "Left tile should be full screen height")
    }

    // MARK: - Tile Right Tests

    func test_tileRight_calculatesCorrectFrameForRightHalf() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let rightFrame = WindowManager.calculateTileFrame(for: .rightHalf, on: screenFrame)

        XCTAssertEqual(rightFrame.origin.x, 960, "Right tile should start at x=screenWidth/2")
        XCTAssertEqual(rightFrame.origin.y, 0, "Right tile should start at y=0")
        XCTAssertEqual(rightFrame.width, 960, "Right tile should be half the screen width")
        XCTAssertEqual(rightFrame.height, 1080, "Right tile should be full screen height")
    }

    // MARK: - Maximize Tests

    func test_maximize_calculatesCorrectFrameForFullScreen() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let maximizedFrame = WindowManager.calculateTileFrame(for: .maximize, on: screenFrame)

        XCTAssertEqual(maximizedFrame, screenFrame, "Maximized window should fill the screen")
    }

    // MARK: - Tiling Options

    func test_tileOptions_includesLeftRightAndMaximize() {
        let options = WindowManager.TilingOption.allCases
        XCTAssertEqual(options.count, 3, "Should have 3 tiling options")
        XCTAssertTrue(options.contains(.leftHalf), "Should include leftHalf")
        XCTAssertTrue(options.contains(.rightHalf), "Should include rightHalf")
        XCTAssertTrue(options.contains(.maximize), "Should include maximize")
    }
}

// MARK: - Frame Calculation Tests

final class WindowFrameCalculationTests: XCTestCase {

    func test_leftHalfFrame_calculation() {
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
            XCTAssertEqual(result, testCase.expectedLeft,
                          "Left half calculation failed for screen \(testCase.screen)")
        }
    }

    func test_rightHalfFrame_calculation() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let expected = CGRect(x: 960, y: 0, width: 960, height: 1080)

        let result = WindowManager.calculateTileFrame(for: .rightHalf, on: screen)
        XCTAssertEqual(result, expected)
    }

    func test_maximizeFrame_calculation() {
        let screen = CGRect(x: 100, y: 200, width: 1920, height: 1080)

        let result = WindowManager.calculateTileFrame(for: .maximize, on: screen)
        XCTAssertEqual(result, screen)
    }
}
