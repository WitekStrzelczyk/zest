import AppKit

/// A floating HUD window that displays the picked color result
/// Shows color swatch, HEX/RGB/HSL values, and indicates which was copied
/// The preferred format is shown first (larger) and auto-copied
final class ColorResultHUD: NSPanel {
    // MARK: - UI Elements
    
    private let primaryButton: NSButton
    private let secondaryButton1: NSButton
    private let secondaryButton2: NSButton
    private let colorSwatch: NSView
    private let copiedLabel: NSTextField
    
    // MARK: - State
    
    private var currentColorInfo: ColorInfo?
    private var hideCopiedTimer: Timer?
    private var currentFormats: (primary: ColorFormat, secondary1: ColorFormat, secondary2: ColorFormat) = (.hex, .rgb, .hsl)
    
    // MARK: - Init
    
    init() {
        // Primary button (larger, semibold - for preferred format)
        primaryButton = NSButton()
        primaryButton.title = "#FF6363"
        primaryButton.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        primaryButton.bezelStyle = .inline
        primaryButton.isBordered = false
        primaryButton.contentTintColor = .labelColor
        primaryButton.alignment = .left
        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Secondary buttons (smaller - for other formats)
        secondaryButton1 = NSButton()
        secondaryButton1.title = "rgb(255, 99, 99)"
        secondaryButton1.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        secondaryButton1.bezelStyle = .inline
        secondaryButton1.isBordered = false
        secondaryButton1.contentTintColor = .secondaryLabelColor
        secondaryButton1.alignment = .left
        secondaryButton1.translatesAutoresizingMaskIntoConstraints = false
        
        secondaryButton2 = NSButton()
        secondaryButton2.title = "hsl(0, 100%, 69%)"
        secondaryButton2.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        secondaryButton2.bezelStyle = .inline
        secondaryButton2.isBordered = false
        secondaryButton2.contentTintColor = .secondaryLabelColor
        secondaryButton2.alignment = .left
        secondaryButton2.translatesAutoresizingMaskIntoConstraints = false
        
        colorSwatch = NSView()
        colorSwatch.wantsLayer = true
        colorSwatch.layer?.cornerRadius = 8
        colorSwatch.layer?.backgroundColor = NSColor.red.cgColor
        colorSwatch.translatesAutoresizingMaskIntoConstraints = false
        
        copiedLabel = NSTextField(labelWithString: "")
        copiedLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        copiedLabel.textColor = .systemGreen
        copiedLabel.alignment = .right
        copiedLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Calculate initial size
        let width: CGFloat = 280
        let height: CGFloat = 100
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupUI(width: width, height: height)
        setupActions()
        updateButtonOrder()
    }
    
    // MARK: - Setup
    
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
        hidesOnDeactivate = false
    }
    
    private func setupUI(width: CGFloat, height: CGFloat) {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.layer?.cornerRadius = 12
        contentView.layer?.masksToBounds = true
        
        // Title label
        let titleLabel = NSTextField(labelWithString: "Color Picked")
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .tertiaryLabelColor
        titleLabel.alignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Add subviews
        contentView.addSubview(colorSwatch)
        contentView.addSubview(primaryButton)
        contentView.addSubview(secondaryButton1)
        contentView.addSubview(secondaryButton2)
        contentView.addSubview(copiedLabel)
        
        NSLayoutConstraint.activate([
            // Title - top left
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            
            // Color swatch - left side
            colorSwatch.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            colorSwatch.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            colorSwatch.widthAnchor.constraint(equalToConstant: 44),
            colorSwatch.heightAnchor.constraint(equalToConstant: 44),
            
            // Primary button - right of swatch (top, larger)
            primaryButton.leadingAnchor.constraint(equalTo: colorSwatch.trailingAnchor, constant: 12),
            primaryButton.topAnchor.constraint(equalTo: colorSwatch.topAnchor),
            
            // Secondary button 1 - below primary
            secondaryButton1.leadingAnchor.constraint(equalTo: primaryButton.leadingAnchor),
            secondaryButton1.topAnchor.constraint(equalTo: primaryButton.bottomAnchor, constant: 0),
            
            // Secondary button 2 - below secondary 1
            secondaryButton2.leadingAnchor.constraint(equalTo: primaryButton.leadingAnchor),
            secondaryButton2.topAnchor.constraint(equalTo: secondaryButton1.bottomAnchor, constant: 0),
            
            // Copied label - right side
            copiedLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            copiedLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            copiedLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])
        
        self.contentView = contentView
    }
    
    private func setupActions() {
        primaryButton.target = self
        primaryButton.action = #selector(copyPrimary)
        
        secondaryButton1.target = self
        secondaryButton1.action = #selector(copySecondary1)
        
        secondaryButton2.target = self
        secondaryButton2.action = #selector(copySecondary2)
    }
    
    // MARK: - Button Order Management
    
    private func updateButtonOrder() {
        let preferred = ColorPickerConfig.shared.preferredFormat
        let allFormats = ColorFormat.allCases
        
        // Find formats that are not the preferred one
        let otherFormats = allFormats.filter { $0 != preferred }
        
        currentFormats = (
            primary: preferred,
            secondary1: otherFormats[0],
            secondary2: otherFormats[1]
        )
        
        // Update tooltips
        primaryButton.toolTip = "Click to copy \(preferred.rawValue) value (default)"
        secondaryButton1.toolTip = "Click to copy \(otherFormats[0].rawValue) value"
        secondaryButton2.toolTip = "Click to copy \(otherFormats[1].rawValue) value"
    }
    
    // MARK: - Actions
    
    @objc private func copyPrimary() {
        guard let info = currentColorInfo else { return }
        copyFormat(currentFormats.primary, from: info)
    }
    
    @objc private func copySecondary1() {
        guard let info = currentColorInfo else { return }
        copyFormat(currentFormats.secondary1, from: info, saveAsPreferred: true)
    }
    
    @objc private func copySecondary2() {
        guard let info = currentColorInfo else { return }
        copyFormat(currentFormats.secondary2, from: info, saveAsPreferred: true)
    }
    
    private func copyFormat(_ format: ColorFormat, from info: ColorInfo, saveAsPreferred: Bool = false) {
        let value: String
        
        switch format {
        case .hex:
            value = info.hex
        case .rgb:
            value = info.rgb
        case .hsl:
            value = info.hsl
        }
        
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        
        // Save as preferred if user clicked a secondary format
        if saveAsPreferred {
            ColorPickerConfig.shared.preferredFormat = format
            updateButtonOrder()
            // Update display to show new order
            if let info = currentColorInfo {
                updateButtonTitles(with: info)
            }
        }
        
        // Show copied indicator
        showCopiedIndicator(format: format.rawValue)
    }
    
    private func showCopiedIndicator(format: String) {
        // Cancel any existing timer
        hideCopiedTimer?.invalidate()
        
        // Show the copied message
        copiedLabel.stringValue = "\(format) copied!"
        copiedLabel.isHidden = false
        
        // Hide after 2 seconds
        hideCopiedTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.copiedLabel.stringValue = ""
        }
    }
    
    // MARK: - Public Methods
    
    /// Update the HUD with new color information
    func setColorInfo(_ info: ColorInfo) {
        currentColorInfo = info
        updateButtonOrder()
        updateButtonTitles(with: info)
        colorSwatch.layer?.backgroundColor = info.color.cgColor
        
        // Show initial "Copied!" for preferred format (auto-copied on pick)
        showCopiedIndicator(format: ColorPickerConfig.shared.preferredFormat.rawValue)
    }
    
    private func updateButtonTitles(with info: ColorInfo) {
        switch currentFormats.primary {
        case .hex:
            primaryButton.title = info.hex
        case .rgb:
            primaryButton.title = info.rgb
        case .hsl:
            primaryButton.title = info.hsl
        }
        
        switch currentFormats.secondary1 {
        case .hex:
            secondaryButton1.title = info.hex
        case .rgb:
            secondaryButton1.title = info.rgb
        case .hsl:
            secondaryButton1.title = info.hsl
        }
        
        switch currentFormats.secondary2 {
        case .hex:
            secondaryButton2.title = info.hex
        case .rgb:
            secondaryButton2.title = info.rgb
        case .hsl:
            secondaryButton2.title = info.hsl
        }
    }
    
    /// Get the value for the preferred format (used for auto-copy)
    func getPreferredFormatValue(from info: ColorInfo) -> String {
        switch ColorPickerConfig.shared.preferredFormat {
        case .hex:
            return info.hex
        case .rgb:
            return info.rgb
        case .hsl:
            return info.hsl
        }
    }
    
    /// Show the HUD at the center of the screen, then auto-dismiss after delay
    func show(autoDismiss: Bool = true) {
        // Position at center of screen, slightly above center
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.midY + 50
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        
        // Auto dismiss after 4 seconds
        if autoDismiss {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                self?.orderOut(nil)
            }
        }
    }
    
    // MARK: - NSPanel Overrides
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
