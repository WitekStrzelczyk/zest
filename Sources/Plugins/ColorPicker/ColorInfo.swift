import AppKit
import Foundation

/// Represents color information in multiple formats
/// Uses Swift's synthesized memberwise initializer
struct ColorInfo: Sendable {
    let hex: String
    let rgb: String
    let hsl: String
    let color: NSColor
}
