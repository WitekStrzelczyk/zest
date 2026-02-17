import AppKit
import Carbon
import Quartz

// MARK: - Custom Row View with Dual-State Highlighting

/// Custom NSTableRowView that implements dual-state highlighting:
/// - Keyboard focus (selection): darker background (15% opacity)
/// - Mouse hover: lighter background (8% opacity)
/// - Both on same item: focus takes precedence
final class ResultRowView: NSTableRowView {
    /// Whether the mouse is currently hovering over this row
    var isHovered: Bool = false {
        didSet {
            if oldValue != isHovered {
                needsDisplay = true
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Draw custom background based on state
        if isSelected {
            // Keyboard focus - darker (15% opacity)
            NSColor.labelColor.withAlphaComponent(0.15).setFill()
            bounds.fill()
        } else if isHovered {
            // Mouse hover - lighter (8% opacity)
            NSColor.labelColor.withAlphaComponent(0.08).setFill()
            bounds.fill()
        }

        super.draw(dirtyRect)
    }

    override func drawSelection(in dirtyRect: NSRect) {
        // We handle selection drawing ourselves in draw(_:)
        // This prevents the default blue selection highlight
    }
}

// MARK: - Custom Results Table View

/// Custom NSTableView that handles keyboard navigation and forwards character keys to search field
final class ResultsTableView: NSTableView {
    weak var commandPalette: CommandPaletteWindow?

    /// Currently hovered row index (managed centrally to prevent multiple highlights)
    private(set) var hoveredRow: Int? = nil

    override var acceptsFirstResponder: Bool {
        true
    }

    /// Set hover state for a specific row, clearing others
    func setHoveredRow(_ row: Int?) {
        let previousHovered = hoveredRow
        hoveredRow = row

        // Clear previous hover
        if let prev = previousHovered, prev >= 0, prev < numberOfRows {
            if let rowView = rowView(atRow: prev, makeIfNecessary: false) as? ResultRowView {
                rowView.isHovered = false
            }
        }

        // Set new hover
        if let new = row, new >= 0, new < numberOfRows {
            if let rowView = rowView(atRow: new, makeIfNecessary: false) as? ResultRowView {
                rowView.isHovered = true
            }
        }
    }

    /// Clear all hover states from all visible rows
    func clearHover() {
        // Clear tracked hover state
        hoveredRow = nil

        // Clear hover state from ALL visible row views
        // This ensures any rows that may have been hovered but not properly tracked
        // (e.g., due to row recycling or nil returns from rowView(atRow:)) get cleared
        enumerateAvailableRowViews { rowView, _ in
            if let resultRowView = rowView as? ResultRowView {
                resultRowView.isHovered = false
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        // Clear hover when using keyboard navigation
        clearHover()

        // Handle up arrow on first row - return to search field
        if event.keyCode == 126 { // Up arrow
            if selectedRow <= 0 {
                // Return to search field
                commandPalette?.returnToSearchField()
                return
            }
        }

        // Handle character keys - return to search field and forward the key
        if let characters = event.characters, !characters.isEmpty {
            let isPrintableChar = characters.unicodeScalars.first.map { CharacterSet.alphanumerics.contains($0) } ?? false
            if isPrintableChar {
                commandPalette?.returnToSearchFieldAndType(characters)
                return
            }
        }

        // Default handling for other keys
        super.keyDown(with: event)
    }

    // MARK: - Mouse Tracking

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)

        if row >= 0 && row < numberOfRows {
            setHoveredRow(row)
        } else {
            clearHover()
        }
    }

    override func mouseExited(with event: NSEvent) {
        clearHover()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Ensure we have tracking for mouse movements
        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .mouseEnteredAndExited,
            .activeInActiveApp,
            .inVisibleRect
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
    private var searchField: NSTextField!
    private var resultsTableView: ResultsTableView!
    private var scrollView: NSScrollView!
    private(set) var hintLabel: NSTextField!
    private var noResultsLabel: NSTextField!
    private var previousApp: NSRunningApplication?
    private var searchResults: [SearchResult] = []

    /// Tracks whether focus is on results table (vs search field)
    /// This is used because makeFirstResponder only works when window is key
    private var isResultsFocused: Bool = false

    /// Tracks whether Quick Look preview is currently showing
    private var isQuickLookOpen: Bool = false

    // Layout constants
    private let windowWidth: CGFloat = 680
    private let searchFieldHeight: CGFloat = 56
    private let rowHeight: CGFloat = 40
    private let hintHeight: CGFloat = 24
    private let maxResultsHeight: CGFloat = 0.4 // 40% of screen

    override init(
        contentRect _: NSRect,
        styleMask _: NSWindow.StyleMask,
        backing _: NSWindow.BackingStoreType,
        defer _: Bool
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: searchFieldHeight + hintHeight),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupUI()
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
    }

    private func setupUI() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: searchFieldHeight + hintHeight))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.layer?.cornerRadius = 12
        contentView.layer?.masksToBounds = true

        // Search icon
        let searchIcon = NSImageView()
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        searchIcon.contentTintColor = .secondaryLabelColor
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchIcon)

        // Search field
        searchField = NSTextField()
        searchField.placeholderString = "Search apps, files, and commands..."
        searchField.font = NSFont.systemFont(ofSize: 22, weight: .regular)
        searchField.isBordered = false
        searchField.focusRingType = .none
        searchField.backgroundColor = .clear
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchField)

        // Hint label at bottom
        hintLabel = NSTextField(labelWithString: "\u{2318}\u{21A9} Reveal  \u{21B5} Select  Space Preview  \u{2191}\u{2193} Navigate  Esc Close")
        hintLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.alignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hintLabel)

        // Results table (custom class for keyboard handling)
        resultsTableView = ResultsTableView()
        resultsTableView.headerView = nil
        resultsTableView.backgroundColor = .clear
        resultsTableView.intercellSpacing = NSSize(width: 0, height: 0)
        resultsTableView.selectionHighlightStyle = .none  // Custom drawing in ResultRowView
        resultsTableView.delegate = self
        resultsTableView.dataSource = self
        resultsTableView.commandPalette = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Result"))
        column.width = windowWidth - 16
        resultsTableView.addTableColumn(column)

        scrollView = NSScrollView()
        scrollView.documentView = resultsTableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.isHidden = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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
            // Search icon - top left
            searchIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            searchIcon.widthAnchor.constraint(equalToConstant: 20),
            searchIcon.heightAnchor.constraint(equalToConstant: 20),

            // Search field - next to icon, full width minus margins
            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            searchField.centerYAnchor.constraint(equalTo: searchIcon.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            // Scroll view - below search, above hints
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -4),

            // No results - centered in scroll area
            noResultsLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            noResultsLabel.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 20),

            // Hint label - bottom
            hintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            hintLabel.heightAnchor.constraint(equalToConstant: hintHeight),
        ])

        self.contentView = contentView
    }

    // MARK: - Show/Hide

    func show(previousApp: NSRunningApplication?) {
        self.previousApp = previousApp
        searchField.stringValue = ""
        searchResults = []
        resultsTableView.reloadData()
        scrollView.isHidden = true
        noResultsLabel.isHidden = true
        hintLabel.isHidden = false
        isResultsFocused = false // Reset to search field focus

        // Position window - store top position for resize from bottom (top fixed)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowX = screenFrame.midX - windowWidth / 2
            let windowY = screenFrame.midY + 120
            let frame = NSRect(x: windowX, y: windowY, width: windowWidth, height: searchFieldHeight + hintHeight)
            setFrame(frame, display: true)
            initialWindowTop = frame.maxY
        }

        makeKeyAndOrderFront(nil)
        // Use makeFirstResponder for proper first responder management
        makeFirstResponder(searchField)
    }

    override func close() {
        // First, resign first responder and key window status
        // This ensures the window stops capturing keyboard events
        makeFirstResponder(nil)
        resignKey()

        // Use orderOut to hide without activating previous app immediately
        // This is cleaner than super.close() for nonactivating panels
        orderOut(nil)

        // Hide the entire application to ensure it stops capturing keys
        NSApp.hide(nil)

        // Reactivate previous app after window is hidden
        previousApp?.activate(options: .activateIgnoringOtherApps)
        previousApp = nil
    }

    // MARK: - Focus Management

    /// Return focus to search field from results table
    func returnToSearchField() {
        resultsTableView.deselectAll(nil)
        isResultsFocused = false
        makeFirstResponder(searchField)
    }

    /// Return focus to search field and type a character
    func returnToSearchFieldAndType(_ character: String) {
        resultsTableView.deselectAll(nil)
        isResultsFocused = false
        makeFirstResponder(searchField)

        // Append the character to the search field
        searchField.stringValue += character
        performSearch(searchField.stringValue)
    }

    // MARK: - Search

    /// Store initial top position to resize from bottom (top stays fixed)
    private var initialWindowTop: CGFloat?

    /// Task for background file search
    private var fileSearchTask: Task<Void, Never>?

    /// Current search query to avoid race conditions
    private var currentSearchQuery: String = ""

    private func performSearch(_ query: String) {
        // Cancel previous file search
        fileSearchTask?.cancel()

        // Cancel any in-progress search
        SearchEngine.shared.cancelCurrentSearch()

        guard let topY = initialWindowTop, let screen = NSScreen.main else { return }

        let currentFrame = frame

        if query.isEmpty {
            searchResults = []
            resultsTableView.reloadData()
            scrollView.isHidden = true
            noResultsLabel.isHidden = true
            hintLabel.isHidden = false

            // Resize from bottom - top stays fixed
            let newHeight = searchFieldHeight + hintHeight
            let newY = topY - newHeight
            setFrame(NSRect(x: currentFrame.origin.x, y: newY, width: windowWidth, height: newHeight), display: true)
        } else {
            // Store current query for race condition handling
            currentSearchQuery = query

            // PHASE 1: Show fast results immediately (apps, calculator, clipboard, emojis)
            let fastResults = SearchEngine.shared.searchFast(query: query)
            updateSearchResults(fastResults, topY: topY, screen: screen)

            // PHASE 2: Run file search in background and append when ready
            fileSearchTask = Task { [weak self] in
                guard let self else { return }

                // Small delay before file search to not compete with fast results
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

                guard !Task.isCancelled else { return }

                // Verify query hasn't changed
                guard currentSearchQuery == query else { return }

                // Run file search on background
                let fileResults = await Task.detached(priority: .utility) {
                    SearchEngine.shared.searchFiles(query: query)
                }.value

                // Check if query still matches (prevent race condition)
                guard currentSearchQuery == query else { return }

                // Merge results: fast results + file results
                var combinedResults = fastResults
                for fileResult in fileResults {
                    // Avoid duplicates by title
                    if !combinedResults.contains(where: { $0.title == fileResult.title }) {
                        combinedResults.append(fileResult)
                    }
                }

                // Update UI on main thread
                await MainActor.run {
                    guard self.currentSearchQuery == query else { return }
                    self.updateSearchResults(combinedResults, topY: topY, screen: screen)
                }
            }
        }
    }

    private func updateSearchResults(_ results: [SearchResult], topY: CGFloat, screen: NSScreen) {
        let currentFrame = frame

        searchResults = results
        resultsTableView.reloadData()

        if searchResults.isEmpty {
            scrollView.isHidden = true
            noResultsLabel.isHidden = false
            hintLabel.isHidden = true

            // Resize from bottom - top stays fixed
            let newHeight = searchFieldHeight + 50
            let newY = topY - newHeight
            setFrame(NSRect(x: currentFrame.origin.x, y: newY, width: windowWidth, height: newHeight), display: true)
        } else {
            scrollView.isHidden = false
            noResultsLabel.isHidden = true
            hintLabel.isHidden = true

            // Auto-select first result when results appear
            resultsTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

            // Calculate height: search + results + hints
            let availableHeight = screen.visibleFrame.height * maxResultsHeight
            let maxRows = Int((availableHeight - searchFieldHeight - hintHeight - 20) / rowHeight)
            let visibleRows = min(searchResults.count, maxRows)
            let resultsHeight = CGFloat(visibleRows) * rowHeight + 8
            let newHeight = searchFieldHeight + resultsHeight + hintHeight

            // Resize from bottom - top stays fixed
            let newY = topY - newHeight
            setFrame(NSRect(x: currentFrame.origin.x, y: newY, width: windowWidth, height: newHeight), display: true)
        }
    }

    // MARK: - Key Events

    override func keyDown(with event: NSEvent) {
        // Check for Cmd+Enter (Reveal in Finder)
        if event.modifierFlags.contains(.command), event.keyCode == 36 {
            revealCurrentResultInFinder()
            return
        }

        switch event.keyCode {
        case 53: // Escape
            close()
        case 36: // Enter
            selectCurrentResult()
        case 49: // Space - Quick Look preview
            toggleQuickLook()
        case 125: // Down arrow
            if !searchResults.isEmpty {
                // Clear hover when using keyboard navigation
                resultsTableView.clearHover()

                // Check if focus is on search field
                if !isResultsFocused {
                    // Move focus to results table and select first result
                    resultsTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                    resultsTableView.scrollRowToVisible(0)
                    isResultsFocused = true
                    makeFirstResponder(resultsTableView)
                } else {
                    // Already on results table, navigate to next row
                    let currentRow = resultsTableView.selectedRow
                    let newRow = min(currentRow + 1, searchResults.count - 1)
                    resultsTableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                    resultsTableView.scrollRowToVisible(newRow)
                }
            }
        case 126: // Up arrow
            if !searchResults.isEmpty {
                // Clear hover when using keyboard navigation
                resultsTableView.clearHover()

                let currentRow = resultsTableView.selectedRow
                if currentRow <= 0 || !isResultsFocused {
                    // At first result or no selection - return to search field
                    resultsTableView.deselectAll(nil)
                    isResultsFocused = false
                    makeFirstResponder(searchField)
                } else {
                    let newRow = currentRow - 1
                    resultsTableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                    resultsTableView.scrollRowToVisible(newRow)
                    // Keep first responder on results table
                    makeFirstResponder(resultsTableView)
                }
            }
        default:
            // If typing a character while results are focused, return to search field
            if let characters = event.characters, !characters.isEmpty {
                let isPrintableChar = characters.unicodeScalars.first.map { CharacterSet.alphanumerics.contains($0) } ?? false
                if isPrintableChar, isResultsFocused {
                    // Return focus to search field and let the character be typed
                    resultsTableView.deselectAll(nil)
                    isResultsFocused = false
                    makeFirstResponder(searchField)
                    // Let the search field handle the character
                    super.keyDown(with: event)
                    return
                }
            }
            super.keyDown(with: event)
        }
    }

    /// Reveal the currently selected result in Finder (Cmd+Enter)
    private func revealCurrentResultInFinder() {
        var selectedRow = resultsTableView.selectedRow

        // If no selection but results exist, default to first result
        if selectedRow < 0, !searchResults.isEmpty {
            selectedRow = 0
        }

        guard selectedRow >= 0, selectedRow < searchResults.count else { return }

        let result = searchResults[selectedRow]
        result.reveal()
        close()
    }

    private func selectCurrentResult() {
        var selectedRow = resultsTableView.selectedRow

        // If no selection but results exist, default to first result
        if selectedRow < 0, !searchResults.isEmpty {
            selectedRow = 0
        }

        guard selectedRow >= 0, selectedRow < searchResults.count else { return }

        let result = searchResults[selectedRow]
        result.execute()
        close()
    }

    // MARK: - Quick Look Preview

    /// Accept Quick Look panel control
    override func acceptsPreviewPanelControl(_: QLPreviewPanel!) -> Bool {
        true
    }

    /// Toggle Quick Look preview for the selected file result
    private func toggleQuickLook() {
        guard let selectedResult = getSelectedFileResult() else { return }

        // Only file results with a valid file path can be previewed
        guard selectedResult.isFileResult else { return }

        if isQuickLookOpen {
            // Close Quick Look
            QLPreviewPanel.shared().orderOut(nil)
            isQuickLookOpen = false
        } else {
            // Open Quick Look
            QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
            isQuickLookOpen = true
        }
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
            close()
            return true
        }

        // Handle arrow keys from search field
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            if !searchResults.isEmpty {
                // Move focus to results table
                isResultsFocused = true
                resultsTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                resultsTableView.scrollRowToVisible(0)
                makeFirstResponder(resultsTableView)
                return true
            }
        }

        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            // Already at search field, nothing to do
            return true
        }

        // Handle Enter key - execute first result if no explicit selection
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if !searchResults.isEmpty {
                selectCurrentResult()
                return true
            }
        }

        return false
    }
}

// MARK: - NSTableViewDelegate & DataSource

extension CommandPaletteWindow: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        searchResults.count
    }

    func tableView(_: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        // Return custom row view with dual-state highlighting
        let rowView = ResultRowView()
        rowView.identifier = NSUserInterfaceItemIdentifier("ResultRow")
        return rowView
    }

    func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let result = searchResults[row]

        let cellView = NSTableCellView()
        cellView.identifier = NSUserInterfaceItemIdentifier("ResultCell")

        let imageView = NSImageView()
        imageView.image = result.icon
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: result.title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: result.subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        cellView.addSubview(imageView)
        cellView.addSubview(titleLabel)
        cellView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 12),
            imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 28),
            imageView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 4),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
        ])

        return cellView
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        rowHeight
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
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
    }
}
