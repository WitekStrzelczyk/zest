import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Preferences"
        window.center()
        window.isReleasedWhenClosed = false

        let preferencesView = PreferencesView()
        window.contentView = NSHostingView(rootView: preferencesView)

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct PreferencesView: View {
    @ObservedObject private var preferences = PreferencesManager.shared

    var body: some View {
        TabView {
            GeneralPreferencesView(preferences: preferences)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            SearchPreferencesView(preferences: preferences)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            AppearancePreferencesView(preferences: preferences)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
        }
        .frame(width: 500, height: 350)
    }
}

struct GeneralPreferencesView: View {
    @ObservedObject var preferences: PreferencesManager

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $preferences.launchAtLogin)
                    .onChange(of: preferences.launchAtLogin) { _, newValue in
                        LaunchAtLoginService.shared.enabled = newValue
                    }
            }

            Section("Global Hotkey") {
                Text("Current: Cmd+Space")
                    .foregroundColor(.secondary)
            }

            Section("Indexed Directories") {
                ForEach(preferences.indexedDirectories, id: \.self) { directory in
                    Text(directory)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct SearchPreferencesView: View {
    @ObservedObject var preferences: PreferencesManager

    var body: some View {
        Form {
            Section {
                Stepper(
                    "Search Results: \(preferences.searchResultsLimit)",
                    value: $preferences.searchResultsLimit,
                    in: 10...80,
                    step: 10
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AppearancePreferencesView: View {
    @ObservedObject var preferences: PreferencesManager

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $preferences.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
