import AppKit
import Combine

enum AppStyle {
    static func tone(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    static func gray(_ white: CGFloat, alpha: CGFloat = 1) -> NSColor {
        NSColor(white: white, alpha: alpha)
    }

    enum Palette {
        static let backgroundTop = AppStyle.tone(light: AppStyle.gray(0.985), dark: AppStyle.gray(0.094))
        static let backgroundBottom = AppStyle.tone(light: AppStyle.gray(0.975), dark: AppStyle.gray(0.078))
        static let surface = AppStyle.tone(light: AppStyle.gray(1), dark: AppStyle.gray(0.13))
        static let sidebar = AppStyle.tone(light: AppStyle.gray(0.96), dark: AppStyle.gray(0.11))
        static let hairline = AppStyle.tone(light: AppStyle.gray(0, alpha: 0.08), dark: AppStyle.gray(1, alpha: 0.07))

        static let rowSelectedFill = AppStyle.tone(light: AppStyle.gray(0.925), dark: AppStyle.gray(0.165))
        static let rowSelectedStroke = AppStyle.tone(light: AppStyle.gray(0, alpha: 0.03), dark: AppStyle.gray(1, alpha: 0.04))
        static let rowHoverFill = AppStyle.tone(light: AppStyle.gray(0, alpha: 0.035), dark: AppStyle.gray(1, alpha: 0.04))

        static let footerBackground = AppStyle.tone(light: AppStyle.gray(0.955), dark: AppStyle.gray(0.105))
        static let footerBorder = hairline
        static let searchBarBorder = hairline

        static let primaryText = AppStyle.tone(light: AppStyle.gray(0.1), dark: AppStyle.gray(0.93))
        static let secondaryText = AppStyle.tone(light: AppStyle.gray(0.42), dark: AppStyle.gray(0.61))
        static let tertiaryText = AppStyle.tone(light: AppStyle.gray(0.6), dark: AppStyle.gray(0.43))
        static let mutedText = AppStyle.tone(light: AppStyle.gray(0.7), dark: AppStyle.gray(0.36))
        static let accentText = secondaryText

        static let chipBackground = AppStyle.tone(light: AppStyle.gray(0.94), dark: AppStyle.gray(0.15))
        static let chipBorder = hairline
        static let chipText = secondaryText

        static let iconChipBackground = AppStyle.tone(light: AppStyle.gray(0.95), dark: AppStyle.gray(0.15))
    }

    enum KeyboardBadge {
        static let escWidth: CGFloat = 44
        static let escHeight: CGFloat = 22
        static let keyWidth: CGFloat = 52
        static let keyHeight: CGFloat = 22
        static let cornerRadius: CGFloat = 6
        static let escFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        static let keyFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)

        static let background = AppStyle.tone(light: AppStyle.gray(0.95), dark: AppStyle.gray(0.15))
        static let border = Palette.hairline
        static let text = Palette.secondaryText
    }
}

extension AppStyle {
    static func followTheme(of preferences: PreferencesManager) -> AnyCancellable {
        preferences.$theme.sink { theme in
            NSApplication.shared.appearance = theme.appearance
        }
    }
}

extension AppTheme {
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
