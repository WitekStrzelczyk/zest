import AppKit
import Carbon
import Quartz

final class PaletteBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        let gradient = NSGradient(
            colors: [
                AppStyle.Palette.backgroundTop,
                AppStyle.Palette.backgroundBottom,
            ]
        )
        gradient?.draw(in: bounds, angle: -90)
    }
}

// MARK: - Row View with Custom Highlight Colors

/// Row view using `.inset` table style for layout (rounded rects)
/// but with custom subtle colors instead of the default blue accent.
/// Supports "danger mode" - red background with border to indicate kill action.
final class ResultRowView: NSTableRowView {
    private let horizontalInset: CGFloat = 6
    private let verticalInset: CGFloat = 1

    var isHovered: Bool = false {
        didSet {
            if oldValue != isHovered { needsDisplay = true }
        }
    }

    /// When true, shows red background and border to indicate dangerous action (e.g., force quit)
    var isDangerMode: Bool = false {
        didSet {
            if oldValue != isDangerMode { needsDisplay = true }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isHovered = false
        isDangerMode = false
    }

    override func drawSelection(in dirtyRect: NSRect) {
        if isDangerMode {
            // Danger mode: reddish background with red border
            NSColor.systemRed.withAlphaComponent(0.15).setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: horizontalInset, dy: verticalInset), xRadius: 6, yRadius: 6)
            path.fill()

            // Red border
            NSColor.systemRed.withAlphaComponent(0.6).setStroke()
            path.lineWidth = 1.5
            path.stroke()
        } else {
            AppStyle.Palette.rowSelectedFill.setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: horizontalInset, dy: verticalInset), xRadius: 6, yRadius: 6)
            path.fill()
            AppStyle.Palette.rowSelectedStroke.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if isDangerMode {
            // Danger mode background even when not selected (for hover state)
            NSColor.systemRed.withAlphaComponent(0.1).setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: horizontalInset, dy: verticalInset), xRadius: 6, yRadius: 6)
            path.fill()

            // Red border
            NSColor.systemRed.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 1.5
            path.stroke()
        } else if !isSelected, isHovered {
            AppStyle.Palette.rowHoverFill.setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: horizontalInset, dy: verticalInset), xRadius: 6, yRadius: 6)
            path.fill()
        }
        super.draw(dirtyRect)
    }
}

// MARK: - Fading Scroll View

/// Scroll view that fades content at the top and bottom edges when scrollable.
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

// MARK: - Custom Results Table View

/// Custom NSTableView that handles keyboard navigation and forwards character keys to search field
final class ResultsTableView: NSTableView {
    weak var commandPalette: CommandPaletteWindow?

    override var acceptsFirstResponder: Bool {
        true
    }

    /// Clear all hover states from all visible rows
    func clearHover() {
        // Method 1: Clear via enumerateAvailableRowViews
        enumerateAvailableRowViews { rowView, _ in
            if let resultRowView = rowView as? ResultRowView {
                resultRowView.isHovered = false
            }
        }

        // Method 2: Also iterate through all possible rows and clear if view exists
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
            // Clear danger mode before handling escape
            palette.clearDangerMode()
            palette.handleEscape()

        case kVK_Return:
            if event.modifierFlags.contains(.command) {
                // Cmd+Enter: Two-step force quit for processes
                // First press: Enter danger mode (red state)
                // Second press (already in danger mode): Force quit
                palette.revealCurrentResult()
            } else if palette.isDangerMode {
                // Enter in danger mode: Force quit the process
                palette.forceQuitCurrentResult()
            } else {
                // Enter: Select result
                palette.selectCurrentResult()
            }

        case kVK_UpArrow:
            // Clear danger mode when navigating
            palette.clearDangerMode()
            clearHover()
            if selectedRow <= 0 {
                palette.returnToSearchField()
            } else {
                super.keyDown(with: event)
            }

        case kVK_DownArrow:
            // Clear danger mode when navigating
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
                // Clear danger mode when typing
                palette.clearDangerMode()
                palette.returnToSearchFieldAndType(characters)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    // MARK: - Mouse Click

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)

        if clickedRow >= 0, clickedRow < numberOfRows {
            selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            commandPalette?.selectCurrentResult()
        }
    }

    // MARK: - Mouse Tracking

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)

        // Clear all hovers first, then set hover on the row under mouse
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

        // Ensure we have tracking for mouse movements
        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .mouseEnteredAndExited,
            .activeInActiveApp,
            .inVisibleRect,
        ]

        // Remove existing custom tracking areas and add new one
        for area in trackingAreas {
            if area.owner === self {
                removeTrackingArea(area)
            }
        }

        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    // MARK: - Test Helpers

    /// Set hover state on multiple rows for testing
    func setHoverOnRowsForTesting(_ rows: [Int]) {
        for row in rows {
            if row >= 0, row < numberOfRows {
                if let rowView = rowView(atRow: row, makeIfNecessary: true) as? ResultRowView {
                    rowView.isHovered = true
                }
            }
        }
    }

    /// Check if any rows have hover state for testing
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

// MARK: - Command Palette Window

final class CommandPaletteWindow: NSPanel {
    /// Exposed for testing
    private(set) var searchField: NSTextField!
    private var searchIcon: NSImageView!
    private var resultsTableView: ResultsTableView!
    private var scrollView: NSScrollView!
    private(set) var hintLabel: NSTextField!
    private var suggestionsLabel: NSTextField!
    private var noResultsLabel: NSTextField!
    
    /// Stats label shown on hover - displays search timing metrics
    private var statsLabel: NSTextField!
    /// Container view for search area (used for hover detection)
    private var searchContainerView: NSView!
    /// Tracking area for hover detection
    private var hoverTrackingArea: NSTrackingArea?
    /// Last search trace for displaying stats
    private var lastSearchTrace: SearchSpan?
    /// Whether stats are enabled - enabled by default, can be disabled via preference
    private var statsEnabled: Bool {
        // Default to true if not explicitly disabled
        !UserDefaults.standard.bool(forKey: "hideSearchStats")
    }
    
    /// Exposed for testing
    private(set) var searchResults: [SearchResult] = []

    /// Tracks whether focus is on results table (vs search field)
    /// This is used because makeFirstResponder only works when window is key
    private var isResultsFocused: Bool = false

    /// Tracks whether Quick Look preview is currently showing
    private var isQuickLookOpen: Bool = false

    /// Tracks whether Option key is currently pressed
    private var isOptionKeyPressed: Bool = false
    /// Tracks whether Command key is currently pressed (index shortcut mode)
    private var isCommandKeyPressed: Bool = false

    /// Action bar view shown when Option key is held
    private var actionBarView: NSView?

    /// Contextual action bar at bottom - shows available actions for selected item
    private var contextualActionBar: NSView!

    /// Label in contextual bar showing keyboard shortcuts
    private var contextualActionLabel: NSTextField!
    private var contextualFooterLeftLabel: NSTextField!
    private var preferencesIconView: NSImageView!
    private var preferencesLabel: NSTextField!
    private var storeIconView: NSImageView!
    private var storeLabel: NSTextField!

    /// Action bar options available (for testing)
    private let actionBarOptionLabels: [String] = ["convert", "translate"]

    /// Height of the contextual action bar
    private let contextualBarHeight: CGFloat = 36

    /// Constraint for scroll view when action bar is visible
    private var actionBarScrollViewTopConstraint: NSLayoutConstraint?

    /// Original scroll view top constraint (to restore when action bar hides)
    private var originalScrollViewTopConstraint: NSLayoutConstraint?

    /// Tracks whether we're in settings mode (quicklink creation)
    /// Exposed for testing
    private(set) var isSettingsMode: Bool = false {
        didSet {
            if isSettingsMode != oldValue {
                handleModeChange()
            }
        }
    }

    /// Tracks whether "danger mode" is active for the selected process row
    /// When true, shows red background/border, Enter triggers force quit instead of normal action
    private(set) var isDangerMode: Bool = false {
        didSet {
            if isDangerMode != oldValue {
                updateDangerModeAppearance()
            }
        }
    }

    /// Tracks whether LLM tool calling mode is active (when query starts with =)
    private(set) var isLLMMode: Bool = false
    
    /// Global headless state store
    private let stateStore = CommandPaletteStateStore.shared
    private let controller = CommandPaletteController.shared
    private var stateObserver: NSObjectProtocol?

    /// Centralized mode handling - called whenever mode changes
    private func handleModeChange() {
        if isSettingsMode {
            // ENTERING SETTINGS MODE
            // 1. Cancel in-progress search engine search
            SearchEngine.shared.cancelCurrentSearch()
            
            // 2. Hide search and results UI
            searchField.isHidden = true
            searchIcon.isHidden = true
            scrollView.isHidden = true
            noResultsLabel.isHidden = true
            hintLabel.isHidden = true
            
            // 3. Show settings UI
            showSettingsUI()
        } else {
            // EXITING SETTINGS MODE (entering normal mode)
            // 1. Hide settings UI
            settingsContainerView?.isHidden = true
            settingsContainerView?.removeFromSuperview()
            settingsContainerView = nil
            
            // 2. Show search UI
            searchField.isHidden = false
            searchIcon.isHidden = false
            searchField.stringValue = preservedSearchQuery
            hintLabel.isHidden = false
            
            // 3. Show results if we have any
            if !searchResults.isEmpty {
                scrollView.isHidden = false
            }
            
            // 4. Restore window size
            if let topY = initialWindowTop {
                let newHeight = searchFieldHeight + hintHeight
                let newY = topY - newHeight
                let currentFrame = frame
                animateFrame(NSRect(x: currentFrame.origin.x, y: newY, width: windowWidth, height: newHeight))
            }
            
            // 5. Re-run search with preserved query
            if !preservedSearchQuery.isEmpty {
                performSearch(preservedSearchQuery)
            }
            
            // 6. Focus on search field
            makeFirstResponder(searchField)
        }
    }

    // MARK: - Danger Mode (Tab key for processes)

    /// Clear danger mode (called on navigation, typing, escape)
    func clearDangerMode() {
        guard isDangerMode else { return }
        isDangerMode = false
        updateDangerModeAppearance()
    }

    /// Update the visual appearance of the selected row to show/hide danger mode
    private func updateDangerModeAppearance() {
        let selectedRow = resultsTableView.selectedRow
        guard selectedRow >= 0 else { return }

        // Get the row view and update its danger mode state
        if let rowView = resultsTableView.rowView(atRow: selectedRow, makeIfNecessary: false) as? ResultRowView {
            rowView.isDangerMode = isDangerMode
            rowView.needsDisplay = true
        }

        // Update contextual action bar to reflect danger mode state
        updateContextualActionBar()
    }

    /// Force quit the currently selected process (triggered by Enter in danger mode)
    func forceQuitCurrentResult() {
        var selectedRow = resultsTableView.selectedRow

        // If no selection but results exist, default to first result
        if selectedRow < 0, !searchResults.isEmpty {
            selectedRow = 0
        }

        guard selectedRow >= 0, selectedRow < searchResults.count else {
            close()
            return
        }

        let result = searchResults[selectedRow]

        // Only force quit process items
        guard result.category == .process else {
            close()
            return
        }

        // Clear danger mode first
        clearDangerMode()

        // Trigger the reveal action (which is force quit for processes)
        result.reveal()

        // Refresh the results to show the process is gone
        // Small delay to let the process terminate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshProcessResults()
        }
    }

    /// Refresh process list after a force quit
    private func refreshProcessResults() {
        // Re-run the current search to refresh process list
        let currentQuery = searchField.stringValue
        performSearch(currentQuery)
    }

    // MARK: - Contextual Action Bar

    /// Create the contextual action bar that shows available actions for selected item
    private func createContextualActionBar() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = AppStyle.Palette.footerBackground.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        // Add subtle top border
        let borderView = NSView()
        borderView.wantsLayer = true
        borderView.layer?.backgroundColor = AppStyle.Palette.footerBorder.cgColor
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
        preferencesIconView = NSImageView(image: NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Preferences") ?? NSImage())
        preferencesIconView.contentTintColor = AppStyle.Palette.secondaryText
        preferencesIconView.translatesAutoresizingMaskIntoConstraints = false
        preferencesLabel = NSTextField(labelWithString: "Preferences")
        preferencesLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        preferencesLabel.textColor = AppStyle.Palette.secondaryText
        preferencesLabel.translatesAutoresizingMaskIntoConstraints = false
        prefStack.addArrangedSubview(preferencesIconView)
        prefStack.addArrangedSubview(preferencesLabel)

        let storeStack = NSStackView()
        storeStack.orientation = .horizontal
        storeStack.alignment = .centerY
        storeStack.spacing = 6
        storeStack.translatesAutoresizingMaskIntoConstraints = false
        storeIconView = NSImageView(image: NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: "Store") ?? NSImage())
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

        // Right footer label showing keyboard shortcuts
        contextualActionLabel = NSTextField(labelWithString: "")
        contextualActionLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        contextualActionLabel.textColor = AppStyle.Palette.secondaryText
        contextualActionLabel.alignment = .right
        contextualActionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contextualActionLabel)

        NSLayoutConstraint.activate([
            // Top border
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

            contextualActionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leftStack.trailingAnchor, constant: 12),
            contextualActionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            contextualActionLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    /// Update the contextual action bar based on the currently selected item
    func updateContextualActionBar() {
        let selectedRow = resultsTableView.selectedRow

        // No selection or out of bounds - show default hints
        guard selectedRow >= 0, selectedRow < searchResults.count else {
            contextualActionLabel.stringValue = "⏎ Open   |   ⌘⏎ Actions"
            return
        }

        let result = searchResults[selectedRow]

        // Build contextual hints based on category - use | as separator
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

    /// Quicklink creation UI elements
    private var settingsContainerView: NSView?
    private var quicklinkNameField: NSTextField?
    private var quicklinkURLField: NSTextField?
    private var createQuicklinkButton: NSButton?
    private var backButton: NSButton?

    /// Preserved search query when entering settings mode
    private var preservedSearchQuery: String = ""

    /// Global event monitor to catch keys when app isn't frontmost (e.g. launched from terminal)
    private var quickLookGlobalMonitor: Any?
    /// Local event monitor for when app IS frontmost
    private var quickLookLocalMonitor: Any?


    // Layout constants
    private let windowWidth: CGFloat = 720
    private let searchFieldHeight: CGFloat = 56
    private let rowHeight: CGFloat = 52
    private let hintHeight: CGFloat = 24
    private let emptyStateHeight: CGFloat = 78
    private let maxVisibleResultRows: Int = 6
    private let resultsContainerVerticalPadding: CGFloat = 20

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
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: searchFieldHeight + hintHeight + contextualBarHeight),
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
                  let state = notification.userInfo?[commandPaletteStateUserInfoKey] as? CommandPaletteState else { return }
            self.render(state: state)
        }
    }
    
    private func render(state: CommandPaletteState) {
        guard !isSettingsMode else { return }
        isLLMMode = state.isLLMMode
        
        if state.query.isEmpty {
            searchResults = []
            resultsTableView.reloadData()
            scrollView.isHidden = true
            noResultsLabel.isHidden = true
            hintLabel.isHidden = true
            contextualActionBar.isHidden = true
            if let topY = initialWindowTop {
                let currentFrame = frame
                let newY = topY - emptyStateHeight
                animateFrame(NSRect(x: currentFrame.origin.x, y: newY, width: windowWidth, height: emptyStateHeight))
            }
            return
        }
        
        guard let topY = initialWindowTop, let screen = NSScreen.main else { return }
        updateSearchResults(state.results, topY: topY, screen: screen)
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
        // Allow panel to become key for text input (needed for Cmd+key shortcuts)
        becomesKeyOnlyIfNeeded = false
    }

    private func makeKeycapView(text: String, font: NSFont) -> (container: NSView, label: NSTextField) {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = AppStyle.KeyboardBadge.cornerRadius
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = AppStyle.KeyboardBadge.background.cgColor
        container.layer?.borderColor = AppStyle.KeyboardBadge.border.cgColor
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

    private func setupUI() {
        let contentView = PaletteBackgroundView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: searchFieldHeight + hintHeight + contextualBarHeight))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 12
        contentView.layer?.masksToBounds = true

        let searchBarContainer = NSView()
        searchBarContainer.wantsLayer = true
        searchBarContainer.layer?.cornerRadius = 10
        searchBarContainer.layer?.masksToBounds = true
        searchBarContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        searchBarContainer.layer?.borderColor = AppStyle.Palette.searchBarBorder.cgColor
        searchBarContainer.layer?.borderWidth = 1
        searchBarContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchBarContainer)

        // Search icon
        searchIcon = NSImageView()
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        searchIcon.contentTintColor = AppStyle.Palette.accentText
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchBarContainer.addSubview(searchIcon)

        // Search field
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

        let (escBadge, _) = makeKeycapView(text: "ESC", font: AppStyle.KeyboardBadge.escFont)
        searchBarContainer.addSubview(escBadge)

        // Hint label at bottom
        hintLabel = NSTextField(labelWithString: "\u{2318}\u{21A9} Reveal  \u{21B5} Select  Space Preview  \u{2191}\u{2193} Navigate  Esc Close")
        hintLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        hintLabel.textColor = AppStyle.Palette.tertiaryText
        hintLabel.alignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hintLabel)
        
        suggestionsLabel = NSTextField(labelWithString: "SUGGESTIONS")
        suggestionsLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        suggestionsLabel.textColor = AppStyle.Palette.mutedText
        suggestionsLabel.translatesAutoresizingMaskIntoConstraints = false
        suggestionsLabel.isHidden = true
        contentView.addSubview(suggestionsLabel)

        // Contextual action bar - shows available actions for selected item
        contextualActionBar = createContextualActionBar()
        contentView.addSubview(contextualActionBar)
        
        // Stats label - shows search timing on hover
        statsLabel = NSTextField(labelWithString: "")
        statsLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        statsLabel.textColor = AppStyle.Palette.tertiaryText
        statsLabel.alignment = .right
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.isHidden = true
        statsLabel.toolTip = "Search performance metrics"
        contentView.addSubview(statsLabel)

        // Results table -- .inset style gives native rounded selection (like Spotlight)
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

        // No results label
        noResultsLabel = NSTextField(labelWithString: "No results found")
        noResultsLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        noResultsLabel.textColor = .secondaryLabelColor
        noResultsLabel.alignment = .center
        noResultsLabel.isHidden = true
        noResultsLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(noResultsLabel)

        // Constraints
        NSLayoutConstraint.activate([
            searchBarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchBarContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            searchBarContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            searchBarContainer.heightAnchor.constraint(equalToConstant: 40),

            // Search icon in search bar
            searchIcon.leadingAnchor.constraint(equalTo: searchBarContainer.leadingAnchor, constant: 12),
            searchIcon.centerYAnchor.constraint(equalTo: searchBarContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 20),
            searchIcon.heightAnchor.constraint(equalToConstant: 20),
            
            escBadge.trailingAnchor.constraint(equalTo: searchBarContainer.trailingAnchor, constant: -10),
            escBadge.centerYAnchor.constraint(equalTo: searchBarContainer.centerYAnchor),
            escBadge.widthAnchor.constraint(equalToConstant: AppStyle.KeyboardBadge.escWidth),
            escBadge.heightAnchor.constraint(equalToConstant: AppStyle.KeyboardBadge.escHeight),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: escBadge.leadingAnchor, constant: -10),
            searchField.centerYAnchor.constraint(equalTo: searchBarContainer.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 24),
        ])
        
        // Store the original scroll view top constraint (needed for action bar management)
        originalScrollViewTopConstraint = scrollView.topAnchor.constraint(equalTo: searchBarContainer.bottomAnchor, constant: 8)
        originalScrollViewTopConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contextualActionBar.topAnchor, constant: 0),
            scrollView.topAnchor.constraint(equalTo: suggestionsLabel.bottomAnchor, constant: 8),

            suggestionsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            suggestionsLabel.topAnchor.constraint(equalTo: searchBarContainer.bottomAnchor, constant: 10),

            // No results - centered in scroll area
            noResultsLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            noResultsLabel.topAnchor.constraint(equalTo: suggestionsLabel.bottomAnchor, constant: 20),

            // Contextual action bar - at very bottom
            contextualActionBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contextualActionBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contextualActionBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            contextualActionBar.heightAnchor.constraint(equalToConstant: contextualBarHeight),

            // Hint label - hidden by default, shown when no results
            hintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: contextualActionBar.topAnchor, constant: -6),
            hintLabel.heightAnchor.constraint(equalToConstant: hintHeight),

            // Stats label - right side, above contextual bar
            statsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            statsLabel.bottomAnchor.constraint(equalTo: contextualActionBar.topAnchor, constant: -4),
            statsLabel.heightAnchor.constraint(equalToConstant: 14),
        ])
        
        // Setup hover tracking for the entire content view
        setupHoverTracking(in: contentView)

        self.contentView = contentView
    }
    
    // MARK: - Hover Tracking for Stats
    
    private func setupHoverTracking(in view: NSView) {
        // Remove old tracking area if exists
        if let oldTracking = hoverTrackingArea {
            view.removeTrackingArea(oldTracking)
        }
        
        // Create new tracking area for the entire view
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
        // Show stats label on hover if we have stats and they're enabled
        if statsEnabled, let trace = lastSearchTrace {
            updateStatsLabel(with: trace)
            statsLabel.isHidden = false
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // Hide stats label when mouse leaves
        statsLabel.isHidden = true
    }
    
    /// Update the stats label with trace information
    private func updateStatsLabel(with trace: SearchSpan) {
        // Build a concise stats string
        var stats: [String] = []

        // Total time with precision
        let totalMs = trace.durationMsPrecise
        stats.append(String(format: "⏱%.1fms", totalMs))

        // Add timing for each major category
        for child in trace.children {
            let name = child.operationName
            let ms = child.durationMsPrecise
            let resultsCount = child.tags["results"] as? Int

            let shortName: String
            switch name {
            case "calculator": shortName = "calc"
            case "applications": shortName = "apps"
            case "user_commands": shortName = "cmd"
            case "contacts": shortName = "👤"
            case "clipboard": shortName = "📋"
            case "files": shortName = "📁"
            case "global_commands": shortName = "⌨️"
            case "toggles": shortName = "tgl"
            case "quicklinks": shortName = "🔗"
            case "deduplicate_sort": shortName = "sort"
            case "settings": shortName = "⚙️"
            case "unit_conversion": shortName = "conv"
            default: shortName = name.prefix(4).lowercased()
            }

            // Show category with timing and result count
            if let count = resultsCount, count > 0 {
                stats.append("\(shortName):\(String(format: "%.1f", ms))ms(\(count))")
            } else if ms > 0.1 {
                stats.append("\(shortName):\(String(format: "%.1f", ms))ms")
            }
        }

        statsLabel.stringValue = stats.joined(separator: " | ")
    }

    /// Store the last search trace and update stats display
    func setSearchTrace(_ trace: SearchSpan) {
        lastSearchTrace = trace

        // Show stats immediately if enabled
        if statsEnabled {
            updateStatsLabel(with: trace)
            statsLabel.isHidden = false
        }
    }

    // MARK: - Show/Hide

    func show(previousApp: NSRunningApplication? = nil) {
        searchField.stringValue = ""
        searchResults = []
        resultsTableView.reloadData()
        scrollView.isHidden = true
        noResultsLabel.isHidden = true
        hintLabel.isHidden = true
        suggestionsLabel.isHidden = true
        contextualActionBar.isHidden = true // Hide contextual bar when empty
        isResultsFocused = false // Reset to search field focus
        isOptionKeyPressed = false // Reset Option key state
        isCommandKeyPressed = false
        hideActionBar() // Ensure action bar is hidden
        isDangerMode = false // Reset danger mode
        isLLMMode = false // Reset LLM mode
        stateStore.clearIntent()

        // Position window - store top position for resize from bottom (top fixed)
        // Initial window doesn't include contextual bar (only shows when results exist)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowX = screenFrame.midX - windowWidth / 2
            let windowY = screenFrame.midY + 120
            let frame = NSRect(x: windowX, y: windowY, width: windowWidth, height: emptyStateHeight)
            setFrame(frame, display: true)
            initialWindowTop = frame.maxY
        }

        // Menu bar apps (LSUIElement=true) need this to become key window
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    override func close() {
        removeQuickLookMonitors()
        if isQuickLookOpen, QLPreviewPanel.sharedPreviewPanelExists() {
            QLPreviewPanel.shared().orderOut(nil)
            isQuickLookOpen = false
        }
        // Clear search results to ensure clean state on reopen
        searchResults = []
        resultsTableView.reloadData()
        suggestionsLabel.isHidden = true
        // Reset settings mode when closing
        isSettingsMode = false
        // Reset LLM mode when closing
        isLLMMode = false
        stateStore.clearIntent()
        // Reset Option key state and hide action bar
        isOptionKeyPressed = false
        isCommandKeyPressed = false
        hideActionBar()
        orderOut(nil)
    }

    // MARK: - Settings Mode (Quicklink Creation)

    /// Enter settings mode to create a new quicklink
    /// All mode switching logic is centralized in handleModeChange() via isSettingsMode.didSet
    func enterSettingsMode() {
        guard !isSettingsMode else { return }
        
        // Preserve current search query before switching mode
        preservedSearchQuery = searchField.stringValue
        
        // Clear results when entering settings mode - prevents stale results from showing
        searchResults = []
        resultsTableView.reloadData()
        
        // Switch mode - handleModeChange() will do all the UI work
        isSettingsMode = true
    }

    /// Exit settings mode and return to normal search
    func exitSettingsMode() {
        guard isSettingsMode else { return }
        
        // Clear results when exiting to start fresh
        searchResults = []
        resultsTableView.reloadData()
        
        // Switch mode - handleModeChange() will do all the UI work
        isSettingsMode = false
    }

    private func showSettingsUI() {
        guard let contentView = contentView else { return }
        
        // Compact settings panel height
        let settingsHeight: CGFloat = 180
        
        // Step 1: Resize window FIRST - make it taller while keeping same Y position
        var currentFrame = frame
        currentFrame.size.height = settingsHeight
        // Adjust origin to keep bottom in same place (grow upward)
        currentFrame.origin.y -= (settingsHeight - frame.height)
        setFrame(currentFrame, display: true, animate: true)
        
        // Step 2: NOW create settings view with the NEW window bounds
        // Use window frame, not contentView.bounds (which hasn't resized yet)
        let settingsView = NSView(frame: NSRect(x: 0, y: 0, width: currentFrame.width, height: currentFrame.height))
        settingsView.wantsLayer = true
        
        // Back button
        let backBtn = NSButton(title: "← Back", target: self, action: #selector(backButtonClicked))
        backBtn.bezelStyle = .inline
        backBtn.isBordered = false
        backBtn.contentTintColor = .secondaryLabelColor
        backBtn.font = NSFont.systemFont(ofSize: 13)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        settingsView.addSubview(backBtn)
        self.backButton = backBtn
        
        // Compact title
        let titleLabel = NSTextField(labelWithString: "Add Quicklink")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        settingsView.addSubview(titleLabel)
        
        // Create button first (needed for nextKeyView)
        let createBtn = NSButton(title: "Create", target: self, action: #selector(createQuicklinkClicked))
        createBtn.bezelStyle = .rounded
        createBtn.keyEquivalent = "\r"
        createBtn.translatesAutoresizingMaskIntoConstraints = false
        settingsView.addSubview(createBtn)
        self.createQuicklinkButton = createBtn
        
        // URL text field (needs to be before nameField for nextKeyView)
        let urlField = NSTextField()
        urlField.placeholderString = "URL (e.g., https://github.com)"
        urlField.font = NSFont.systemFont(ofSize: 14)
        urlField.delegate = self
        urlField.nextKeyView = createBtn  // Tab from URL goes to Create button
        urlField.translatesAutoresizingMaskIntoConstraints = false
        settingsView.addSubview(urlField)
        self.quicklinkURLField = urlField
        
        // Name text field (first responder)
        let nameField = NSTextField()
        nameField.placeholderString = "Name (e.g., GitHub)"
        nameField.font = NSFont.systemFont(ofSize: 14)
        nameField.delegate = self
        nameField.nextKeyView = urlField  // Tab from name goes to URL
        nameField.translatesAutoresizingMaskIntoConstraints = false
        settingsView.addSubview(nameField)
        self.quicklinkNameField = nameField
        
        // Constraints - compact layout
        NSLayoutConstraint.activate([
            // Back button - top left
            backBtn.leadingAnchor.constraint(equalTo: settingsView.leadingAnchor, constant: 16),
            backBtn.topAnchor.constraint(equalTo: settingsView.topAnchor, constant: 12),
            
            // Title - centered
            titleLabel.centerXAnchor.constraint(equalTo: settingsView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: settingsView.topAnchor, constant: 12),
            
            // Name field
            nameField.leadingAnchor.constraint(equalTo: settingsView.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: settingsView.trailingAnchor, constant: -16),
            nameField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            nameField.heightAnchor.constraint(equalToConstant: 28),
            
            // URL field
            urlField.leadingAnchor.constraint(equalTo: settingsView.leadingAnchor, constant: 16),
            urlField.trailingAnchor.constraint(equalTo: settingsView.trailingAnchor, constant: -16),
            urlField.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 8),
            urlField.heightAnchor.constraint(equalToConstant: 28),
            
            // Create button - center below URL field
            createBtn.centerXAnchor.constraint(equalTo: settingsView.centerXAnchor),
            createBtn.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 16),
        ])
        
        contentView.addSubview(settingsView)
        settingsContainerView = settingsView
        
        // KEY: Tell AppKit to rebuild key view loop for the new fields
        // This enables proper Tab navigation between form fields
        recalculateKeyViewLoop()
        
        // Focus on name field and make it the first in key loop
        nameField.window?.initialFirstResponder = nameField
        makeFirstResponder(nameField)
    }
    
    @objc private func backButtonClicked() {
        exitSettingsMode()
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
        
        // Validate URL
        let quicklink = Quicklink(name: name, url: url)
        guard quicklink.isValidURL else {
            showAlert(message: "Please enter a valid URL (http:// or https://)")
            return
        }
        
        // Add quicklink
        QuicklinkManager.shared.addQuicklink(quicklink)
        
        // Exit settings mode
        exitSettingsMode()
        
        // Re-run search to show new quicklink
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

    // MARK: - Focus Management

    /// Return focus to search field from results table
    func returnToSearchField() {
        resultsTableView.deselectAll(nil)
        isResultsFocused = false
        makeFirstResponder(searchField)

        // Place cursor at end instead of selecting all
        if let editor = fieldEditor(false, for: searchField) as? NSTextView {
            editor.setSelectedRange(NSRange(location: editor.string.count, length: 0))
        }
    }

    /// Return focus to search field and type a character
    func returnToSearchFieldAndType(_ character: String) {
        resultsTableView.deselectAll(nil)
        isResultsFocused = false
        makeFirstResponder(searchField)

        // Append the character and place cursor at end
        searchField.stringValue += character
        if let editor = fieldEditor(false, for: searchField) as? NSTextView {
            editor.string = searchField.stringValue
            editor.setSelectedRange(NSRange(location: editor.string.count, length: 0))
        }
        performSearch(searchField.stringValue)
    }

    // MARK: - Search

    /// Store initial top position to resize from bottom (top stays fixed)
    private var initialWindowTop: CGFloat?

    /// Perform search - only runs in normal mode
    private func performSearch(_ query: String) {
        guard !isSettingsMode else { return }
        controller.handleQuery(query)
    }

    private func updateSearchResults(_ results: [SearchResult], topY: CGFloat, screen _: NSScreen) {
        // Don't update results when in settings mode
        guard !isSettingsMode else { return }
        
        let currentFrame = frame

        // Preserve current selection across reloads (e.g. when Phase 2 file results arrive)
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

            let newHeight = searchFieldHeight + 50
            let newY = topY - newHeight
            animateFrame(NSRect(x: currentFrame.origin.x, y: newY, width: windowWidth, height: newHeight))
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
            // Include contextual bar height in total height
            let newHeight = searchFieldHeight + resultsHeight + contextualBarHeight

            let newY = topY - newHeight
            animateFrame(NSRect(x: currentFrame.origin.x, y: newY, width: windowWidth, height: newHeight))
        }
    }
    
    // MARK: - Animated Resize

    private func animateFrame(_ newFrame: NSRect) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: true)
        }
    }

    // MARK: - Key Events

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
        
        // Handle Cmd+Enter for reveal action (force quit processes, reveal files in Finder)
        if Int(event.keyCode) == kVK_Return && event.modifierFlags.contains(.command) {
            revealCurrentResult()
            return
        }
        
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown,
           event.modifierFlags.contains(.command),
           executeIndexedResultShortcut(forKeyCode: Int(event.keyCode))
        {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Modifier Key Events (Option Key Action Bar)

    override func flagsChanged(with event: NSEvent) {
        let optionIsPressed = event.modifierFlags.contains(.option)
        let commandIsPressed = event.modifierFlags.contains(.command)

        // Only react to Option key changes, and only when we have results
        if optionIsPressed != isOptionKeyPressed {
            isOptionKeyPressed = optionIsPressed
            updateActionBarVisibility()
        }

        if commandIsPressed != isCommandKeyPressed {
            isCommandKeyPressed = commandIsPressed
            resultsTableView.reloadData()
        }

        super.flagsChanged(with: event)
    }

    /// Update action bar visibility based on current state
    private func updateActionBarVisibility() {
        // Action bar is only visible when Option is pressed AND we have results
        let shouldShowActionBar = isOptionKeyPressed && !searchResults.isEmpty && !isSettingsMode

        if shouldShowActionBar {
            showActionBar()
        } else {
            hideActionBar()
        }
    }

    /// Show the action bar above the search results
    private func showActionBar() {
        guard actionBarView == nil else { return }
        guard let contentView = contentView else { return }

        let actionBar = createActionBarView()
        actionBarView = actionBar

        // Insert action bar between search field and results
        contentView.addSubview(actionBar)

        // Position below search field, above results
        NSLayoutConstraint.activate([
            actionBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            actionBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            actionBar.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            actionBar.heightAnchor.constraint(equalToConstant: 32),
        ])

        // Deactivate original scroll view constraint and add new one for action bar
        originalScrollViewTopConstraint?.isActive = false
        actionBarScrollViewTopConstraint = scrollView.topAnchor.constraint(equalTo: actionBar.bottomAnchor, constant: 4)
        actionBarScrollViewTopConstraint?.isActive = true
    }

    /// Hide the action bar
    private func hideActionBar() {
        guard actionBarView != nil else { return }
        
        // Restore original scroll view constraint
        actionBarScrollViewTopConstraint?.isActive = false
        actionBarScrollViewTopConstraint = nil
        originalScrollViewTopConstraint?.isActive = true
        
        actionBarView?.removeFromSuperview()
        actionBarView = nil
    }

    /// Create the action bar view with convert and translate options
    private func createActionBarView() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        container.layer?.cornerRadius = 6
        container.translatesAutoresizingMaskIntoConstraints = false

        // Create horizontal stack for options
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.alignment = .centerY
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Add convert option
        let convertButton = createActionBarButton(title: "convert")
        stackView.addArrangedSubview(convertButton)

        // Add separator
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 16),
        ])
        stackView.addArrangedSubview(separator)

        // Add translate option
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

    /// Create a button for an action bar option
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
            // In settings mode, escape exits settings and returns to normal mode
            exitSettingsMode()
        } else if isLLMMode {
            // In LLM mode, escape clears the = prefix and returns to normal mode
            isLLMMode = false
            searchField.stringValue = ""
            hintLabel.stringValue = "⌘↵ Reveal  ↵ Select  Space Preview  ↑↓ Navigate  Esc Close"
            performSearch("")
        } else {
            close()
        }
    }

    func selectCurrentResult() {
        var selectedRow = resultsTableView.selectedRow

        // If no selection but results exist, default to first result
        if selectedRow < 0, !searchResults.isEmpty {
            selectedRow = 0
        }

        guard selectedRow >= 0, selectedRow < searchResults.count else { return }

        executeResult(at: selectedRow)
    }

    /// Reveals the current result (Cmd+Enter action)
    /// For processes: Two-step safety - first Cmd+Enter shows danger mode, second force quits
    /// For files: Reveal in Finder
    /// For other results: Trigger reveal action
    func revealCurrentResult() {
        var selectedRow = resultsTableView.selectedRow

        // If no selection but results exist, default to first result
        if selectedRow < 0, !searchResults.isEmpty {
            selectedRow = 0
        }

        guard selectedRow >= 0, selectedRow < searchResults.count else {
            close()
            return
        }

        let result = searchResults[selectedRow]

        // For process items: two-step safety
        if result.category == .process {
            if isDangerMode {
                // Second Cmd+Enter: Force quit the process
                forceQuitCurrentResult()
            } else {
                // First Cmd+Enter: Enter danger mode (show red state)
                isDangerMode = true
            }
        } else {
            // For non-process items: trigger reveal action normally
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

    // MARK: - Quick Look Preview

    /// Accept Quick Look panel control
    override func acceptsPreviewPanelControl(_: QLPreviewPanel!) -> Bool {
        true
    }

    /// Toggle Quick Look preview for the selected file result
    func toggleQuickLook() {
        guard let selectedResult = getSelectedFileResult() else { return }
        guard selectedResult.isFileResult else { return }

        if isQuickLookOpen {
            closeQuickLook()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
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
        makeKeyAndOrderFront(nil)
    }

    private func installQuickLookMonitors() {
        removeQuickLookMonitors()

        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self, self.isQuickLookOpen else { return }
            let keyCode = Int(event.keyCode)
            if keyCode == kVK_Escape || keyCode == kVK_Space {
                DispatchQueue.main.async { self.closeQuickLook() }
            }
        }

        // Global monitor: catches keys even when terminal/another app is frontmost
        quickLookGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)

        // Local monitor: catches keys when Zest is frontmost
        quickLookLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isQuickLookOpen else { return event }
            let keyCode = Int(event.keyCode)
            if keyCode == kVK_Escape || keyCode == kVK_Space {
                self.closeQuickLook()
                return nil
            }
            return event
        }
    }

    private func removeQuickLookMonitors() {
        if let m = quickLookGlobalMonitor { NSEvent.removeMonitor(m); quickLookGlobalMonitor = nil }
        if let m = quickLookLocalMonitor { NSEvent.removeMonitor(m); quickLookLocalMonitor = nil }
    }

    /// Get the currently selected result if it's a file result
    private func getSelectedFileResult() -> SearchResult? {
        var selectedRow = resultsTableView.selectedRow

        // If no selection but results exist, default to first result
        if selectedRow < 0, !searchResults.isEmpty {
            selectedRow = 0
        }

        guard selectedRow >= 0, selectedRow < searchResults.count else { return nil }

        return searchResults[selectedRow]
    }
}

// MARK: - NSTextFieldDelegate

extension CommandPaletteWindow: NSTextFieldDelegate {
    func controlTextDidChange(_: Notification) {
        performSearch(searchField.stringValue)
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            handleEscape()
            return true
        }

        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            selectCurrentResult()
            return true
        }
        
        // Allow Tab to move between fields (default behavior)
        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            return false // Let system handle Tab
        }
        
        // Allow Shift+Tab to move backwards
        if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
            return false // Let system handle Shift+Tab
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

// MARK: - NSTableViewDelegate & DataSource

extension CommandPaletteWindow: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        searchResults.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        // Update contextual action bar when selection changes
        updateContextualActionBar()
    }

    func tableView(_: NSTableView, rowViewForRow _: Int) -> NSTableRowView? {
        // Return custom row view with dual-state highlighting
        let rowView = ResultRowView()
        rowView.identifier = NSUserInterfaceItemIdentifier("ResultRow")
        return rowView
    }

    func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let result = searchResults[row]

        let cellView = NSTableCellView()
        cellView.identifier = NSUserInterfaceItemIdentifier("ResultCell")
        
        if result.category == .file, let filePath = result.filePath {
            return buildFileCellView(result: result, filePath: filePath, container: cellView, row: row)
        }

        let imageView = NSImageView()
        imageView.image = result.icon
        imageView.translatesAutoresizingMaskIntoConstraints = false

        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        imageView.layer?.backgroundColor = AppStyle.Palette.iconChipBackground.cgColor

        let titleLabel = NSTextField(labelWithString: result.title)
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AppStyle.Palette.primaryText
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: result.subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = AppStyle.Palette.secondaryText
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let (indexBadge, _) = makeKeycapView(text: "\(row + 1)", font: AppStyle.KeyboardBadge.keyFont)
        indexBadge.isHidden = !isCommandKeyPressed

        cellView.addSubview(imageView)
        cellView.addSubview(indexBadge)
        cellView.addSubview(titleLabel)
        cellView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 10),
            imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 34),
            imageView.heightAnchor.constraint(equalToConstant: 34),

            indexBadge.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 10),
            indexBadge.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            indexBadge.widthAnchor.constraint(equalToConstant: 34),
            indexBadge.heightAnchor.constraint(equalToConstant: AppStyle.KeyboardBadge.keyHeight),

            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -12),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
        ])

        imageView.isHidden = isCommandKeyPressed

        return cellView
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        rowHeight
    }
    
    private func buildFileCellView(result: SearchResult, filePath: String, container: NSTableCellView, row: Int) -> NSView {
        let imageView = NSImageView()
        imageView.image = result.icon
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true

        let titleLabel = NSTextField(labelWithString: result.title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = AppStyle.Palette.primaryText
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let pathLabel = NSTextField(labelWithString: displayPathSuffix(for: filePath))
        pathLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        pathLabel.textColor = AppStyle.Palette.secondaryText
        pathLabel.lineBreakMode = .byTruncatingHead
        pathLabel.translatesAutoresizingMaskIntoConstraints = false

        let metadataLabel = NSTextField(labelWithString: fileMetadataLine(filePath: filePath))
        metadataLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        metadataLabel.textColor = AppStyle.Palette.tertiaryText
        metadataLabel.lineBreakMode = .byTruncatingTail
        metadataLabel.translatesAutoresizingMaskIntoConstraints = false

        let sizeLabel = NSTextField(labelWithString: fileSizeBadge(filePath: filePath))
        sizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        sizeLabel.textColor = AppStyle.Palette.chipText
        sizeLabel.alignment = .center
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false

        let sizeBadge = NSView()
        sizeBadge.wantsLayer = true
        sizeBadge.layer?.cornerRadius = 6
        sizeBadge.layer?.backgroundColor = AppStyle.Palette.chipBackground.cgColor
        sizeBadge.layer?.borderColor = AppStyle.Palette.chipBorder.cgColor
        sizeBadge.layer?.borderWidth = 1
        sizeBadge.translatesAutoresizingMaskIntoConstraints = false
        sizeBadge.addSubview(sizeLabel)

        let (indexBadge, _) = makeKeycapView(text: "\(row + 1)", font: AppStyle.KeyboardBadge.keyFont)
        indexBadge.isHidden = !isCommandKeyPressed

        container.addSubview(imageView)
        container.addSubview(indexBadge)
        container.addSubview(titleLabel)
        container.addSubview(pathLabel)
        container.addSubview(metadataLabel)
        container.addSubview(sizeBadge)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 34),
            imageView.heightAnchor.constraint(equalToConstant: 34),

            indexBadge.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            indexBadge.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            indexBadge.widthAnchor.constraint(equalToConstant: 34),
            indexBadge.heightAnchor.constraint(equalToConstant: AppStyle.KeyboardBadge.keyHeight),

            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pathLabel.leadingAnchor, constant: -8),

            pathLabel.trailingAnchor.constraint(equalTo: sizeBadge.leadingAnchor, constant: -10),
            pathLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            pathLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 260),

            metadataLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metadataLabel.trailingAnchor.constraint(lessThanOrEqualTo: sizeBadge.leadingAnchor, constant: -8),
            metadataLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

            sizeBadge.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            sizeBadge.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            sizeLabel.leadingAnchor.constraint(equalTo: sizeBadge.leadingAnchor, constant: 8),
            sizeLabel.trailingAnchor.constraint(equalTo: sizeBadge.trailingAnchor, constant: -8),
            sizeLabel.topAnchor.constraint(equalTo: sizeBadge.topAnchor, constant: 4),
            sizeLabel.bottomAnchor.constraint(equalTo: sizeBadge.bottomAnchor, constant: -4),
            sizeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 42),
        ])

        imageView.isHidden = isCommandKeyPressed

        return container
    }
    
    private func displayPathSuffix(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let components = url.deletingLastPathComponent().pathComponents
        if components.count <= 3 {
            return url.deletingLastPathComponent().path
        }
        let suffix = components.suffix(3).joined(separator: "/")
        return "/\(suffix)"
    }

    private func fileMetadataLine(filePath: String) -> String {
        let url = URL(fileURLWithPath: filePath)
        let ext = url.pathExtension.uppercased()
        let typeText = ext.isEmpty ? "File" : "\(ext) Document"

        let modifiedText: String = {
            let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
            guard let date = attrs?[.modificationDate] as? Date else { return "Updated recently" }
            return "Updated \(relativeDateString(from: date))"
        }()

        return "\(modifiedText)  •  \(typeText)"
    }

    private func fileSizeBadge(filePath: String) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
        guard let bytes = attrs?[.size] as? NSNumber else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes.int64Value)
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Test Helpers

extension CommandPaletteWindow {
    /// Current selected result index (for testing)
    var selectedIndex: Int {
        resultsTableView.selectedRow
    }

    /// Check if search field is first responder (for testing)
    var isSearchFieldFirstResponder: Bool {
        !isResultsFocused
    }

    /// Check if results table is first responder (for testing)
    var isResultsTableFirstResponder: Bool {
        isResultsFocused
    }

    /// Get the current text in the search field (for testing)
    var searchFieldText: String {
        searchField.stringValue
    }

    /// Check if text is selected in the search field (for testing)
    var isSearchFieldTextSelected: Bool {
        guard let fieldEditor = fieldEditor(false, for: searchField) else { return false }
        return fieldEditor.selectedRange.length > 0
    }

    /// Set text in search field (for testing)
    func setSearchFieldTextForTesting(_ text: String) {
        searchField.stringValue = text
        // Also update the field editor so it's in sync
        if let fieldEditor = fieldEditor(false, for: searchField) {
            fieldEditor.string = text
        }
    }

    /// Update results for testing purposes
    func updateResultsForTesting(_ results: [SearchResult]) {
        searchResults = results
        resultsTableView.reloadData()

        if !results.isEmpty {
            // Auto-select first result
            resultsTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            scrollView.isHidden = false
        } else {
            scrollView.isHidden = true
        }
        
        // Update action bar visibility based on results
        updateActionBarVisibility()
    }

    /// Clear selection (for testing)
    func clearSelectionForTesting() {
        resultsTableView.deselectAll(nil)
    }

    /// Set selected result index (for testing)
    func setSelectedIndexForTesting(_ index: Int) {
        guard index >= 0, index < searchResults.count else { return }
        resultsTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }

    /// Simulate key press (for testing)
    func simulateKeyPress(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )!
        keyDown(with: event)
    }

    /// Simulate character key press (for testing)
    func simulateCharacterKeyPress(character: String) {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: character,
            charactersIgnoringModifiers: character,
            isARepeat: false,
            keyCode: 0
        )!
        keyDown(with: event)
    }

    // MARK: - Quick Look Test Helpers

    /// Check if Quick Look was requested (for testing)
    var isQuickLookRequested: Bool {
        isQuickLookOpen
    }

    /// Check if Quick Look is closing (for testing) - tracks close operation
    var isQuickLookClosing: Bool {
        !isQuickLookOpen && getSelectedFileResult()?.isFileResult == true
    }

    /// Reset Quick Look request flag (for testing)
    func resetQuickLookRequestFlag() {
        // This is used to reset the tracking between test assertions
        // The actual state is tracked by isQuickLookOpen
    }

    /// Get file URL for selected result (for testing)
    var selectedFileURL: URL? {
        getSelectedFileResult()?.fileURL
    }

    // MARK: - Hover State Test Helpers

    /// Set hover state on multiple rows for testing
    func setHoverOnRowsForTesting(_ rows: [Int]) {
        resultsTableView.setHoverOnRowsForTesting(rows)
    }

    /// Check if any rows have hover state for testing
    func hasAnyHoveredRowsForTesting() -> Bool {
        resultsTableView.hasAnyHoveredRowsForTesting()
    }

    /// Clear hover on all rows for testing
    func clearHoverOnAllRowsForTesting() {
        resultsTableView.clearHover()
    }

    // MARK: - Action Bar Test Helpers

    /// Check if action bar is visible (for testing)
    var isActionBarVisible: Bool {
        actionBarView != nil && actionBarView?.superview != nil
    }

    /// Get action bar options (for testing)
    var actionBarOptions: [String] {
        actionBarOptionLabels
    }

    /// Simulate modifier flags change (for testing Option key detection)
    /// Directly updates the internal state without creating NSEvent
    func simulateModifierFlagsChange(modifiers: NSEvent.ModifierFlags) {
        let optionIsPressed = modifiers.contains(.option)
        if optionIsPressed != isOptionKeyPressed {
            isOptionKeyPressed = optionIsPressed
            updateActionBarVisibility()
        }
    }
}

// MARK: - QLPreviewPanelDataSource

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

// MARK: - QLPreviewPanelDelegate

extension CommandPaletteWindow: QLPreviewPanelDelegate {
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown else { return false }

        let keyCode = Int(event.keyCode)
        if keyCode == kVK_Escape || keyCode == kVK_Space {
            closeQuickLook()
            return true
        }

        return false
    }
}
