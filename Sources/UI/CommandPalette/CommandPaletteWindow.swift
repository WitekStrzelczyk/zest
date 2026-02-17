import AppKit
import Carbon

final class CommandPaletteWindow: NSPanel {
    private var searchField: NSTextField!
    private var resultsTableView: NSTableView!
    private var scrollView: NSScrollView!
    private(set) var hintLabel: NSTextField!
    private var noResultsLabel: NSTextField!
    private var previousApp: NSRunningApplication?
    private var searchResults: [SearchResult] = []

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
        hintLabel = NSTextField(labelWithString: "\u{2318}\u{21A9} Reveal  \u{21B5} Select  \u{2191}\u{2193} Navigate  Esc Close")
        hintLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.alignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hintLabel)

        // Results table
        resultsTableView = NSTableView()
        resultsTableView.headerView = nil
        resultsTableView.backgroundColor = .clear
        resultsTableView.intercellSpacing = NSSize(width: 0, height: 0)
        resultsTableView.selectionHighlightStyle = .regular
        resultsTableView.delegate = self
        resultsTableView.dataSource = self

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
        searchField.becomeFirstResponder()
    }

    override func close() {
        super.close()
        previousApp?.activate(options: .activateIgnoringOtherApps)
    }

    // MARK: - Search

    /// Store initial top position to resize from bottom (top stays fixed)
    private var initialWindowTop: CGFloat?

    /// Debounce task for search
    private var searchDebounceTask: Task<Void, Never>?

    /// Current search query to avoid race conditions
    private var currentSearchQuery: String = ""

    private func performSearch(_ query: String) {
        // Cancel previous debounced search
        searchDebounceTask?.cancel()

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

            // Debounce search by 50ms to avoid searching on every keystroke
            searchDebounceTask = Task { [weak self] in
                // Small debounce - 50ms
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

                guard !Task.isCancelled else { return }
                guard let self else { return }

                // Verify query hasn't changed during debounce
                guard currentSearchQuery == query else { return }

                // Perform search on background (async to avoid blocking main thread)
                let results = await SearchEngine.shared.searchAsync(query: query)

                // Check if query still matches (prevent race condition)
                guard currentSearchQuery == query else { return }

                // Update UI on main thread
                await MainActor.run {
                    self.updateSearchResults(results, topY: topY, screen: screen)
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
        case 125: // Down arrow
            if !searchResults.isEmpty {
                let newRow = min(resultsTableView.selectedRow + 1, searchResults.count - 1)
                resultsTableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                resultsTableView.scrollRowToVisible(newRow)
            }
        case 126: // Up arrow
            if !searchResults.isEmpty {
                let newRow = max(resultsTableView.selectedRow - 1, 0)
                resultsTableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                resultsTableView.scrollRowToVisible(newRow)
            }
        default:
            super.keyDown(with: event)
        }
    }

    /// Reveal the currently selected result in Finder (Cmd+Enter)
    private func revealCurrentResultInFinder() {
        let selectedRow = resultsTableView.selectedRow
        guard selectedRow >= 0, selectedRow < searchResults.count else { return }

        let result = searchResults[selectedRow]
        result.reveal()
        close()
    }

    private func selectCurrentResult() {
        let selectedRow = resultsTableView.selectedRow
        guard selectedRow >= 0, selectedRow < searchResults.count else { return }

        let result = searchResults[selectedRow]
        result.execute()
        close()
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
        return false
    }
}

// MARK: - NSTableViewDelegate & DataSource

extension CommandPaletteWindow: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        searchResults.count
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
