import AppKit
import Foundation

/// Represents color information in multiple formats
struct ColorInfo: Sendable {
    let hex: String
    let rgb: String
    let hsl: String
    let color: NSColor

    init(hex: String, rgb: String, hsl: String, color: NSColor) {
        self.hex = hex
        self.rgb = rgb
        self.hsl = hsl
        self.color = color
    }
}
