import Foundation

enum ColorFormat: String, CaseIterable {
    case hex = "HEX"
    case rgb = "RGB"
    case hsl = "HSL"
}

final class ColorPickerConfig {
    static let shared = ColorPickerConfig()

    private let preferredFormatKey = "com.zest.colorpicker.preferredFormat"

    var preferredFormat: ColorFormat {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: preferredFormatKey),
                  let format = ColorFormat(rawValue: rawValue)
            else {
                return .hex
            }
            return format
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredFormatKey)
        }
    }

    private init() {}
}
