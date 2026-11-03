import AppKit
import Foundation

final class ColorPickerService: @unchecked Sendable {
    static let shared: ColorPickerService = .init()

    private init() {}

    @MainActor
    func pickColor(completion: @escaping (ColorInfo?) -> Void) {
        let sampler = NSColorSampler()
        sampler.show { [weak self] selectedColor in
            guard let self, let color = selectedColor else {
                completion(nil)
                return
            }
            let info = getColorInfo(color)
            completion(info)
        }
    }

    func toHEX(_ color: NSColor) -> String {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    func toRGB(_ color: NSColor) -> String {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        return "rgb(\(red), \(green), \(blue))"
    }

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

    func getColorInfo(_ color: NSColor) -> ColorInfo {
        ColorInfo(
            hex: toHEX(color),
            rgb: toRGB(color),
            hsl: toHSL(color),
            color: color
        )
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
