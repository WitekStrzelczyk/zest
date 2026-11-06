import AppKit
import Foundation

struct SystemSettingsPage {
    let title: String
    let section: String?
    let pageName: String
    let pane: String
    let keywords: [String]

    var path: String {
        let place = section.map { "\($0) › \(pageName)" } ?? pageName
        return "System Settings › \(place)"
    }

    var url: URL? { URL(string: "x-apple.systempreferences:\(pane)") }

    init(_ title: String, in section: String? = nil, page: String? = nil, pane: String, keywords: [String] = []) {
        self.title = title
        self.section = section
        self.pageName = page ?? title
        self.pane = pane
        self.keywords = keywords
    }
}

final class SystemSettingsSearch: SearchTool {
    static let shared = SystemSettingsSearch()

    private static let settingsAppPath = "/System/Applications/System Settings.app"
    private static let icon = IconCache.shared.renderedIcon(for: settingsAppPath)
    private static let minimumQueryLength = 3

    static let pages: [SystemSettingsPage] = [
        SystemSettingsPage(
            "Wi-Fi",
            pane: "com.apple.wifi-settings-extension",
            keywords: ["wifi", "wireless", "internet"]
        ),
        SystemSettingsPage(
            "Bluetooth",
            pane: "com.apple.BluetoothSettings",
            keywords: ["airpods", "headphones", "pair"]
        ),
        SystemSettingsPage(
            "Network",
            pane: "com.apple.Network-Settings.extension",
            keywords: ["ethernet", "proxy", "dns", "firewall"]
        ),
        SystemSettingsPage("VPN", pane: "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension"),
        SystemSettingsPage(
            "Battery",
            pane: "com.apple.Battery-Settings.extension",
            keywords: ["energy", "power", "low power mode", "charging"]
        ),
        SystemSettingsPage("General", pane: "com.apple.systempreferences.GeneralSettings"),
        SystemSettingsPage(
            "About This Mac",
            in: "General",
            page: "About",
            pane: "com.apple.SystemProfiler.AboutExtension",
            keywords: ["serial number", "model", "specs"]
        ),
        SystemSettingsPage(
            "Check for Software Updates",
            in: "General",
            page: "Software Update",
            pane: "com.apple.Software-Update-Settings.extension",
            keywords: ["upgrade", "macos", "install"]
        ),
        SystemSettingsPage(
            "Software Update",
            in: "General",
            pane: "com.apple.Software-Update-Settings.extension",
            keywords: ["automatic updates", "beta"]
        ),
        SystemSettingsPage(
            "Storage",
            in: "General",
            pane: "com.apple.settings.Storage",
            keywords: ["disk space", "free space"]
        ),
        SystemSettingsPage(
            "AirDrop & Handoff",
            in: "General",
            pane: "com.apple.AirDrop-Handoff-Settings.extension",
            keywords: ["continuity"]
        ),
        SystemSettingsPage(
            "Login Items & Extensions",
            in: "General",
            pane: "com.apple.LoginItems-Settings.extension",
            keywords: ["startup", "launch at login"]
        ),
        SystemSettingsPage(
            "Language & Region",
            in: "General",
            pane: "com.apple.Localization-Settings.extension",
            keywords: ["locale", "format"]
        ),
        SystemSettingsPage(
            "Date & Time",
            in: "General",
            pane: "com.apple.Date-Time-Settings.extension",
            keywords: ["clock", "time zone", "timezone"]
        ),
        SystemSettingsPage(
            "Sharing",
            in: "General",
            pane: "com.apple.Sharing-Settings.extension",
            keywords: ["screen sharing", "file sharing", "remote login", "ssh"]
        ),
        SystemSettingsPage(
            "Time Machine",
            in: "General",
            pane: "com.apple.Time-Machine-Settings.extension",
            keywords: ["backup"]
        ),
        SystemSettingsPage(
            "Transfer or Reset",
            in: "General",
            pane: "com.apple.Transfer-Reset-Settings.extension",
            keywords: ["erase"]
        ),
        SystemSettingsPage(
            "Startup Disk",
            in: "General",
            pane: "com.apple.Startup-Disk-Settings.extension",
            keywords: ["boot"]
        ),
        SystemSettingsPage(
            "Device Management",
            in: "General",
            pane: "com.apple.Profiles-Settings.extension",
            keywords: ["profiles", "mdm"]
        ),
        SystemSettingsPage(
            "Accessibility",
            pane: "com.apple.Accessibility-Settings.extension",
            keywords: ["voiceover", "zoom", "reduce motion"]
        ),
        SystemSettingsPage(
            "Appearance",
            pane: "com.apple.Appearance-Settings.extension",
            keywords: ["dark mode", "light mode", "accent color", "theme"]
        ),
        SystemSettingsPage(
            "Control Center",
            pane: "com.apple.ControlCenter-Settings.extension",
            keywords: ["menu bar"]
        ),
        SystemSettingsPage(
            "Desktop & Dock",
            pane: "com.apple.Desktop-Settings.extension",
            keywords: ["mission control", "stage manager", "hot corners"]
        ),
        SystemSettingsPage(
            "Displays",
            pane: "com.apple.Displays-Settings.extension",
            keywords: ["resolution", "brightness", "night shift", "monitor"]
        ),
        SystemSettingsPage("Spotlight", pane: "com.apple.Spotlight-Settings.extension"),
        SystemSettingsPage("Siri", pane: "com.apple.Siri-Settings.extension"),
        SystemSettingsPage("Wallpaper", pane: "com.apple.Wallpaper-Settings.extension", keywords: ["background"]),
        SystemSettingsPage(
            "Notifications",
            pane: "com.apple.Notifications-Settings.extension",
            keywords: ["alerts", "banners"]
        ),
        SystemSettingsPage(
            "Sound",
            pane: "com.apple.Sound-Settings.extension",
            keywords: ["volume", "output", "input", "microphone"]
        ),
        SystemSettingsPage("Focus", pane: "com.apple.Focus-Settings.extension", keywords: ["do not disturb", "dnd"]),
        SystemSettingsPage("Screen Time", pane: "com.apple.Screen-Time-Settings.extension", keywords: ["app limits"]),
        SystemSettingsPage(
            "Lock Screen",
            pane: "com.apple.Lock-Screen-Settings.extension",
            keywords: ["screen saver", "sleep"]
        ),
        SystemSettingsPage(
            "Privacy & Security",
            pane: "com.apple.settings.PrivacySecurity.extension",
            keywords: ["permissions", "filevault", "gatekeeper"]
        ),
        SystemSettingsPage(
            "Touch ID & Password",
            pane: "com.apple.Touch-ID-Settings.extension",
            keywords: ["fingerprint"]
        ),
        SystemSettingsPage(
            "Users & Groups",
            pane: "com.apple.Users-Groups-Settings.extension",
            keywords: ["accounts", "guest"]
        ),
        SystemSettingsPage(
            "Apple Account",
            pane: "com.apple.systempreferences.AppleIDSettings",
            keywords: ["apple id", "icloud"]
        ),
        SystemSettingsPage("Family", pane: "com.apple.Family-Settings.extension"),
        SystemSettingsPage(
            "Internet Accounts",
            pane: "com.apple.Internet-Accounts-Settings.extension",
            keywords: ["mail accounts"]
        ),
        SystemSettingsPage("Game Center", pane: "com.apple.Game-Center-Settings.extension"),
        SystemSettingsPage("Game Controllers", pane: "com.apple.Game-Controller-Settings.extension"),
        SystemSettingsPage("Wallet & Apple Pay", pane: "com.apple.WalletSettingsExtension"),
        SystemSettingsPage(
            "Keyboard",
            pane: "com.apple.Keyboard-Settings.extension",
            keywords: ["shortcuts", "input sources", "dictation", "key repeat"]
        ),
        SystemSettingsPage("Mouse", pane: "com.apple.Mouse-Settings.extension", keywords: ["scrolling"]),
        SystemSettingsPage(
            "Trackpad",
            pane: "com.apple.Trackpad-Settings.extension",
            keywords: ["gestures", "tap to click"]
        ),
        SystemSettingsPage(
            "Printers & Scanners",
            pane: "com.apple.Print-Scan-Settings.extension",
            keywords: ["printer", "scanner"]
        ),
    ]

    private init() {}

    var name: String { "System Settings" }

    func search(_ context: QueryContext) -> [SearchResult] {
        let query = Self.simplified(context.normalized)
        guard query.count >= Self.minimumQueryLength else { return [] }

        return Self.pages.compactMap { page in
            guard Self.matches(query, page) else { return nil }
            return SearchResult(
                title: page.title,
                subtitle: page.path,
                icon: Self.icon,
                category: .settings,
                action: { Self.open(page) },
                score: Self.score(query, page)
            )
        }
    }

    private static func matches(_ query: String, _ page: SystemSettingsPage) -> Bool {
        ([page.title, page.pageName] + page.keywords).contains { term in
            " \(simplified(term))".contains(" \(query)")
        }
    }

    private static func score(_ query: String, _ page: SystemSettingsPage) -> Int {
        let calculator = SearchScoreCalculator.shared
        return max(calculator.calculateScore(query: query, title: page.title, category: .settings), 100)
    }

    private static func simplified(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func open(_ page: SystemSettingsPage) {
        guard let url = page.url else { return }
        NSWorkspace.shared.open(url)
    }
}
