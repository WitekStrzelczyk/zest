import AppKit
import Foundation

// MARK: - Plugin Protocol

/// Protocol that all Zest plugins must conform to
protocol ZestPlugin {
    /// Unique identifier for the plugin
    static var pluginID: String { get }
    
    /// Human-readable name of the plugin
    static var pluginName: String { get }
    
    /// Keywords that should trigger this plugin in search
    static var searchKeywords: [String] { get }
    
    /// Search for results matching the query
    func search(query: String) -> [SearchResult]
    
    /// Called when the plugin is registered
    func onRegister()
}

// MARK: - Color Picker Plugin

/// Color Picker plugin - allows users to pick colors from anywhere on screen
final class ColorPickerPlugin: ZestPlugin {
    // MARK: - Plugin Info
    
    static let pluginID = "com.zest.plugin.colorpicker"
    static let pluginName = "Color Picker"
    static let searchKeywords = ["color", "picker", "pick color", "color picker", "eyedropper", "sampler", "eye dropper"]
    
    // MARK: - Services
    
    private let service: ColorPickerService
    private var hud: ColorResultHUD?
    
    // MARK: - Singleton
    
    static let shared = ColorPickerPlugin()
    
    private init() {
        self.service = ColorPickerService.shared
    }
    
    // MARK: - ZestPlugin Protocol
    
    func onRegister() {
        // Listen for color picked notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleColorPicked(_:)),
            name: .zestColorPicked,
            object: nil
        )
    }
    
    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()
        
        guard !lowercasedQuery.isEmpty else { return [] }
        
        // Check if query matches any keywords
        let matchesKeyword = Self.searchKeywords.contains { keyword in
            keyword.contains(lowercasedQuery) || lowercasedQuery.contains(keyword)
        }
        
        guard matchesKeyword else { return [] }
        
        let score = SearchScoreCalculator.shared.calculateScore(
            query: lowercasedQuery,
            title: "Pick Color",
            category: .action
        )
        
        return [
            SearchResult(
                title: "Pick Color",
                subtitle: "Pick a color from anywhere on screen",
                icon: NSImage(systemSymbolName: "eyedropper", accessibilityDescription: "Color Picker"),
                category: .action,
                action: { [weak self] in
                    self?.startColorPicker()
                },
                score: max(score, 50)
            )
        ]
    }
    
    // MARK: - Private Methods
    
    private func startColorPicker() {
        // Post notification to dismiss command palette
        NotificationCenter.default.post(name: .zestDismissCommandPalette, object: nil)
        
        // Hide cursor since the eyedropper shows the pick location
        NSCursor.hide()
        
        // Small delay to let palette dismiss before showing color sampler
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showColorSampler()
        }
    }
    
    @MainActor
    private func showColorSampler() {
        service.pickColor { [weak self] info in
            // Restore cursor when done
            NSCursor.unhide()
            
            guard let self, let info else { return }
            
            // Get preferred format value for auto-copy
            let preferredValue: String
            switch ColorPickerConfig.shared.preferredFormat {
            case .hex:
                preferredValue = info.hex
            case .rgb:
                preferredValue = info.rgb
            case .hsl:
                preferredValue = info.hsl
            }
            
            // Copy preferred format to clipboard
            self.service.copyToClipboard(preferredValue)
            
            // Post notification with color info for UI display
            NotificationCenter.default.post(
                name: .zestColorPicked,
                object: nil,
                userInfo: [
                    "hex": info.hex,
                    "rgb": info.rgb,
                    "hsl": info.hsl,
                    "color": info.color
                ]
            )
        }
    }
    
    @objc private func handleColorPicked(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let hex = userInfo["hex"] as? String,
              let rgb = userInfo["rgb"] as? String,
              let hsl = userInfo["hsl"] as? String,
              let color = userInfo["color"] as? NSColor else { return }
        
        let info = ColorInfo(hex: hex, rgb: rgb, hsl: hsl, color: color)
        
        DispatchQueue.main.async { [weak self] in
            self?.showHUD(with: info)
        }
    }
    
    @MainActor
    private func showHUD(with info: ColorInfo) {
        if hud == nil {
            hud = ColorResultHUD()
        }
        hud?.setColorInfo(info)
        hud?.show()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when a color is picked (contains hex, rgb, hsl, color in userInfo)
    static let zestColorPicked = Notification.Name("zestColorPicked")
    
    /// Posted to request command palette dismissal
    static let zestDismissCommandPalette = Notification.Name("zestDismissCommandPalette")
}
