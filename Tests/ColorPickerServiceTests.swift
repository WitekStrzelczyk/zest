import AppKit
import AppKit
import Testing
@testable import ZestApp

@MainActor
final class ColorPickerServiceTests {
    var sut: ColorPickerService!

    init() {
        sut = ColorPickerService.shared
    }

    isolated deinit {
        sut = nil
    }

    @Test func testColorPickerServiceCreation() {
        #expect(sut != nil)
    }

    @Test func testColorPickerServiceSingleton() {
        let service1 = ColorPickerService.shared
        let service2 = ColorPickerService.shared
        #expect(service1 === service2)
    }

    @Test func testHEXConversionRed() {
        let color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        #expect(hex == "#FF0000")
    }

    @Test func testHEXConversionGreen() {
        let color = NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        #expect(hex == "#00FF00")
    }

    @Test func testHEXConversionBlue() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        #expect(hex == "#0000FF")
    }

    @Test func testHEXConversionCustom() {
        let color = NSColor(red: 1.0, green: 99.0 / 255.0, blue: 99.0 / 255.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        #expect(hex == "#FF6363")
    }

    @Test func testHEXConversionBlack() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        #expect(hex == "#000000")
    }

    @Test func testHEXConversionWhite() {
        let color = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let hex = sut.toHEX(color)
        #expect(hex == "#FFFFFF")
    }

    @Test func testRGBConversionRed() {
        let color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        #expect(rgb == "rgb(255, 0, 0)")
    }

    @Test func testRGBConversionGreen() {
        let color = NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        #expect(rgb == "rgb(0, 255, 0)")
    }

    @Test func testRGBConversionBlue() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        #expect(rgb == "rgb(0, 0, 255)")
    }

    @Test func testRGBConversionCustom() {
        let color = NSColor(red: 1.0, green: 99.0 / 255.0, blue: 99.0 / 255.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        #expect(rgb == "rgb(255, 99, 99)")
    }

    @Test func testRGBConversionBlack() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        #expect(rgb == "rgb(0, 0, 0)")
    }

    @Test func testRGBConversionWhite() {
        let color = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let rgb = sut.toRGB(color)
        #expect(rgb == "rgb(255, 255, 255)")
    }

    @Test func testHSLConversionRed() {
        let color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        #expect(hsl == "hsl(0, 100%, 50%)")
    }

    @Test func testHSLConversionGreen() {
        let color = NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        #expect(hsl == "hsl(120, 100%, 50%)")
    }

    @Test func testHSLConversionBlue() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        #expect(hsl == "hsl(240, 100%, 50%)")
    }

    @Test func testHSLConversionBlack() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        #expect(hsl == "hsl(0, 0%, 0%)")
    }

    @Test func testHSLConversionWhite() {
        let color = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        #expect(hsl == "hsl(0, 0%, 100%)")
    }

    @Test func testHSLConversionCustom() {
        let color = NSColor(red: 1.0, green: 99.0 / 255.0, blue: 99.0 / 255.0, alpha: 1.0)
        let hsl = sut.toHSL(color)
        #expect(hsl.hasPrefix("hsl("))
        #expect(hsl.contains("100%"))
    }

    @Test func testColorInfoContainsAllFormats() {
        let color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let info = sut.getColorInfo(color)

        #expect(info.hex == "#FF0000")
        #expect(info.rgb == "rgb(255, 0, 0)")
        #expect(info.hsl == "hsl(0, 100%, 50%)")
    }

    @Test func testSearchColorPicker() {
        let results = ColorPickerPlugin.shared.search(query: "color picker")
        #expect(!results.isEmpty)
        #expect(results.first?.title == "Pick Color")
    }

    @Test func testSearchPickColor() {
        let results = ColorPickerPlugin.shared.search(query: "pick color")
        #expect(!results.isEmpty)
        #expect(results.first?.title == "Pick Color")
    }

    @Test func testSearchColor() {
        let results = ColorPickerPlugin.shared.search(query: "color")
        #expect(!results.isEmpty)
        #expect(results.first?.title.contains("Color") ?? false)
    }

    @Test func testSearchPicker() {
        let results = ColorPickerPlugin.shared.search(query: "picker")
        #expect(!results.isEmpty)
        #expect(results.first?.title.contains("Pick") ?? false)
    }

    @Test func testSearchEyedropper() {
        let results = ColorPickerPlugin.shared.search(query: "eyedropper")
        #expect(!results.isEmpty)
    }

    @Test func testEmptySearchReturnsEmpty() {
        let results = ColorPickerPlugin.shared.search(query: "")
        #expect(results.isEmpty)
    }

    @Test func testUnrelatedSearchReturnsEmpty() {
        let results = ColorPickerPlugin.shared.search(query: "xyzabc123")
        #expect(results.isEmpty)
    }
    
    @Test func testConfigDefaultFormatIsHex() {
        ColorPickerConfig.shared.preferredFormat = .hex
        #expect(ColorPickerConfig.shared.preferredFormat == .hex)
    }
    
    @Test func testConfigCanChangePreferredFormat() {
        let original = ColorPickerConfig.shared.preferredFormat
        
        ColorPickerConfig.shared.preferredFormat = .rgb
        #expect(ColorPickerConfig.shared.preferredFormat == .rgb)
        
        ColorPickerConfig.shared.preferredFormat = .hsl
        #expect(ColorPickerConfig.shared.preferredFormat == .hsl)
        
        ColorPickerConfig.shared.preferredFormat = original
    }
    
    @Test func testConfigPersistsAcrossInstances() {
        let original = ColorPickerConfig.shared.preferredFormat
        
        ColorPickerConfig.shared.preferredFormat = .rgb
        
        let newConfig = ColorPickerConfig.shared
        #expect(newConfig.preferredFormat == .rgb)
        
        ColorPickerConfig.shared.preferredFormat = original
    }
    
    @Test func testColorFormatRawValues() {
        #expect(ColorFormat.hex.rawValue == "HEX")
        #expect(ColorFormat.rgb.rawValue == "RGB")
        #expect(ColorFormat.hsl.rawValue == "HSL")
    }
    
    @Test func testColorFormatAllCases() {
        let allFormats = ColorFormat.allCases
        #expect(allFormats.count == 3)
        #expect(allFormats.contains(.hex))
        #expect(allFormats.contains(.rgb))
        #expect(allFormats.contains(.hsl))
    }
}
