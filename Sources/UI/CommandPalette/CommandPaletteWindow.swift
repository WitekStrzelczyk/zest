import AppKit
import Carbon
import Quartz

final class PaletteBackgroundView: NSView {
    override func draw(_: NSRect) {
        let bounds = bounds
        let gradient = NSGradient(
            colors: [
                AppStyle.Palette.backgroundTop,
                AppStyle.Palette.backgroundBottom,
            ]
        )
        gradient?.draw(in: bounds, angle: -90)
    }
}

final class TintedLayerView: NSView {
    var fillColor: NSColor? {
        didSet { applyColors() }
    }

    var strokeColor: NSColor? {
        didSet { applyColors() }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    func applyColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = fillColor?.cgColor
            layer?.borderColor = strokeColor?.cgColor
        }
    }
}

extension NSView {
    func refreshTintedLayers() {
        (self as? TintedLayerView)?.applyColors()
        subviews.forEach { $0.refreshTintedLayers() }
    }
}

final class ResultRowView: NSTableRowView {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("ResultRow")
    private let horizontalInset: CGFloat = 6
    private let verticalInset: CGFloat = 1

    var isHovered: Bool = false {
        didSet {
            if oldValue != isHovered { needsDisplay = true }
        }
    }

    var isDangerMode: Bool = false {
        didSet {
            if oldValue != isDangerMode { needsDisplay = true }
        }
    }

    var isKillAttempted: Bool = false {
        didSet {
            if oldValue != isKillAttempted { needsDisplay = true }
        }
    }

    private var shouldShowDangerStyle: Bool {
        isDangerMode || isKillAttempted
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isHovered = false
        isDangerMode = false
        isKillAttempted = false
    }

    override func drawSelection(in _: NSRect) {
        if shouldShowDangerStyle {
            NSColor.systemRed.withAlphaComponent(0.15).setFill()
            let path = NSBezierPath(
                roundedRect: bounds.insetBy(dx: horizontalInset, dy: verticalInset),
                xRadius: 8,
                yRadius: 8
            )
            path.fill()

            NSColor.systemRed.withAlphaComponent(isKillAttempted && !isDangerMode ? 0.4 : 0.6).setStroke()
            path.lineWidth = isKillAttempted && !isDangerMode ? 1.0 : 1.5
            path.stroke()
        } else {
            AppStyle.Palette.rowSelectedFill.setFill()
            let path = NSBezierPath(
                roundedRect: bounds.insetBy(dx: horizontalInset, dy: verticalInset),
                xRadius: 8,
                yRadius: 8
            )
            path.fill()
            AppStyle.Palette.rowSelectedStroke.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if shouldShowDangerStyle {
            NSColor.systemRed.withAlphaComponent(isKillAttempted && !isDangerMode ? 0.08 : 0.1).setFill()
            let path = NSBezierPath(
                roundedRect: bounds.insetBy(dx: horizontalInset, dy: verticalInset),
                xRadius: 8,
                yRadius: 8
            )
            path.fill()

            NSColor.systemRed.withAlphaComponent(isKillAttempted && !isDangerMode ? 0.4 : 0.5).setStroke()
            path.lineWidth = isKillAttempted && !isDangerMode ? 1.0 : 1.5
            path.stroke()
        } else if !isSelected, isHovered {
            AppStyle.Palette.rowHoverFill.setFill()
            let path = NSBezierPath(
                roundedRect: bounds.insetBy(dx: horizontalInset, dy: verticalInset),
                xRadius: 8,
                yRadius: 8
            )
            path.fill()
        }
        super.draw(dirtyRect)
    }
}

final class FadingScrollView: NSScrollView {
    private let fadeHeight: CGFloat = 16

    override func layout() {
        super.layout()
        updateFadeMask()
    }

    override func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        updateFadeMask()
    }

    private func updateFadeMask() {
        wantsLayer = true
        guard let docView = documentView else {
            layer?.mask = nil
            return
        }
        guard bounds.height > 1, bounds.width > 1 else {
            layer?.mask = nil
            return
        }

        let contentHeight = docView.frame.height
        let visibleHeight = contentView.bounds.height
        guard contentHeight > visibleHeight else {
            layer?.mask = nil
            return
        }
        guard visibleHeight > 1 else {
            layer?.mask = nil
            return
        }

        let scrollOffset = contentView.bounds.origin.y
        let maxScroll = contentHeight - visibleHeight
        let fadeTop = scrollOffset > 1
        let fadeBottom = scrollOffset < maxScroll - 1

        let maskLayer = CAGradientLayer()
        maskLayer.frame = bounds
        maskLayer.colors = [
            fadeTop ? NSColor.clear.cgColor : NSColor.black.cgColor,
            NSColor.black.cgColor,
            NSColor.black.cgColor,
            fadeBottom ? NSColor.clear.cgColor : NSColor.black.cgColor,
        ]

        let normalizedFade = min(0.49, fadeHeight / bounds.height)
        let topStop = fadeTop ? normalizedFade : 0
        let bottomStop = fadeBottom ? 1 - normalizedFade : 1
        maskLayer.locations = [0, NSNumber(value: Double(topStop)), NSNumber(value: Double(bottomStop)), 1]

        layer?.mask = maskLayer
    }
}

final class ResultsTableView: NSTableView {
    weak var commandPalette: CommandPaletteWindow?

    override var acceptsFirstResponder: Bool {
        true
    }

    func clearHover() {
        enumerateAvailableRowViews { rowView, _ in
            if let resultRowView = rowView as? ResultRowView {
                resultRowView.isHovered = false
            }
        }

        for row in 0..<numberOfRows {
            if let rowView = rowView(atRow: row, makeIfNecessary: false) as? ResultRowView {
                rowView.isHovered = false
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        guard let palette = commandPalette else {
            super.keyDown(with: event)
            return
        }

        if event.modifierFlags.contains(.command),
           palette.handleIndexedShortcutFromTable(forKeyCode: Int(event.keyCode))
        {
            return
        }

        switch Int(event.keyCode) {
        case kVK_Escape:
            palette.clearDangerMode()
            palette.handleEscape()

        case kVK_Return:
            if event.modifierFlags.contains(.command) {
                palette.revealCurrentResult()
            } else if palette.isDangerMode {
                palette.forceQuitCurrentResult()
            } else {
                palette.selectCurrentResult()
            }

        case kVK_UpArrow:
            palette.clearDangerMode()
            clearHover()
            if selectedRow <= 0 {
                palette.returnToSearchField()
            } else {
                super.keyDown(with: event)
            }

        case kVK_DownArrow:
            palette.clearDangerMode()
            clearHover()
            super.keyDown(with: event)

        case kVK_Space:
            palette.toggleQuickLook()

        default:
            if let characters = event.characters,
               !characters.isEmpty,
               !event.modifierFlags.contains(.command),
               !event.modifierFlags.contains(.control)
            {
                palette.clearDangerMode()
                palette.returnToSearchFieldAndType(characters)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)

        if clickedRow >= 0, clickedRow < numberOfRows {
            selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            commandPalette?.selectCurrentResult()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)

        clearHover()

        if row >= 0, row < numberOfRows {
            if let rowView = rowView(atRow: row, makeIfNecessary: false) as? ResultRowView {
                rowView.isHovered = true
            }
        }
    }

    override func mouseExited(with _: NSEvent) {
        clearHover()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .mouseEnteredAndExited,
            .activeInActiveApp,
            .inVisibleRect,
        ]

        for area in trackingAreas {
            if area.owner === self {
                removeTrackingArea(area)
            }
        }

        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    func setHoverOnRowsForTesting(_ rows: [Int]) {
        for row in rows {
            if row >= 0, row < numberOfRows {
                if let rowView = rowView(atRow: row, makeIfNecessary: true) as? ResultRowView {
                    rowView.isHovered = true
                }
            }
        }
    }

    func hasAnyHoveredRowsForTesting() -> Bool {
        var hasHovered = false
        enumerateAvailableRowViews { rowView, _ in
            if let resultRowView = rowView as? ResultRowView, resultRowView.isHovered {
                hasHovered = true
            }
        }
        return hasHovered
    }
}

final class CommandPaletteWindow: NSPanel {
    static var showsOnScreen = true

    private(set) var searchField: NSTextField!
    private var searchIcon: NSImageView!
    private var resultsTableView: ResultsTableView!
    private var scrollView: NSScrollView!
    private(set) var hintLabel: NSTextField!
    private var suggestionsLabel: NSTextField!
    private var noResultsLabel: NSTextField!

    private var statsLabel: NSTextField!
    private var searchContainerView: NSView!
    private var hoverTrackingArea: NSTrackingArea?
    private var lastSearchTrace: SearchSpan?
    private var statsEnabled: Bool {
        !UserDefaults.standard.bool(forKey: "hideSearchStats")
    }

    private(set) var searchResults: [SearchResult] = []

    private var isResultsFocused: Bool = false

    private var isQuickLookOpen: Bool = false

    private var isOptionKeyPressed: Bool = false
    private var isCommandKeyPressed: Bool = false

    private var actionBarView: NSView?

    private var contextualActionBar: NSView!

    private var contextualActionLabel: NSTextField!
    private var contextualFooterLeftLabel: NSTextField!
    private var preferencesIconView: NSImageView!
    private var preferencesLabel: NSTextField!
    private var storeIconView: NSImageView!
    private var storeLabel: NSTextField!

    private let actionBarOptionLabels: [String] = ["convert", "translate"]

    private let contextualBarHeight: CGFloat = 36

    private var actionBarScrollViewTopConstraint: NSLayoutConstraint?

    private var originalScrollViewTopConstraint: NSLayoutConstraint?

    private(set) var isSettingsMode: Bool = false {
        didSet {
            if isSettingsMode != oldValue {
                handleModeChange()
            }
        }
    }

    private(set) var isDangerMode: Bool = false {
        didSet {
            if isDangerMode != oldValue {
                updateDangerModeAppearance()
            }
        }
    }

    private let stateStore = CommandPaletteStateStore.shared
    private let controller = CommandPaletteController.shared
    private var stateObserver: NSObjectProtocol?

    private func handleModeChange() {
        if isSettingsMode {
            SearchEngine.shared.cancelCurrentSearch()

            searchField.isHidden = true
            searchIcon.isHidden = true
            scrollView.isHidden = true
            noResultsLabel.isHidden = true
            hintLabel.isHidden = true

            showSettingsUI()
        } else {
            settingsContainerView?.isHidden = true
            settingsContainerView?.removeFromSuperview()
            settingsContainerView = nil

            searchField.isHidden = false
            searchIcon.isHidden = false
            searchField.stringValue = preservedSearchQuery
            hintLabel.isHidden = false

            if !searchResults.isEmpty {
                scrollView.isHidden = false
            }

            resizePalette(to: emptyStateHeight)

            if !preservedSearchQuery.isEmpty {
                performSearch(preservedSearchQuery)
            }

            makeFirstResponder(searchField)
        }
    }

    func clearDangerMode() {
        guard isDangerMode else { return }
        isDangerMode = false
        updateDangerModeAppearance()
    }

    private func updateDangerModeAppearance() {
        let selectedRow = resultsTableView.selectedRow
        guard selectedRow >= 0 else { return }

        if let rowView = resultsTableView.rowView(atRow: selectedRow, makeIfNecessary: false) as? ResultRowView {
            rowView.isDangerMode = isDangerMode
            rowView.needsDisplay = true
        }

        updateContextualActionBar()
    }

    func forceQuitCurrentResult() {
        var selectedRow = resultsTableView.selectedRow

        if selectedRow < 0, !searchResults.isEmpty {
            selectedRow = 0
        }

        guard selectedRow >= 0, selectedRow < searchResults.count else {
            close()
            return
        }

        let result = searchResults[selectedRow]
        let processPID = result.pid

        guard result.category == .process, let pid = processPID else {
            close()
            return
        }

        clearDangerMode()

        result.reveal()

        checkProcessAndRefresh(pid: pid, attempts: 0)
    }

    private func checkProcessAndRefresh(pid: pid_t, attempts: Int) {
        let maxAttempts = 5
        let delays: [TimeInterval] = [0.2, 0.3, 0.5, 0.5, 1.0]

        guard attempts < maxAttempts else {
            refreshProcessResults()
            return
        }

        let delay = delays[attempts]

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            let processExists = kill(pid, 0) == 0

            if processExists {
                self?.checkProcessAndRefresh(pid: pid, attempts: attempts + 1)
            } else {
                self?.refreshProcessResults()
            }
        }
    }

    private func refreshProcessResults() {
        let currentQuery = searchField.stringValue
        performSearch(currentQuery)
    }

    private func createContextualActionBar() -> NSView {
        let container = TintedLayerView()
        container.wantsLayer = true
        container.fillColor = AppStyle.Palette.footerBackground
        container.translatesAutoresizingMaskIntoConstraints = false

        let borderView = TintedLayerView()
        borderView.wantsLayer = true
        borderView.fillColor = AppStyle.Palette.footerBorder
        borderView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(borderView)

        let leftStack = NSStackView()
        leftStack.orientation = .horizontal
        leftStack.alignment = .centerY
        leftStack.spacing = 16
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        let prefStack = NSStackView()
        prefStack.orientation = .horizontal
        prefStack.alignment = .centerY
        prefStack.spacing = 6
        prefStack.translatesAutoresizingMaskIntoConstraints = false
        preferencesIconView = NSImageView(image: NSImage(
            systemSymbolName: "gearshape.fill",
            accessibilityDescription: "Preferences"
        ) ?? NSImage())
        preferencesIconView.contentTintColor = AppStyle.Palette.secondaryText
        preferencesIconView.translatesAutoresizingMaskIntoConstraints = false
        preferencesLabel = NSTextField(labelWithString: "Preferences")
        preferencesLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        preferencesLabel.textColor = AppStyle.Palette.secondaryText
        preferencesLabel.translatesAutoresizingMaskIntoConstraints = false
        prefStack.addArrangedSubview(preferencesIconView)
        prefStack.addArrangedSubview(preferencesLabel)
        prefStack.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(preferencesClicked)))

        let storeStack = NSStackView()
        storeStack.orientation = .horizontal
        storeStack.alignment = .centerY
        storeStack.spacing = 6
        storeStack.translatesAutoresizingMaskIntoConstraints = false
        storeIconView = NSImageView(image: NSImage(
            systemSymbolName: "shippingbox.fill",
            accessibilityDescription: "Store"
        ) ?? NSImage())
        storeIconView.contentTintColor = AppStyle.Palette.secondaryText
        storeIconView.translatesAutoresizingMaskIntoConstraints = false
        storeLabel = NSTextField(labelWithString: "Store")
        storeLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        storeLabel.textColor = AppStyle.Palette.secondaryText
        storeLabel.translatesAutoresizingMaskIntoConstraints = false
        storeStack.addArrangedSubview(storeIconView)
        storeStack.addArrangedSubview(storeLabel)

        leftStack.addArrangedSubview(prefStack)
        leftStack.addArrangedSubview(storeStack)
        container.addSubview(leftStack)

        contextualActionLabel = NSTextField(labelWithString: "")
        contextualActionLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        contextualActionLabel.textColor = AppStyle.Palette.secondaryText
        contextualActionLabel.alignment = .right
        contextualActionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contextualActionLabel)

        NSLayoutConstraint.activate([
            borderView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            borderView.topAnchor.constraint(equalTo: container.topAnchor),
            borderView.heightAnchor.constraint(equalToConstant: 1),

            leftStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            leftStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            preferencesIconView.widthAnchor.constraint(equalToConstant: 14),
            preferencesIconView.heightAnchor.constraint(equalToConstant: 14),
            storeIconView.widthAnchor.constraint(equalToConstant: 14),
            storeIconView.heightAnchor.constraint(equalToConstant: 14),

            contextualActionLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: leftStack.trailingAnchor,
                constant: 12
            ),
            contextualActionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            contextualActionLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    func updateContextualActionBar() {
        let selectedRow = resultsTableView.selectedRow

        guard selectedRow >= 0, selectedRow < searchResults.count else {
            contextualActionLabel.stringValue = "⏎ Open   |   ⌘⏎ Actions"
            return
        }

        let result = searchResults[selectedRow]

        switch result.category {
        case .process:
            if isDangerMode {
                contextualActionLabel.stringValue = "⚠ ⌘⏎ Force Kill   |   Esc Cancel"
            } else {
                contextualActionLabel.stringValue = "⏎ Activate   |   ⌘⏎ Kill Process"
            }
        case .file:
            contextualActionLabel.stringValue = "⏎ Open   |   ⌘⏎ Reveal   |   Space Preview"
        case .application:
            contextualActionLabel.stringValue = "⏎ Launch   |   ⌘⏎ Reveal"
        case .calendar:
            contextualActionLabel.stringValue = "⏎ Join   |   ⌘⏎ Details"
        default:
            contextualActionLabel.stringValue = "⏎ Open   |   ⌘⏎ Actions"
        }
    }

    private var settingsContainerView: NSView?
    private var quicklinkNameField: NSTextField?
    private var quicklinkURLField: NSTextField?
    private var createQuicklinkButton: NSButton?
    private var backButton: NSButton?

    private var preservedSearchQuery: String = ""

    private var quickLookGlobalMonitor: Any?
    private var quickLookLocalMonitor: Any?

    private let windowWidth: CGFloat = 720
    private let searchFieldHeight: CGFloat = 56
    private let rowHeight: CGFloat = 52
    private let hintHeight: CGFloat = 0
    private let emptyStateHeight: CGFloat = 96
    private let maxVisibleResultRows: Int = 6
    private let resultsContainerVerticalPadding: CGFloat = 20
    private var paletteCard: NSView?
    private var paletteHeight: NSLayoutConstraint?

    private var maximumPaletteHeight: CGFloat {
        searchFieldHeight + CGFloat(maxVisibleResultRows) * rowHeight + resultsContainerVerticalPadding + contextualBarHeight
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override init(
        contentRect _: NSRect,
        styleMask _: NSWindow.StyleMask,
        backing _: NSWindow.BackingStoreType,
        defer _: Bool
    ) {
        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: windowWidth,
                height: searchFieldHeight + hintHeight + contextualBarHeight
            ),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupUI()
        setupNotifications()
        setupStateObservation()
    }

    deinit {
        if let observer = stateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowAddQuicklink),
            name: .showAddQuicklink,
            object: nil
        )
    }

    private func setupStateObservation() {
        stateObserver = NotificationCenter.default.addObserver(
            forName: .commandPaletteStateDidChange,
            object: CommandPaletteStateStore.shared,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let state = notification.userInfo?[commandPaletteStateUserInfoKey] as? CommandPaletteState
            else { return }
            render(state: state)
        }
    }

    private func render(state: CommandPaletteState) {
        guard !isSettingsMode else { return }

        if state.query.isEmpty {
            searchResults = []
            resultsTableView.reloadData()
            scrollView.isHidden = true
            noResultsLabel.isHidden = true
            hintLabel.isHidden = true
            contextualActionBar.isHidden = true
            resizePalette(to: emptyStateHeight)
            return
        }

        guard initialWindowTop != nil else { return }
        updateSearchResults(state.results)
    }

    @objc private func handleShowAddQuicklink() {
        enterSettingsMode()
    }

    private func setupWindow() {
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        hasShadow = true
        isOpaque = false
        becomesKeyOnlyIfNeeded = false
        autorecalculatesKeyViewLoop = false
    }

    private func setupUI() {
        let contentView = PaletteBackgroundView(frame: NSRect(
            x: 0,
            y: 0,
            width: windowWidth,
            height: searchFieldHeight + hintHeight + contextualBarHeight
        ))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 14
        contentView.layer?.masksToBounds = true

        let searchBarContainer = TintedLayerView()
        searchBarContainer.wantsLayer = true
        searchBarContainer.layer?.cornerRadius = 10
        searchBarContainer.layer?.masksToBounds = true
        searchBarContainer.fillColor = AppStyle.Palette.surface
        searchBarContainer.strokeColor = AppStyle.Palette.searchBarBorder
        searchBarContainer.layer?.borderWidth = 1
        searchBarContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchBarContainer)

        searchIcon = NSImageView()
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        searchIcon.contentTintColor = AppStyle.Palette.accentText
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchBarContainer.addSubview(searchIcon)

        searchField = NSTextField()
        searchField.placeholderString = "Search or type a command..."
        let searchFieldFont = NSFont.systemFont(ofSize: 22, weight: .medium)
        if let cell = searchField.cell as? NSTextFieldCell {
            cell.placeholderAttributedString = NSAttributedString(
                string: "Search or type a command...",
                attributes: [
                    .font: searchFieldFont,
                    .foregroundColor: AppStyle.Palette.mutedText.withAlphaComponent(0.38),
                ]
            )
        }
        searchField.font = searchFieldFont
        searchField.isBordered = false
        searchField.focusRingType = .none
        searchField.backgroundColor = .clear
        searchField.textColor = AppStyle.Palette.primaryText
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchBarContainer.addSubview(searchField)

        let (escBadge, _) = Keycap.make(text: "ESC", font: AppStyle.KeyboardBadge.escFont)
        searchBarContainer.addSubview(escBadge)

        hintLabel = NSTextField(labelWithString: "")
        hintLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        hintLabel.textColor = AppStyle.Palette.mutedText
        hintLabel.alignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.isHidden = true
        contentView.addSubview(hintLabel)

        suggestionsLabel = NSTextField(labelWithString: "SUGGESTIONS")
        suggestionsLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        suggestionsLabel.textColor = AppStyle.Palette.mutedText
        suggestionsLabel.translatesAutoresizingMaskIntoConstraints = false
        suggestionsLabel.isHidden = true
        contentView.addSubview(suggestionsLabel)

        contextualActionBar = createContextualActionBar()
        contentView.addSubview(contextualActionBar)

        statsLabel = NSTextField(labelWithString: "")
        statsLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        statsLabel.textColor = AppStyle.Palette.tertiaryText
        statsLabel.alignment = .right
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.isHidden = true
        statsLabel.toolTip = "Search performance metrics"
        contentView.addSubview(statsLabel)

        resultsTableView = ResultsTableView()
        resultsTableView.style = .inset
        resultsTableView.headerView = nil
        resultsTableView.backgroundColor = .clear
        resultsTableView.selectionHighlightStyle = .regular
        resultsTableView.delegate = self
        resultsTableView.dataSource = self
        resultsTableView.commandPalette = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Result"))
        resultsTableView.addTableColumn(column)
        resultsTableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        scrollView = FadingScrollView()
        scrollView.documentView = resultsTableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        scrollView.isHidden = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.wantsLayer = true
        contentView.addSubview(scrollView)

        noResultsLabel = NSTextField(labelWithString: "No results found")
        noResultsLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        noResultsLabel.textColor = .secondaryLabelColor
        noResultsLabel.alignment = .center
        noResultsLabel.isHidden = true
        noResultsLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(noResultsLabel)

        NSLayoutConstraint.activate([
            searchBarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchBarContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            searchBarContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            searchBarContainer.heightAnchor.constraint(equalToConstant: 40),

            searchIcon.leadingAnchor.constraint(equalTo: searchBarContainer.leadingAnchor, constant: 12),
            searchIcon.centerYAnchor.constraint(equalTo: searchBarContainer.centerYAnchor, constant: 1),
            searchIcon.widthAnchor.constraint(equalToConstant: 20),
            searchIcon.heightAnchor.constraint(equalToConstant: 20),

            escBadge.trailingAnchor.constraint(equalTo: searchBarContainer.trailingAnchor, constant: -10),
            escBadge.centerYAnchor.constraint(equalTo: searchBarContainer.centerYAnchor),
            escBadge.widthAnchor.constraint(equalToConstant: AppStyle.KeyboardBadge.escWidth),
            escBadge.heightAnchor.constraint(equalToConstant: AppStyle.KeyboardBadge.escHeight),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: escBadge.leadingAnchor, constant: -10),
            searchField.centerYAnchor.constraint(equalTo: searchBarContainer.centerYAnchor),
        ])

        originalScrollViewTopConstraint = scrollView.topAnchor.constraint(
            equalTo: searchBarContainer.bottomAnchor,
            constant: 8
        )
        originalScrollViewTopConstraint?.isActive = true

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contextualActionBar.topAnchor, constant: 0),
            scrollView.topAnchor.constraint(equalTo: suggestionsLabel.bottomAnchor, constant: 8),

            suggestionsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            suggestionsLabel.topAnchor.constraint(equalTo: searchBarContainer.bottomAnchor, constant: 10),

            noResultsLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            noResultsLabel.topAnchor.constraint(equalTo: suggestionsLabel.bottomAnchor, constant: 20),

            contextualActionBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contextualActionBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contextualActionBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            contextualActionBar.heightAnchor.constraint(equalToConstant: contextualBarHeight),

            statsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            statsLabel.bottomAnchor.constraint(equalTo: contextualActionBar.topAnchor, constant: -4),
            statsLabel.heightAnchor.constraint(equalToConstant: 14),
        ])

        setupHoverTracking(in: contentView)

        let stage = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: maximumPaletteHeight))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stage.addSubview(contentView)
        let height = contentView.heightAnchor.constraint(equalToConstant: emptyStateHeight)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: stage.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: stage.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: stage.topAnchor),
            height,
        ])
        paletteHeight = height
        paletteCard = contentView
        self.contentView = stage
    }

    private func setupHoverTracking(in view: NSView) {
        if let oldTracking = hoverTrackingArea {
            view.removeTrackingArea(oldTracking)
        }

        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if statsEnabled, let trace = lastSearchTrace {
            updateStatsLabel(with: trace)
            statsLabel.isHidden = false
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        statsLabel.isHidden = true
    }

    private func updateStatsLabel(with trace: SearchSpan) {
        var stats: [String] = []

        let totalMs = trace.durationMsPrecise
        stats.append(String(format: "⏱%.1fms", totalMs))

        for child in trace.children {
            let name = child.operationName
            let ms = child.durationMsPrecise
            let resultsCount = child.tags["results"] as? Int

            let shortName: String = switch name {
            case "calculator": "calc"
            case "applications": "apps"
            case "user_commands": "cmd"
            case "contacts": "👤"
            case "clipboard": "📋"
            case "files": "📁"
            case "global_commands": "⌨️"
            case "toggles": "tgl"
            case "quicklinks": "🔗"
            case "deduplicate_sort": "sort"
            case "settings": "⚙️"
            case "unit_conversion": "conv"
            default: name.prefix(4).lowercased()
            }

            if let count = resultsCount, count > 0 {
                stats.append("\(shortName):\(String(format: "%.1f", ms))ms(\(count))")
            } else if ms > 0.1 {
                stats.append("\(shortName):\(String(format: "%.1f", ms))ms")
            }
        }

        statsLabel.stringValue = stats.joined(separator: " | ")
    }

    func setSearchTrace(_ trace: SearchSpan) {
        lastSearchTrace = trace

        if statsEnabled {
            updateStatsLabel(with: trace)
            statsLabel.isHidden = false
        }
    }

    func show(previousApp _: NSRunningApplication? = nil) {
        SearchEngine.shared.preloadApps()
        contentView?.refreshTintedLayers()
        searchField.stringValue = ""
        searchResults = []
        resultsTableView.reloadData()
        scrollView.isHidden = true
        noResultsLabel.isHidden = true
        hintLabel.isHidden = true
        suggestionsLabel.isHidden = true
        contextualActionBar.isHidden = true
        isResultsFocused = false
        isOptionKeyPressed = false
        isCommandKeyPressed = false
        hideActionBar()
        isDangerMode = false
        stateStore.clearIntent()

        resizePalette(to: emptyStateHeight)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowX = screenFrame.midX - windowWidth / 2
            let top = screenFrame.midY + 120 + emptyStateHeight
            let frame = NSRect(x: windowX, y: top - maximumPaletteHeight, width: windowWidth, height: maximumPaletteHeight)
            setFrame(frame, display: true)
            initialWindowTop = top
        }

        guard Self.showsOnScreen else {
            alphaValue = 0
            ignoresMouseEvents = true
            orderFrontRegardless()
            makeFirstResponder(searchField)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    override func close() {
        removeQuickLookMonitors()
        if isQuickLookOpen, QLPreviewPanel.sharedPreviewPanelExists() {
            QLPreviewPanel.shared().orderOut(nil)
            isQuickLookOpen = false
        }
        searchResults = []
        resultsTableView.reloadData()
        suggestionsLabel.isHidden = true
        isSettingsMode = false
        stateStore.clearIntent()
        isOptionKeyPressed = false
        isCommandKeyPressed = false
        hideActionBar()
        controller.handleQuery("")
        orderOut(nil)
    }

    func enterSettingsMode() {
        guard !isSettingsMode else { return }

        preservedSearchQuery = searchField.stringValue

        searchResults = []
        resultsTableView.reloadData()

        isSettingsMode = true
    }

    func exitSettingsMode() {
        guard isSettingsMode else { return }

        searchResults = []
        resultsTableView.reloadData()

        isSettingsMode = false
    }

    private func showSettingsUI() {
        guard let contentView = paletteCard else { return }

        let settingsHeight: CGFloat = 180
        resizePalette(to: settingsHeight)

        let settingsView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: settingsHeight))
        settingsView.wantsLayer = true

        let backBtn = NSButton(title: "← Back", target: self, action: #selector(backButtonClicked))
        backBtn.bezelStyle = .inline
        backBtn.isBordered = false
        backBtn.contentTintColor = .secondaryLabelColor
        backBtn.font = NSFont.systemFont(ofSize: 13)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        settingsView.addSubview(backBtn)
        backButton = backBtn

        let titleLabel = NSTextField(labelWithString: "Add Quicklink")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        settingsView.addSubview(titleLabel)

        let createBtn = NSButton(title: "Create", target: self, action: #selector(createQuicklinkClicked))
        createBtn.bezelStyle = .rounded
        createBtn.keyEquivalent = "\r"
        createBtn.translatesAutoresizingMaskIntoConstraints = false
        settingsView.addSubview(createBtn)
        createQuicklinkButton = createBtn

        let urlField = NSTextField()
        urlField.placeholderString = "URL (e.g., https://github.com)"
        urlField.font = NSFont.systemFont(ofSize: 14)
        urlField.delegate = self
        urlField.nextKeyView = createBtn
        urlField.translatesAutoresizingMaskIntoConstraints = false
        settingsView.addSubview(urlField)
        quicklinkURLField = urlField

        let nameField = NSTextField()
        nameField.placeholderString = "Name (e.g., GitHub)"
        nameField.font = NSFont.systemFont(ofSize: 14)
        nameField.delegate = self
        nameField.nextKeyView = urlField
        nameField.translatesAutoresizingMaskIntoConstraints = false
        settingsView.addSubview(nameField)
        quicklinkNameField = nameField

        NSLayoutConstraint.activate([
            backBtn.leadingAnchor.constraint(equalTo: settingsView.leadingAnchor, constant: 16),
            backBtn.topAnchor.constraint(equalTo: settingsView.topAnchor, constant: 12),

            titleLabel.centerXAnchor.constraint(equalTo: settingsView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: settingsView.topAnchor, constant: 12),

            nameField.leadingAnchor.constraint(equalTo: settingsView.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: settingsView.trailingAnchor, constant: -16),
            nameField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            nameField.heightAnchor.constraint(equalToConstant: 28),

            urlField.leadingAnchor.constraint(equalTo: settingsView.leadingAnchor, constant: 16),
            urlField.trailingAnchor.constraint(equalTo: settingsView.trailingAnchor, constant: -16),
            urlField.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 8),
            urlField.heightAnchor.constraint(equalToConstant: 28),

            createBtn.centerXAnchor.constraint(equalTo: settingsView.centerXAnchor),
            createBtn.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 16),
        ])

        contentView.addSubview(settingsView)
        settingsContainerView = settingsView

        recalculateKeyViewLoop()

        nameField.window?.initialFirstResponder = nameField
        makeFirstResponder(nameField)
    }

    @objc private func backButtonClicked() {
        exitSettingsMode()
    }

    @objc private func preferencesClicked() {
        close()
        PreferencesWindowController.shared.showWindow()
    }

    @objc private func createQuicklinkClicked() {
        guard let nameField = quicklinkNameField,
              let urlField = quicklinkURLField else { return }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            showAlert(message: "Please enter a name for the quicklink.")
            return
        }

        guard !url.isEmpty else {
            showAlert(message: "Please enter a URL for the quicklink.")
            return
        }

        let quicklink = Quicklink(name: name, url: url)
        guard quicklink.isValidURL else {
            showAlert(message: "Please enter a valid URL (http:// or https://)")
            return
        }

        QuicklinkManager.shared.addQuicklink(quicklink)

        exitSettingsMode()

        if !preservedSearchQuery.isEmpty {
            performSearch(preservedSearchQuery)
        }
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Invalid Input"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func returnToSearchField() {
        resultsTableView.deselectAll(nil)
        isResultsFocused = false
        makeFirstResponder(searchField)

        if let editor = fieldEditor(false, for: searchField) as? NSTextView {
            editor.setSelectedRange(NSRange(location: editor.string.count, length: 0))
        }
    }

    func returnToSearchFieldAndType(_ character: String) {
        resultsTableView.deselectAll(nil)
        isResultsFocused = false
        makeFirstResponder(searchField)

        searchField.stringValue += character
        if let editor = fieldEditor(false, for: searchField) as? NSTextView {
            editor.string = searchField.stringValue
            editor.setSelectedRange(NSRange(location: editor.string.count, length: 0))
        }
        performSearch(searchField.stringValue)
    }

    private var initialWindowTop: CGFloat?

    private func performSearch(_ query: String) {
        guard !isSettingsMode else { return }
        controller.handleQuery(query)
    }

    private func updateSearchResults(_ results: [SearchResult]) {
        guard !isSettingsMode else { return }
        guard !results.elementsEqual(searchResults, by: SearchResult.showsSameRow) || results.isEmpty else {
            searchResults = results
            return
        }

        let previouslySelectedTitle: String? = {
            let row = resultsTableView.selectedRow
            guard row >= 0, row < searchResults.count else { return nil }
            return searchResults[row].title
        }()

        searchResults = results
        resultsTableView.reloadData()

        if searchResults.isEmpty {
            scrollView.isHidden = true
            suggestionsLabel.isHidden = true
            noResultsLabel.isHidden = false
            hintLabel.isHidden = false
            contextualActionBar.isHidden = true

            resizePalette(to: searchFieldHeight + 50)
        } else {
            scrollView.isHidden = false
            suggestionsLabel.isHidden = false
            noResultsLabel.isHidden = true
            hintLabel.isHidden = true
            contextualActionBar.isHidden = false
            updateContextualActionBar()
            scrollView.hasVerticalScroller = searchResults.count > maxVisibleResultRows

            var restoredRow = 0
            if let title = previouslySelectedTitle {
                if let idx = searchResults.firstIndex(where: { $0.title == title }) {
                    restoredRow = idx
                }
            }
            resultsTableView.selectRowIndexes(IndexSet(integer: restoredRow), byExtendingSelection: false)
            resultsTableView.scrollRowToVisible(restoredRow)

            let visibleRows = min(searchResults.count, maxVisibleResultRows)
            let resultsHeight = CGFloat(visibleRows) * rowHeight + resultsContainerVerticalPadding
            resizePalette(to: searchFieldHeight + resultsHeight + contextualBarHeight)
        }
    }

    private func resizePalette(to height: CGFloat) {
        guard let paletteHeight, paletteHeight.constant != height else { return }
        paletteHeight.constant = height
        invalidateShadow()
    }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            handleEscape()
            return
        }

        if event.modifierFlags.contains(.command),
           executeIndexedResultShortcut(forKeyCode: Int(event.keyCode))
        {
            return
        }

        if Int(event.keyCode) == kVK_Return, event.modifierFlags.contains(.command) {
            revealCurrentResult()
            return
        }

        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown, event.modifierFlags.contains(.command) {
            if Int(event.keyCode) == kVK_Return {
                revealCurrentResult()
                return true
            }
            if executeIndexedResultShortcut(forKeyCode: Int(event.keyCode)) {
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func flagsChanged(with event: NSEvent) {
        let optionIsPressed = event.modifierFlags.contains(.option)
        let commandIsPressed = event.modifierFlags.contains(.command)

        if optionIsPressed != isOptionKeyPressed {
            isOptionKeyPressed = optionIsPressed
            updateActionBarVisibility()
        }

        if commandIsPressed != isCommandKeyPressed {
            isCommandKeyPressed = commandIsPressed
            let savedSelection = resultsTableView.selectedRow
            resultsTableView.reloadData()
            if savedSelection >= 0, savedSelection < searchResults.count {
                resultsTableView.selectRowIndexes(IndexSet(integer: savedSelection), byExtendingSelection: false)
            }
        }

        super.flagsChanged(with: event)
    }

    private func updateActionBarVisibility() {
        let shouldShowActionBar = isOptionKeyPressed && !searchResults.isEmpty && !isSettingsMode

        if shouldShowActionBar {
            showActionBar()
        } else {
            hideActionBar()
        }
    }

    private func showActionBar() {
        guard actionBarView == nil else { return }
        guard let contentView = paletteCard else { return }

        let actionBar = createActionBarView()
        actionBarView = actionBar

        contentView.addSubview(actionBar)

        NSLayoutConstraint.activate([
            actionBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            actionBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            actionBar.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            actionBar.heightAnchor.constraint(equalToConstant: 32),
        ])

        originalScrollViewTopConstraint?.isActive = false
        actionBarScrollViewTopConstraint = scrollView.topAnchor.constraint(equalTo: actionBar.bottomAnchor, constant: 4)
        actionBarScrollViewTopConstraint?.isActive = true
    }

    private func hideActionBar() {
        guard actionBarView != nil else { return }

        actionBarScrollViewTopConstraint?.isActive = false
        actionBarScrollViewTopConstraint = nil
        originalScrollViewTopConstraint?.isActive = true

        actionBarView?.removeFromSuperview()
        actionBarView = nil
    }

    private func createActionBarView() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        container.layer?.cornerRadius = 6
        container.translatesAutoresizingMaskIntoConstraints = false

        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.alignment = .centerY
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let convertButton = createActionBarButton(title: "convert")
        stackView.addArrangedSubview(convertButton)

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 16),
        ])
        stackView.addArrangedSubview(separator)

        let translateButton = createActionBarButton(title: "translate")
        stackView.addArrangedSubview(translateButton)

        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])

        return container
    }

    private func createActionBarButton(title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .inline
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    func handleEscape() {
        if isQuickLookOpen {
            closeQuickLook()
        } else if isSettingsMode {
            exitSettingsMode()
        } else {
            close()
        }
    }

    func selectCurrentResult() {
        var selectedRow = resultsTableView.selectedRow

        if selectedRow < 0, !searchResults.isEmpty {
            selectedRow = 0
        }

        guard selectedRow >= 0, selectedRow < searchResults.count else { return }

        executeResult(at: selectedRow)
    }

    func revealCurrentResult() {
        var selectedRow = resultsTableView.selectedRow

        if selectedRow < 0, !searchResults.isEmpty {
            selectedRow = 0
            resultsTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        guard selectedRow >= 0, selectedRow < searchResults.count else {
            return
        }

        let result = searchResults[selectedRow]

        guard result.revealAction != nil else { return }

        if result.category == .process {
            if isDangerMode || result.isKillAttempted {
                print("💀 Window: Triggering FORCE KILL for PID \(result.pid ?? -1)")
                forceQuitCurrentResult()
            } else {
                print("⚠️ Window: Entering DANGER MODE for PID \(result.pid ?? -1)")
                isDangerMode = true
                result.reveal()
            }
        } else {
            result.reveal()
            close()
        }
    }

    private func executeResult(at index: Int) {
        guard index >= 0, index < searchResults.count else { return }
        let result = searchResults[index]

        if result.category == .settings {
            enterSettingsMode()
            return
        }

        result.execute()
        close()
    }

    @discardableResult
    private func executeIndexedResultShortcut(forKeyCode keyCode: Int) -> Bool {
        let index: Int
        switch keyCode {
        case kVK_ANSI_1: index = 0
        case kVK_ANSI_2: index = 1
        case kVK_ANSI_3: index = 2
        case kVK_ANSI_4: index = 3
        case kVK_ANSI_5: index = 4
        case kVK_ANSI_6: index = 5
        case kVK_ANSI_7: index = 6
        case kVK_ANSI_8: index = 7
        case kVK_ANSI_9: index = 8
        default: return false
        }

        guard index < searchResults.count else { return true }
        executeResult(at: index)
        return true
    }

    @discardableResult
    func handleIndexedShortcutFromTable(forKeyCode keyCode: Int) -> Bool {
        executeIndexedResultShortcut(forKeyCode: keyCode)
    }

    override func acceptsPreviewPanelControl(_: QLPreviewPanel!) -> Bool {
        true
    }

    func toggleQuickLook() {
        guard let selectedResult = getSelectedFileResult() else { return }
        guard selectedResult.isFileResult else { return }

        if isQuickLookOpen {
            closeQuickLook()
        } else {
            if Self.showsOnScreen {
                NSApp.activate(ignoringOtherApps: true)
                QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
            }
            isQuickLookOpen = true
            installQuickLookMonitors()
        }
    }

    func closeQuickLook() {
        removeQuickLookMonitors()
        guard isQuickLookOpen else { return }
        if QLPreviewPanel.sharedPreviewPanelExists() {
            QLPreviewPanel.shared().orderOut(nil)
        }
        isQuickLookOpen = false
        guard Self.showsOnScreen else { return }
        makeKeyAndOrderFront(nil)
    }

    private func installQuickLookMonitors() {
        removeQuickLookMonitors()

        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self, isQuickLookOpen else { return }
            let keyCode = Int(event.keyCode)
            if keyCode == kVK_Escape || keyCode == kVK_Space {
                DispatchQueue.main.async { self.closeQuickLook() }
            }
        }

        quickLookGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)

        quickLookLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, isQuickLookOpen else { return event }
            let keyCode = Int(event.keyCode)
            if keyCode == kVK_Escape || keyCode == kVK_Space {
                closeQuickLook()
                return nil
            }
            return event
        }
    }

    private func removeQuickLookMonitors() {
        if let m = quickLookGlobalMonitor { NSEvent.removeMonitor(m)
            quickLookGlobalMonitor = nil
        }
        if let m = quickLookLocalMonitor { NSEvent.removeMonitor(m)
            quickLookLocalMonitor = nil
        }
    }

    private func getSelectedFileResult() -> SearchResult? {
        var selectedRow = resultsTableView.selectedRow

        if selectedRow < 0, !searchResults.isEmpty {
            selectedRow = 0
        }

        guard selectedRow >= 0, selectedRow < searchResults.count else { return nil }

        return searchResults[selectedRow]
    }
}

extension CommandPaletteWindow: NSTextFieldDelegate {
    func controlTextDidChange(_: Notification) {
        performSearch(searchField.stringValue)
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.command) {
            if event.keyCode == UInt16(kVK_Return) {
                revealCurrentResult()
                return true
            }

            if handleIndexedShortcutFromTable(forKeyCode: Int(event.keyCode)) {
                return true
            }
        }

        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            handleEscape()
            return true
        }

        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            selectCurrentResult()
            return true
        }

        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            return false
        }

        if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
            return false
        }

        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            if !searchResults.isEmpty {
                isResultsFocused = true
                makeFirstResponder(resultsTableView)
                resultsTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                resultsTableView.scrollRowToVisible(0)
            }
            return true
        }

        return false
    }
}

extension CommandPaletteWindow: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        searchResults.count
    }

    func tableViewSelectionDidChange(_: Notification) {
        updateContextualActionBar()
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = tableView.makeView(withIdentifier: ResultRowView.reuseIdentifier, owner: nil) as? ResultRowView
            ?? ResultRowView()
        rowView.identifier = ResultRowView.reuseIdentifier

        if row >= 0, row < searchResults.count {
            let result = searchResults[row]
            rowView.isKillAttempted = result.isKillAttempted
        }

        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let result = searchResults[row]

        if result.category == .file, let filePath = result.filePath {
            let cell = tableView.makeView(withIdentifier: FileResultCellView.reuseIdentifier, owner: nil) as? FileResultCellView
                ?? FileResultCellView()
            cell.configure(with: result, path: filePath, row: row, showsIndex: isCommandKeyPressed)
            return cell
        }

        let cell = tableView.makeView(withIdentifier: ResultCellView.reuseIdentifier, owner: nil) as? ResultCellView
            ?? ResultCellView()
        cell.configure(with: result, row: row, showsIndex: isCommandKeyPressed)
        return cell
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        rowHeight
    }
}

extension CommandPaletteWindow {
    var visiblePaletteFrame: NSRect {
        guard let paletteCard else { return .zero }
        return convertToScreen(paletteCard.convert(paletteCard.bounds, to: nil))
    }

    var selectedIndex: Int {
        resultsTableView.selectedRow
    }

    var isSearchFieldFirstResponder: Bool {
        !isResultsFocused
    }

    var isResultsTableFirstResponder: Bool {
        isResultsFocused
    }

    var searchFieldText: String {
        searchField.stringValue
    }

    var isSearchFieldTextSelected: Bool {
        guard let fieldEditor = fieldEditor(false, for: searchField) else { return false }
        return fieldEditor.selectedRange.length > 0
    }

    func setSearchFieldTextForTesting(_ text: String) {
        searchField.stringValue = text
        if let fieldEditor = fieldEditor(false, for: searchField) {
            fieldEditor.string = text
        }
    }

    func updateResultsForTesting(_ results: [SearchResult]) {
        searchResults = results
        resultsTableView.reloadData()

        if !results.isEmpty {
            resultsTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            scrollView.isHidden = false
        } else {
            scrollView.isHidden = true
        }

        updateActionBarVisibility()
    }

    func clearSelectionForTesting() {
        resultsTableView.deselectAll(nil)
    }

    func setSelectedIndexForTesting(_ index: Int) {
        guard index >= 0, index < searchResults.count else { return }
        resultsTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }

    private static let simulatedCharacters: [Int: String] = [
        kVK_Return: "\r", kVK_Escape: "\u{1B}", kVK_Space: " ", kVK_Tab: "\t",
        kVK_DownArrow: String(Character(UnicodeScalar(NSDownArrowFunctionKey)!)),
        kVK_UpArrow: String(Character(UnicodeScalar(NSUpArrowFunctionKey)!)),
        kVK_ANSI_A: "a", kVK_ANSI_C: "c", kVK_ANSI_V: "v", kVK_ANSI_X: "x",
        kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4", kVK_ANSI_5: "5",
        kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
    ]

    func simulateKeyPress(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) {
        let characters = Self.simulatedCharacters[Int(keyCode)] ?? ""
        sendSimulatedKey(keyCode: keyCode, characters: characters, modifiers: modifiers)
    }

    func simulateCharacterKeyPress(character: String) {
        sendSimulatedKey(keyCode: 0, characters: character, modifiers: [])
    }

    private func sendSimulatedKey(keyCode: UInt16, characters: String, modifiers: NSEvent.ModifierFlags) {
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        ) else { return }
        if modifiers.contains(.command), performKeyEquivalent(with: event) || performMenuAction(for: event) { return }
        sendEvent(event)
    }

    private func performMenuAction(for event: NSEvent) -> Bool {
        let key = event.charactersIgnoringModifiers ?? ""
        let item = NSApplication.shared.mainMenu?.items.compactMap(\.submenu).flatMap(\.items)
            .first { $0.keyEquivalent == key && $0.keyEquivalentModifierMask == .command }
        guard let action = item?.action else { return false }
        return NSApplication.shared.sendAction(action, to: firstResponder, from: item)
    }

    var isQuickLookRequested: Bool {
        isQuickLookOpen
    }

    var isQuickLookClosing: Bool {
        !isQuickLookOpen && getSelectedFileResult()?.isFileResult == true
    }

    func resetQuickLookRequestFlag() {
    }

    var selectedFileURL: URL? {
        getSelectedFileResult()?.fileURL
    }

    func setHoverOnRowsForTesting(_ rows: [Int]) {
        resultsTableView.setHoverOnRowsForTesting(rows)
    }

    func hasAnyHoveredRowsForTesting() -> Bool {
        resultsTableView.hasAnyHoveredRowsForTesting()
    }

    func clearHoverOnAllRowsForTesting() {
        resultsTableView.clearHover()
    }

    var isActionBarVisible: Bool {
        actionBarView != nil && actionBarView?.superview != nil
    }

    var actionBarOptions: [String] {
        actionBarOptionLabels
    }

    func simulateModifierFlagsChange(modifiers: NSEvent.ModifierFlags) {
        let optionIsPressed = modifiers.contains(.option)
        if optionIsPressed != isOptionKeyPressed {
            isOptionKeyPressed = optionIsPressed
            updateActionBarVisibility()
        }
    }
}

extension CommandPaletteWindow: QLPreviewPanelDataSource {
    func numberOfPreviewItems(in _: QLPreviewPanel!) -> Int {
        getSelectedFileResult()?.isFileResult == true ? 1 : 0
    }

    func previewPanel(_: QLPreviewPanel!, previewItemAt _: Int) -> (any QLPreviewItem)! {
        guard let result = getSelectedFileResult(), result.isFileResult else {
            return nil
        }
        return result.fileURL as QLPreviewItem?
    }
}

extension CommandPaletteWindow: QLPreviewPanelDelegate {
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }

    func previewPanel(_: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown else { return false }

        let keyCode = Int(event.keyCode)
        if keyCode == kVK_Escape || keyCode == kVK_Space {
            closeQuickLook()
            return true
        }

        return false
    }
}
