import AppKit
import Foundation

final class ColorPickerPlugin: SearchTool {
    static let searchKeywords = ["color", "picker", "pick color", "eyedropper", "sampler"]

    private let service: ColorPickerService
    private var hud: ColorResultHUD?

    static let shared = ColorPickerPlugin()

    private init() {
        service = ColorPickerService.shared
    }

    func onRegister() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleColorPicked(_:)),
            name: .zestColorPicked,
            object: nil
        )
    }

    var name: String { "Color Picker" }

    func search(_ context: QueryContext) -> [SearchResult] {
        search(query: context.normalized)
    }

    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()

        guard !lowercasedQuery.isEmpty else { return [] }

        guard matchesKeyword(lowercasedQuery, in: Self.searchKeywords) else { return [] }

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
            ),
        ]
    }

    private func startColorPicker() {
        NotificationCenter.default.post(name: .zestDismissCommandPalette, object: nil)

        NSCursor.hide()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showColorSampler()
        }
    }

    @MainActor
    private func showColorSampler() {
        service.pickColor { [weak self] info in
            NSCursor.unhide()

            guard let self, let info else { return }

            let preferredValue: String = switch ColorPickerConfig.shared.preferredFormat {
            case .hex:
                info.hex
            case .rgb:
                info.rgb
            case .hsl:
                info.hsl
            }

            service.copyToClipboard(preferredValue)

            NotificationCenter.default.post(
                name: .zestColorPicked,
                object: nil,
                userInfo: [
                    "hex": info.hex,
                    "rgb": info.rgb,
                    "hsl": info.hsl,
                    "color": info.color,
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

extension Notification.Name {
    static let zestColorPicked = Notification.Name("zestColorPicked")

    static let zestDismissCommandPalette = Notification.Name("zestDismissCommandPalette")
}
