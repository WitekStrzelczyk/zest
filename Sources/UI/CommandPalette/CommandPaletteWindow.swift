import AppKit
import Carbon
import Quartz

// MARK: - Row View with Custom Highlight Colors

/// Row view using `.inset` table style for layout (rounded rects)
/// but with custom subtle colors instead of the default blue accent.
final class ResultRowView: NSTableRowView {
    var isHovered: Bool = false {
        didSet {
            if oldValue != isHovered { needsDisplay = true }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isHovered = false
    }

    override func drawSelection(in dirtyRect: NSRect) {
        // 20% lighter than background -- subtle keyboard selection
        NSColor.white.withAlphaComponent(0.12).setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 6, yRadius: 6)
        path.fill()
    }

    override func draw(_ dirtyRect: NSRect) {
        if !isSelected, isHovered {
            // 30% lighter than background -- mouse hover
            NSColor.white.withAlphaComponent(0.06).setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 6, yRadius: 6)
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

        let contentHeight = docView.frame.height
        let visibleHeight = contentView.bounds.height
        guard contentHeight > visibleHeight else {
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

        let topStop = fadeTop ? fadeHeight / bounds.height : 0
        let bottomStop = fadeBottom ? 1 - (fadeHeight / bounds.height) : 1
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

        switch Int(event.keyCode) {
        case kVK_Escape:
            palette.handleEscape()

        case kVK_Return:
            palette.selectCurrentResult()

        case kVK_UpArrow:
            clearHover()
            if selectedRow <= 0 {
                palette.returnToSearchField()
            } else {
                super.keyDown(with: event)
            }

        case kVK_DownArrow:
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
    private var noResultsLabel: NSTextField!
    /// Exposed for testing
    private(set) var searchResults: [SearchResult] = []

    /// Tracks whether focus is on results table (vs search field)
    /// This is used because makeFirstResponder only works when window is key
    private var isResultsFocused: Bool = false

    /// Tracks whether Quick Look preview is currently showing
    private var isQuickLookOpen: Bool = false

    /// Tracks whether we're in settings mode (quicklink creation)
    /// Exposed for testing
    private(set) var isSettingsMode: Bool = false {
        didSet {
            if isSettingsMode != oldValue {
                handleModeChange()
            }
        }
    }

    /// Centralized mode handling - called whenever mode changes
    private func handleModeChange() {
        if isSettingsMode {
            // ENTERING SETTINGS MODE
            // 1. Cancel any pending file search
            fileSearchTask?.cancel()
            fileSearchTask = nil
            
            // 2. Cancel in-progress search engine search
            SearchEngine.shared.cancelCurrentSearch()
            
            // 3. Hide search and results UI
            searchField.isHidden = true
            searchIcon.isHidden = true
            scrollView.isHidden = true
            noResultsLabel.isHidden = true
            hintLabel.isHidden = true
            
            // 4. Show settings UI
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
                performSearchInternal(preservedSearchQuery)
            }
            
            // 6. Focus on search field
            makeFirstResponder(searchField)
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
    private let windowWidth: CGFloat = 680
    private let searchFieldHeight: CGFloat = 56
    private let rowHeight: CGFloat = 40
    private let hintHeight: CGFloat = 24
    private let maxResultsHeight: CGFloat = 0.4 // 40% of screen

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
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: searchFieldHeight + hintHeight),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupUI()
        setupNotifications()
    }

    deinit {
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

    private func setupUI() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: searchFieldHeight + hintHeight))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.layer?.cornerRadius = 12
        contentView.layer?.masksToBounds = true

        // Search icon
        searchIcon = NSImageView()
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

            // Scroll view - below search, to bottom edge
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

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

    func show(previousApp: NSRunningApplication? = nil) {
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
        // Reset settings mode when closing
        isSettingsMode = false
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

    /// Task for background file search
    private var fileSearchTask: Task<Void, Never>?

    /// Current search query to avoid race conditions
    private var currentSearchQuery: String = ""

    /// Perform search - only runs in normal mode
    private func performSearch(_ query: String) {
        // Don't search when in settings mode
        guard !isSettingsMode else { return }
        performSearchInternal(query)
    }

    /// Internal search implementation - always runs regardless of mode
    private func performSearchInternal(_ query: String) {
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

            let newHeight = searchFieldHeight + hintHeight
            let newY = topY - newHeight
            animateFrame(NSRect(x: currentFrame.origin.x, y: newY, width: windowWidth, height: newHeight))
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

                // Merge results: fast results + file results, sorted by score (highest first) then category
                var combinedResults = fastResults
                for fileResult in fileResults {
                    if !combinedResults.contains(where: { $0.title == fileResult.title }) {
                        combinedResults.append(fileResult)
                    }
                }
                combinedResults.sort { (a, b) -> Bool in
                    if a.score != b.score { return a.score > b.score }
                    return a.category < b.category
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
            noResultsLabel.isHidden = false
            hintLabel.isHidden = true

            let newHeight = searchFieldHeight + 50
            let newY = topY - newHeight
            animateFrame(NSRect(x: currentFrame.origin.x, y: newY, width: windowWidth, height: newHeight))
        } else {
            scrollView.isHidden = false
            noResultsLabel.isHidden = true
            hintLabel.isHidden = true

            var restoredRow = 0
            if let title = previouslySelectedTitle {
                if let idx = searchResults.firstIndex(where: { $0.title == title }) {
                    restoredRow = idx
                }
            }
            resultsTableView.selectRowIndexes(IndexSet(integer: restoredRow), byExtendingSelection: false)
            resultsTableView.scrollRowToVisible(restoredRow)

            let availableHeight = screen.visibleFrame.height * maxResultsHeight
            let maxRows = Int((availableHeight - searchFieldHeight - 20) / rowHeight)
            let visibleRows = min(searchResults.count, maxRows)
            let resultsHeight = CGFloat(visibleRows) * rowHeight + 8
            let newHeight = searchFieldHeight + resultsHeight

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
        super.keyDown(with: event)
    }

    func handleEscape() {
        if isQuickLookOpen {
            closeQuickLook()
        } else if isSettingsMode {
            // In settings mode, escape exits settings and returns to normal mode
            exitSettingsMode()
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

        let result = searchResults[selectedRow]
        
        // Handle settings category specially - don't close window, enter settings mode
        if result.category == .settings {
            enterSettingsMode()
            return
        }
        
        result.execute()
        close()
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

        let imageView = NSImageView()
        imageView.image = result.icon
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: result.title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Category badge: rounded background with small text
        let badgeLabel = NSTextField(labelWithString: result.subtitle)
        badgeLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        badgeLabel.textColor = .secondaryLabelColor
        badgeLabel.alignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        let badgeContainer = NSView()
        badgeContainer.wantsLayer = true
        badgeContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        badgeContainer.layer?.cornerRadius = 4
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeLabel)

        cellView.addSubview(imageView)
        cellView.addSubview(titleLabel)
        cellView.addSubview(badgeContainer)

        // Add checkmark for active toggles
        if result.isActive {
            let checkmarkView = NSImageView()
            checkmarkView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Active")
            checkmarkView.contentTintColor = .systemGreen
            checkmarkView.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(checkmarkView)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 28),
                imageView.heightAnchor.constraint(equalToConstant: 28),

                titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkView.leadingAnchor, constant: -8),
                titleLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),

                checkmarkView.trailingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: -8),
                checkmarkView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                checkmarkView.widthAnchor.constraint(equalToConstant: 18),
                checkmarkView.heightAnchor.constraint(equalToConstant: 18),

                badgeContainer.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                badgeContainer.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),

                badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 6),
                badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -6),
                badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 2),
                badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -2),
            ])
        } else {
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 28),
                imageView.heightAnchor.constraint(equalToConstant: 28),

                titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeContainer.leadingAnchor, constant: -8),
                titleLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),

                badgeContainer.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                badgeContainer.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),

                badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 6),
                badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -6),
                badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 2),
                badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -2),
            ])
        }

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
