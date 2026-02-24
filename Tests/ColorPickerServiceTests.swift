import AppKit
import XCTest
@testable import ZestApp

/// Tests for Color Picker Service functionality
final class ColorPickerServiceTests: XCTestCase {
    var sut: ColorPickerService!

    override func setUp() {
        super.setUp()
        sut = ColorPickerService.shared
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Singleton Tests

    func testColorPickerServiceCreation() {
        XCTAssertNotNil(sut)
    }

    func testColorPickerServiceSingleton() {
        let service1 = ColorPickerService.shared
        let service2 = ColorPickerService.shared
        XCTAssertTrue(service1 === service2)
    }

    // MARK: - HEX Conversion Tests

    func testHEXConversionRed() {
        let color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        XCTAssertEqual(hex, "#FF0000")
    }

    func testHEXConversionGreen() {
        let color = NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        XCTAssertEqual(hex, "#00FF00")
    }

    func testHEXConversionBlue() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        XCTAssertEqual(hex, "#0000FF")
    }

    func testHEXConversionCustom() {
        // #FF6363 = rgb(255, 99, 99)
        let color = NSColor(red: 1.0, green: 99.0 / 255.0, blue: 99.0 / 255.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        XCTAssertEqual(hex, "#FF6363")
    }

    func testHEXConversionBlack() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        XCTAssertEqual(hex, "#000000")
    }

    func testHEXConversionWhite() {
        let color = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        XCTAssertEqual(hex, "#FFFFFF")
    }

    // MARK: - RGB Conversion Tests

    func testRGBConversionRed() {
        let color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        XCTAssertEqual(rgb, "rgb(255, 0, 0)")
    }

    func testRGBConversionGreen() {
        let color = NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        XCTAssertEqual(rgb, "rgb(0, 255, 0)")
    }

    func testRGBConversionBlue() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        XCTAssertEqual(rgb, "rgb(0, 0, 255)")
    }

    func testRGBConversionCustom() {
        // rgb(255, 99, 99)
        let color = NSColor(red: 1.0, green: 99.0 / 255.0, blue: 99.0 / 255.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        XCTAssertEqual(rgb, "rgb(255, 99, 99)")
    }

    func testRGBConversionBlack() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        XCTAssertEqual(rgb, "rgb(0, 0, 0)")
    }

    func testRGBConversionWhite() {
        let color = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        XCTAssertEqual(rgb, "rgb(255, 255, 255)")
    }

    // MARK: - HSL Conversion Tests

    func testHSLConversionRed() {
        let color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        // Red in HSL: hue=0, saturation=100%, lightness=50%
        XCTAssertEqual(hsl, "hsl(0, 100%, 50%)")
    }

    func testHSLConversionGreen() {
        let color = NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        // Green in HSL: hue=120, saturation=100%, lightness=50%
        XCTAssertEqual(hsl, "hsl(120, 100%, 50%)")
    }

    func testHSLConversionBlue() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        // Blue in HSL: hue=240, saturation=100%, lightness=50%
        XCTAssertEqual(hsl, "hsl(240, 100%, 50%)")
    }

    func testHSLConversionBlack() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        // Black: saturation and lightness are both 0%
        XCTAssertEqual(hsl, "hsl(0, 0%, 0%)")
    }

    func testHSLConversionWhite() {
        let color = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        // White: saturation=0%, lightness=100%
        XCTAssertEqual(hsl, "hsl(0, 0%, 100%)")
    }

    func testHSLConversionCustom() {
        // #FF6363 = rgb(255, 99, 99) ≈ hsl(0, 100%, 69%)
        let color = NSColor(red: 1.0, green: 99.0 / 255.0, blue: 99.0 / 255.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        // This is a reddish color with ~0 hue
        XCTAssertTrue(hsl.hasPrefix("hsl("))
        XCTAssertTrue(hsl.contains("100%")) // Full saturation
    }

    // MARK: - ColorInfo Tests

    func testColorInfoContainsAllFormats() {
        let color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let info = sut.getColorInfo(color)

        XCTAssertEqual(info.hex, "#FF0000")
        XCTAssertEqual(info.rgb, "rgb(255, 0, 0)")
        XCTAssertEqual(info.hsl, "hsl(0, 100%, 50%)")
    }

    // MARK: - Search Tests (via ColorPickerPlugin)

    func testSearchColorPicker() {
        let results = ColorPickerPlugin.shared.search(query: "color picker")
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.title, "Pick Color")
    }

    func testSearchPickColor() {
        let results = ColorPickerPlugin.shared.search(query: "pick color")
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.title, "Pick Color")
    }

    func testSearchColor() {
        let results = ColorPickerPlugin.shared.search(query: "color")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.first?.title.contains("Color") ?? false)
    }

    func testSearchPicker() {
        let results = ColorPickerPlugin.shared.search(query: "picker")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.first?.title.contains("Pick") ?? false)
    }

    func testSearchEyedropper() {
        let results = ColorPickerPlugin.shared.search(query: "eyedropper")
        XCTAssertFalse(results.isEmpty)
    }

    func testEmptySearchReturnsEmpty() {
        let results = ColorPickerPlugin.shared.search(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testUnrelatedSearchReturnsEmpty() {
        let results = ColorPickerPlugin.shared.search(query: "xyzabc123")
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - Config Tests
    
    func testConfigDefaultFormatIsHex() {
        // Reset to default by setting to hex first
        ColorPickerConfig.shared.preferredFormat = .hex
        XCTAssertEqual(ColorPickerConfig.shared.preferredFormat, .hex)
    }
    
    func testConfigCanChangePreferredFormat() {
        // Save original
        let original = ColorPickerConfig.shared.preferredFormat
        
        // Change to RGB
        ColorPickerConfig.shared.preferredFormat = .rgb
        XCTAssertEqual(ColorPickerConfig.shared.preferredFormat, .rgb)
        
        // Change to HSL
        ColorPickerConfig.shared.preferredFormat = .hsl
        XCTAssertEqual(ColorPickerConfig.shared.preferredFormat, .hsl)
        
        // Restore original
        ColorPickerConfig.shared.preferredFormat = original
    }
    
    func testConfigPersistsAcrossInstances() {
        // Save original
        let original = ColorPickerConfig.shared.preferredFormat
        
        // Change format
        ColorPickerConfig.shared.preferredFormat = .rgb
        
        // Create "new" instance by accessing singleton again
        let newConfig = ColorPickerConfig.shared
        XCTAssertEqual(newConfig.preferredFormat, .rgb)
        
        // Restore original
        ColorPickerConfig.shared.preferredFormat = original
    }
    
    func testColorFormatRawValues() {
        XCTAssertEqual(ColorFormat.hex.rawValue, "HEX")
        XCTAssertEqual(ColorFormat.rgb.rawValue, "RGB")
        XCTAssertEqual(ColorFormat.hsl.rawValue, "HSL")
    }
    
    func testColorFormatAllCases() {
        let allFormats = ColorFormat.allCases
        XCTAssertEqual(allFormats.count, 3)
        XCTAssertTrue(allFormats.contains(.hex))
        XCTAssertTrue(allFormats.contains(.rgb))
        XCTAssertTrue(allFormats.contains(.hsl))
    }
}
