import AppKit
import Foundation

/// Service that provides color picker functionality using NSColorSampler
/// Allows users to pick colors from anywhere on screen and get them in multiple formats
final class ColorPickerService: @unchecked Sendable {
    // MARK: - Singleton

    static let shared: ColorPickerService = .init()

    private init() {}

    // MARK: - Public API

    /// Shows the system color sampler (eyedropper) and calls the completion with the picked color
    /// - Parameter completion: Called when user picks a color, or nil if cancelled
    @MainActor
    func pickColor(completion: @escaping (ColorInfo?) -> Void) {
        let sampler = NSColorSampler()
        sampler.show { [weak self] selectedColor in
            guard let self, let color = selectedColor else {
                completion(nil)
                return
            }
            let info = self.getColorInfo(color)
            completion(info)
        }
    }

    /// Convert NSColor to HEX format
    /// - Parameter color: The NSColor to convert
    /// - Returns: HEX string in format #RRGGBB
    func toHEX(_ color: NSColor) -> String {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    /// Convert NSColor to RGB format
    /// - Parameter color: The NSColor to convert
    /// - Returns: RGB string in format rgb(r, g, b)
    func toRGB(_ color: NSColor) -> String {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        return "rgb(\(red), \(green), \(blue))"
    }

    /// Convert NSColor to HSL format
    /// - Parameter color: The NSColor to convert
    /// - Returns: HSL string in format hsl(h, s%, l%)
    func toHSL(_ color: NSColor) -> String {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color
        let r = rgbColor.redComponent
        let g = rgbColor.greenComponent
        let b = rgbColor.blueComponent

        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)
        let delta = max - min

        var h: CGFloat = 0
        var s: CGFloat = 0
        let l = (max + min) / 2

        if delta != 0 {
            s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min)

            if max == r {
                h = ((g - b) / delta) + (g < b ? 6 : 0)
            } else if max == g {
                h = ((b - r) / delta) + 2
            } else {
                h = ((r - g) / delta) + 4
            }

            h /= 6
        }

        let hue = Int(round(h * 360))
        let saturation = Int(round(s * 100))
        let lightness = Int(round(l * 100))

        return "hsl(\(hue), \(saturation)%, \(lightness)%)"
    }

    /// Get all color format information for a given color
    /// - Parameter color: The NSColor to convert
    /// - Returns: ColorInfo containing all format representations
    func getColorInfo(_ color: NSColor) -> ColorInfo {
        ColorInfo(
            hex: toHEX(color),
            rgb: toRGB(color),
            hsl: toHSL(color),
            color: color
        )
    }

    /// Copy a string to the clipboard
    /// - Parameter text: The text to copy
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
