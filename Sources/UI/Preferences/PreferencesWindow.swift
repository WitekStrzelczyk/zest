import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PreferencesWindowController()
    static var showsOnScreen = true

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Preferences"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.minSize = NSSize(width: 760, height: 480)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PreferencesView())
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        guard Self.showsOnScreen else {
            window?.alphaValue = 0
            window?.ignoresMouseEvents = true
            window?.orderFrontRegardless()
            return
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func windowWillClose(_: Notification) {
        guard Self.showsOnScreen else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}

enum PreferencesSection: CaseIterable, Identifiable {
    case general
    case search
    case appearance

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .search: "Search"
        case .appearance: "Appearance"
        }
    }

    var symbol: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .search: "magnifyingglass"
        case .appearance: "paintpalette"
        }
    }

    var keywords: [String] {
        switch self {
        case .general: ["launch at login", "startup", "open zest", "shortcut", "hotkey", "keyboard"]
        case .search: ["results shown", "results", "limit", "indexed directories", "folders", "files"]
        case .appearance: ["appearance", "theme", "dark", "light", "system", "colors"]
        }
    }

    func matches(_ query: String) -> Bool {
        title.lowercased().contains(query) || keywords.contains { $0.contains(query) }
    }
}

final class PreferencesNavigation: ObservableObject {
    @Published var section: PreferencesSection = .general
    @Published var query = "" {
        didSet { openFirstMatchIfHidden() }
    }

    var visibleSections: [PreferencesSection] {
        let term = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return PreferencesSection.allCases }
        return PreferencesSection.allCases.filter { $0.matches(term) }
    }

    private func openFirstMatchIfHidden() {
        guard let first = visibleSections.first, !visibleSections.contains(section) else { return }
        section = first
    }
}

private enum Tone {
    static let content = Color(nsColor: AppStyle.Palette.backgroundBottom)
    static let sidebar = Color(nsColor: AppStyle.Palette.sidebar)
    static let card = Color(nsColor: AppStyle.Palette.surface)
    static let hairline = Color(nsColor: AppStyle.Palette.hairline)
    static let selected = Color(nsColor: AppStyle.Palette.rowSelectedFill)
    static let primary = Color(nsColor: AppStyle.Palette.primaryText)
    static let secondary = Color(nsColor: AppStyle.Palette.secondaryText)
    static let tertiary = Color(nsColor: AppStyle.Palette.tertiaryText)
}

struct PreferencesView: View {
    @ObservedObject private var preferences = PreferencesManager.shared
    @ObservedObject private var navigation = PreferencesNavigation()

    var body: some View {
        HStack(spacing: 0) {
            PreferencesSidebar(
                selection: $navigation.section,
                query: $navigation.query,
                sections: navigation.visibleSections
            )
                .frame(width: 232)
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text(navigation.section.title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Tone.primary)
                    content
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, 48)
                .padding(.top, 60)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            .background(Tone.content)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Tone.hairline))
            .padding([.top, .trailing, .bottom], 8)
        }
        .background(Tone.sidebar)
        .ignoresSafeArea()
        .frame(minWidth: 760, minHeight: 480)
    }

    @ViewBuilder
    private var content: some View {
        switch navigation.section {
        case .general: GeneralPreferencesView(preferences: preferences)
        case .search: SearchPreferencesView(preferences: preferences)
        case .appearance: AppearancePreferencesView(preferences: preferences)
        }
    }
}

struct PreferencesSidebar: View {
    @Binding var selection: PreferencesSection
    @Binding var query: String
    let sections: [PreferencesSection]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SettingsSearchField(query: $query)
                .padding(.bottom, 14)
            Text("Settings")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tone.tertiary)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            if sections.isEmpty {
                Text("No settings match")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Tone.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }
            ForEach(sections) { section in
                SidebarRow(section: section, isSelected: section == selection) {
                    selection = section
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 56)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct SettingsSearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Tone.tertiary)
            TextField("Search settings", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Tone.primary)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Tone.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Tone.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Tone.hairline))
    }
}

struct SidebarRow: View {
    let section: PreferencesSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.symbol)
                    .font(.system(size: 13))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Tone.primary : Tone.secondary)
                Text(section.title)
                    .font(.system(size: 13.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(Tone.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(isSelected ? Tone.selected : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tone.primary)
            VStack(spacing: 0) {
                content
            }
            .background(Tone.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Tone.hairline))
        }
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Tone.primary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Tone.secondary)
            }
            Spacer()
            control
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

struct KeycapLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Tone.secondary)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Tone.selected, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Tone.hairline))
    }
}

struct PillPicker<Value: Hashable>: View {
    let options: [Value]
    let label: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button { selection = option } label: {
                    Text(label(option))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(isSelected ? Tone.content : Tone.primary)
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(isSelected ? Tone.primary : Tone.card, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? .clear : Tone.hairline))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct GeneralPreferencesView: View {
    @ObservedObject var preferences: PreferencesManager

    var body: some View {
        SettingsGroup(title: "Startup") {
            SettingsRow(title: "Launch at login", detail: "Open Zest in the menu bar when you log in.") {
                Toggle("", isOn: $preferences.launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .onChange(of: preferences.launchAtLogin) { _, newValue in
                        LaunchAtLoginService.shared.enabled = newValue
                    }
            }
        }
        SettingsGroup(title: "Shortcut") {
            SettingsRow(title: "Open Zest", detail: "Shows or hides the palette from any app.") {
                HStack(spacing: 4) {
                    KeycapLabel(text: "⌘")
                    KeycapLabel(text: "Space")
                }
            }
        }
    }
}

struct SearchPreferencesView: View {
    @ObservedObject var preferences: PreferencesManager

    var body: some View {
        SettingsGroup(title: "Results") {
            SettingsRow(title: "Results shown", detail: "The most results the palette lists for one search.") {
                HStack(spacing: 10) {
                    Text("\(preferences.searchResultsLimit)")
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(Tone.primary)
                    Stepper("", value: $preferences.searchResultsLimit, in: 10...80, step: 10)
                        .labelsHidden()
                }
            }
        }
        SettingsGroup(title: "Indexed directories") {
            ForEach(Array(preferences.indexedDirectories.enumerated()), id: \.element) { index, directory in
                if index > 0 {
                    Rectangle().fill(Tone.hairline).frame(height: 1)
                }
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(Tone.secondary)
                    Text(directory)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(Tone.secondary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
    }
}

struct AppearancePreferencesView: View {
    @ObservedObject var preferences: PreferencesManager

    var body: some View {
        SettingsGroup(title: "Theme") {
            SettingsRow(title: "Appearance", detail: "System follows your Mac's light or dark setting.") {
                PillPicker(options: AppTheme.allCases, label: \.displayName, selection: $preferences.theme)
            }
        }
    }
}
