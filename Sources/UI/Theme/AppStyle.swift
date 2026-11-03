import AppKit
import Combine

enum AppStyle {
    static func adaptive(_ base: NSColor, alpha: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            var resolved = base
            appearance.performAsCurrentDrawingAppearance {
                resolved = base.withAlphaComponent(alpha)
            }
            return resolved
        }
    }

    enum Palette {
        static let backgroundTop = AppStyle.adaptive(.windowBackgroundColor, alpha: 0.94)
        static let backgroundBottom = AppStyle.adaptive(.underPageBackgroundColor, alpha: 0.96)
        static let backgroundGridStroke = AppStyle.adaptive(.separatorColor, alpha: 0.04)

        static let rowSelectedFill = AppStyle.adaptive(.selectedContentBackgroundColor, alpha: 0.22)
        static let rowSelectedStroke = AppStyle.adaptive(.separatorColor, alpha: 0.07)
        static let rowHoverFill = AppStyle.adaptive(.separatorColor, alpha: 0.14)

        static let footerBackground = AppStyle.adaptive(.controlBackgroundColor, alpha: 0.92)
        static let footerBorder = AppStyle.adaptive(.separatorColor, alpha: 0.09)
        static let searchBarBorder = AppStyle.adaptive(.separatorColor, alpha: 0.15)

        static let primaryText = NSColor.labelColor
        static let secondaryText = NSColor.secondaryLabelColor
        static let tertiaryText = NSColor.tertiaryLabelColor
        static let mutedText = NSColor.quaternaryLabelColor
        static let accentText = NSColor.secondaryLabelColor

        static let chipBackground = AppStyle.adaptive(.controlBackgroundColor, alpha: 0.80)
        static let chipBorder = AppStyle.adaptive(.separatorColor, alpha: 0.12)
        static let chipText = NSColor.secondaryLabelColor

        static let iconChipBackground = AppStyle.adaptive(.controlBackgroundColor, alpha: 0.72)
    }

    enum KeyboardBadge {
        static let escWidth: CGFloat = 44
        static let escHeight: CGFloat = 22
        static let keyWidth: CGFloat = 52
        static let keyHeight: CGFloat = 22
        static let cornerRadius: CGFloat = 5
        static let escFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        static let keyFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)

        static let background = AppStyle.adaptive(.controlBackgroundColor, alpha: 0.82)
        static let border = AppStyle.adaptive(.separatorColor, alpha: 0.14)
        static let text = NSColor.secondaryLabelColor
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
