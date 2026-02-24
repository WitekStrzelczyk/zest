import Foundation

/// Supported color output formats
enum ColorFormat: String, CaseIterable {
    case hex = "HEX"
    case rgb = "RGB"
    case hsl = "HSL"
}

/// Configuration storage for Color Picker plugin
final class ColorPickerConfig {
    // MARK: - Singleton
    
    static let shared = ColorPickerConfig()
    
    // MARK: - UserDefaults Keys
    
    private let preferredFormatKey = "com.zest.colorpicker.preferredFormat"
    
    // MARK: - Properties
    
    /// The user's preferred color format (default: HEX)
    var preferredFormat: ColorFormat {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: preferredFormatKey),
                  let format = ColorFormat(rawValue: rawValue) else {
                return .hex
            }
            return format
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredFormatKey)
        }
    }
    
    // MARK: - Init
    
    private init() {}
}
