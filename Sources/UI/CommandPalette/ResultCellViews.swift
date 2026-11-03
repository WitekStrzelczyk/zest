import AppKit

enum Keycap {
    static func make(text: String, font: NSFont) -> (container: NSView, label: NSTextField) {
        let container = TintedLayerView()
        container.wantsLayer = true
        container.layer?.cornerRadius = AppStyle.KeyboardBadge.cornerRadius
        container.layer?.masksToBounds = true
        container.fillColor = AppStyle.KeyboardBadge.background
        container.strokeColor = AppStyle.KeyboardBadge.border
        container.layer?.borderWidth = 1
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = AppStyle.KeyboardBadge.text
        label.alignment = .center
        label.lineBreakMode = .byClipping
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -6),
        ])

        return (container, label)
    }
}

private func makeLabel(font: NSFont, color: NSColor, truncation: NSLineBreakMode) -> NSTextField {
    let label = NSTextField(labelWithString: "")
    label.font = font
    label.textColor = color
    label.lineBreakMode = truncation
    return label
}

private func makeIconView(cornerRadius: CGFloat) -> NSImageView {
    let imageView = NSImageView()
    imageView.wantsLayer = true
    imageView.layer?.cornerRadius = cornerRadius
    imageView.layer?.masksToBounds = true
    return imageView
}

private func makeIndexBadge() -> (badge: TintedLayerView, label: NSTextField) {
    let badge = TintedLayerView()
    badge.wantsLayer = true
    badge.layer?.cornerRadius = AppStyle.KeyboardBadge.cornerRadius
    badge.layer?.masksToBounds = true
    badge.layer?.borderWidth = 1
    badge.fillColor = AppStyle.KeyboardBadge.background
    badge.strokeColor = AppStyle.KeyboardBadge.border
    let label = makeLabel(font: AppStyle.KeyboardBadge.keyFont, color: AppStyle.KeyboardBadge.text, truncation: .byClipping)
    label.alignment = .center
    badge.addSubview(label)
    return (badge, label)
}

private func lineHeight(of label: NSTextField) -> CGFloat {
    ceil(label.intrinsicContentSize.height)
}

private func layoutIndexBadge(_ badge: NSView, label: NSTextField, x: CGFloat, in bounds: NSRect) {
    let height = AppStyle.KeyboardBadge.keyHeight
    badge.frame = NSRect(x: x, y: ((bounds.height - height) / 2).rounded(), width: 34, height: height)
    let labelHeight = lineHeight(of: label)
    label.frame = NSRect(x: 0, y: ((height - labelHeight) / 2).rounded(), width: 34, height: labelHeight)
}

final class ResultCellView: NSTableCellView {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("ResultCell")

    private let iconView = makeIconView(cornerRadius: 10)
    private let titleLabel = makeLabel(
        font: .systemFont(ofSize: 16, weight: .semibold),
        color: AppStyle.Palette.primaryText,
        truncation: .byTruncatingTail
    )
    private let subtitleLabel = makeLabel(
        font: .systemFont(ofSize: 12, weight: .regular),
        color: AppStyle.Palette.secondaryText,
        truncation: .byTruncatingTail
    )
    private let indexBadge: TintedLayerView
    private let indexLabel: NSTextField

    override var isFlipped: Bool {
        true
    }

    init() {
        (indexBadge, indexLabel) = makeIndexBadge()
        super.init(frame: .zero)
        identifier = Self.reuseIdentifier
        [iconView, indexBadge, titleLabel, subtitleLabel].forEach(addSubview)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        iconView.frame = NSRect(x: 10, y: ((bounds.height - 34) / 2).rounded(), width: 34, height: 34)
        layoutIndexBadge(indexBadge, label: indexLabel, x: 10, in: bounds)
        let textX: CGFloat = 56
        let textWidth = max(0, bounds.width - textX - 12)
        let titleHeight = lineHeight(of: titleLabel)
        titleLabel.frame = NSRect(x: textX, y: 8, width: textWidth, height: titleHeight)
        subtitleLabel.frame = NSRect(x: textX, y: 8 + titleHeight + 2, width: textWidth, height: lineHeight(of: subtitleLabel))
    }

    func configure(with result: SearchResult, row: Int, showsIndex: Bool) {
        iconView.image = result.icon
        effectiveAppearance.performAsCurrentDrawingAppearance {
            iconView.layer?.backgroundColor = AppStyle.Palette.iconChipBackground.cgColor
        }
        titleLabel.stringValue = result.title
        subtitleLabel.stringValue = result.subtitle
        indexLabel.stringValue = "\(row + 1)"
        indexBadge.isHidden = !showsIndex
        iconView.isHidden = showsIndex
        needsLayout = true
    }
}

final class FileResultCellView: NSTableCellView {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("FileResultCell")

    private let iconView = makeIconView(cornerRadius: 8)
    private let titleLabel = makeLabel(
        font: .systemFont(ofSize: 14, weight: .semibold),
        color: AppStyle.Palette.primaryText,
        truncation: .byTruncatingTail
    )
    private let pathLabel = makeLabel(
        font: .monospacedSystemFont(ofSize: 11, weight: .regular),
        color: AppStyle.Palette.secondaryText,
        truncation: .byTruncatingHead
    )
    private let metadataLabel = makeLabel(
        font: .systemFont(ofSize: 12, weight: .regular),
        color: AppStyle.Palette.tertiaryText,
        truncation: .byTruncatingTail
    )
    private let sizeLabel = makeLabel(
        font: .monospacedDigitSystemFont(ofSize: 11, weight: .medium),
        color: AppStyle.Palette.chipText,
        truncation: .byClipping
    )
    private let sizeBadge = TintedLayerView()
    private let indexBadge: TintedLayerView
    private let indexLabel: NSTextField

    override var isFlipped: Bool {
        true
    }

    init() {
        (indexBadge, indexLabel) = makeIndexBadge()
        super.init(frame: .zero)
        identifier = Self.reuseIdentifier

        sizeLabel.alignment = .center
        sizeBadge.wantsLayer = true
        sizeBadge.layer?.cornerRadius = 6
        sizeBadge.layer?.borderWidth = 1
        sizeBadge.fillColor = AppStyle.Palette.chipBackground
        sizeBadge.strokeColor = AppStyle.Palette.chipBorder
        sizeBadge.addSubview(sizeLabel)

        [iconView, indexBadge, titleLabel, pathLabel, metadataLabel, sizeBadge].forEach(addSubview)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        iconView.frame = NSRect(x: 8, y: ((bounds.height - 34) / 2).rounded(), width: 34, height: 34)
        layoutIndexBadge(indexBadge, label: indexLabel, x: 8, in: bounds)

        let sizeSize = sizeLabel.intrinsicContentSize
        let badgeWidth = max(42, ceil(sizeSize.width)) + 16
        let badgeHeight = ceil(sizeSize.height) + 8
        sizeBadge.frame = NSRect(
            x: bounds.width - 10 - badgeWidth,
            y: ((bounds.height - badgeHeight) / 2).rounded(),
            width: badgeWidth,
            height: badgeHeight
        )
        sizeLabel.frame = NSRect(x: 8, y: 4, width: badgeWidth - 16, height: ceil(sizeSize.height))

        let textX: CGFloat = 54
        let titleHeight = lineHeight(of: titleLabel)
        let titleFont = titleLabel.font ?? .systemFont(ofSize: 14)
        let pathFont = pathLabel.font ?? .systemFont(ofSize: 11)
        let pathWidth = min(260, ceil(pathLabel.intrinsicContentSize.width))
        let pathX = sizeBadge.frame.minX - 10 - pathWidth
        let baseline = 8 + titleFont.ascender
        pathLabel.frame = NSRect(
            x: pathX,
            y: (baseline - pathFont.ascender).rounded(),
            width: pathWidth,
            height: lineHeight(of: pathLabel)
        )
        titleLabel.frame = NSRect(x: textX, y: 8, width: max(0, pathX - 8 - textX), height: titleHeight)
        metadataLabel.frame = NSRect(
            x: textX,
            y: 8 + titleHeight + 3,
            width: max(0, sizeBadge.frame.minX - 8 - textX),
            height: lineHeight(of: metadataLabel)
        )
    }

    func configure(with result: SearchResult, path: String, row: Int, showsIndex: Bool) {
        iconView.image = result.icon
        titleLabel.stringValue = result.title
        pathLabel.stringValue = FileDetails.location(of: path)
        metadataLabel.stringValue = result.fileDetails?.summary ?? ""
        sizeLabel.stringValue = result.fileDetails?.size ?? "--"
        indexLabel.stringValue = "\(row + 1)"
        indexBadge.isHidden = !showsIndex
        iconView.isHidden = showsIndex
        needsLayout = true
    }
}
