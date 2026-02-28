import AppKit

enum AppStyle {
    enum Palette {
        static let backgroundTop = NSColor.windowBackgroundColor.withAlphaComponent(0.94)
        static let backgroundBottom = NSColor.underPageBackgroundColor.withAlphaComponent(0.96)
        static let backgroundGridStroke = NSColor.separatorColor.withAlphaComponent(0.04)

        static let rowSelectedFill = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.22)
        static let rowSelectedStroke = NSColor.separatorColor.withAlphaComponent(0.07)
        static let rowHoverFill = NSColor.separatorColor.withAlphaComponent(0.14)

        static let footerBackground = NSColor.controlBackgroundColor.withAlphaComponent(0.92)
        static let footerBorder = NSColor.separatorColor.withAlphaComponent(0.09)
        static let searchBarBorder = NSColor.separatorColor.withAlphaComponent(0.15)

        static let primaryText = NSColor.labelColor
        static let secondaryText = NSColor.secondaryLabelColor
        static let tertiaryText = NSColor.tertiaryLabelColor
        static let mutedText = NSColor.quaternaryLabelColor
        static let accentText = NSColor.secondaryLabelColor

        static let chipBackground = NSColor.controlBackgroundColor.withAlphaComponent(0.80)
        static let chipBorder = NSColor.separatorColor.withAlphaComponent(0.12)
        static let chipText = NSColor.secondaryLabelColor

        static let iconChipBackground = NSColor.controlBackgroundColor.withAlphaComponent(0.72)
    }

    enum KeyboardBadge {
        static let escWidth: CGFloat = 44
        static let escHeight: CGFloat = 22
        static let keyWidth: CGFloat = 52
        static let keyHeight: CGFloat = 22
        static let cornerRadius: CGFloat = 5
        static let escFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        static let keyFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)

        static let background = NSColor.controlBackgroundColor.withAlphaComponent(0.82)
        static let border = NSColor.separatorColor.withAlphaComponent(0.14)
        static let text = NSColor.secondaryLabelColor
    }
}
