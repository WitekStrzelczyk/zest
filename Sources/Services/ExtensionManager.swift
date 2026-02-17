import Foundation

/// Represents an extension command
struct ExtensionCommand: Identifiable, Hashable {
    let id: String
    let name: String
    let keywords: [String]
    let action: () -> Void

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ExtensionCommand, rhs: ExtensionCommand) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents an installed extension
struct Extension: Identifiable, Hashable {
    let id: String
    let name: String
    let version: String
    let commands: [ExtensionCommand]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Extension, rhs: Extension) -> Bool {
        lhs.id == rhs.id
    }
}

/// Protocol for extensions to conform to
protocol ZestExtensionProtocol {
    var id: String { get }
    var name: String { get }
    var version: String { get }
    func getCommands() -> [ExtensionCommand]
}

/// Manages extension loading and execution
final class ExtensionManager {
    static let shared: ExtensionManager = .init()

    private var loadedExtensions: [Extension] = []
    private let extensionsDirectory: URL

    private init() {
        // Set up extensions directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        extensionsDirectory = appSupport.appendingPathComponent("Zest/Extensions", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: extensionsDirectory, withIntermediateDirectories: true)

        // Load built-in extensions
        loadBuiltInExtensions()
    }

    // MARK: - Public Methods

    /// Get all loaded extensions
    func getAllExtensions() -> [Extension] {
        loadedExtensions
    }

    /// Get all commands from all extensions
    func getAllCommands() -> [ExtensionCommand] {
        loadedExtensions.flatMap(\.commands)
    }

    /// Search commands across all extensions
    func searchCommands(query: String) -> [ExtensionCommand] {
        guard !query.isEmpty else { return getAllCommands() }

        let lowercasedQuery = query.lowercased()
        return getAllCommands().filter { command in
            command.name.lowercased().contains(lowercasedQuery) ||
                command.keywords.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    /// Load extension from bundle
    func loadExtension(from bundleURL: URL) -> Extension? {
        guard let bundle = Bundle(url: bundleURL) else {
            print("Failed to load bundle from \(bundleURL)")
            return nil
        }

        guard let principalClass = bundle.principalClass as? NSObject.Type else {
            print("Failed to get principal class from bundle")
            return nil
        }

        // Try to create extension instance
        guard let extensionInstance = principalClass.init() as? ZestExtensionProtocol else {
            print("Bundle principal class doesn't conform to ZestExtensionProtocol")
            return nil
        }

        let commands = extensionInstance.getCommands()
        let extensionModel = Extension(
            id: extensionInstance.id,
            name: extensionInstance.name,
            version: extensionInstance.version,
            commands: commands
        )

        loadedExtensions.append(extensionModel)
        return extensionModel
    }

    /// Uninstall extension
    func uninstallExtension(id: String) -> Bool {
        loadedExtensions.removeAll { $0.id == id }
        return true
    }

    /// Execute extension command
    func executeCommand(id: String) -> Bool {
        guard let command = getAllCommands().first(where: { $0.id == id }) else {
            print("Command not found: \(id)")
            return false
        }

        command.action()
        return true
    }

    // MARK: - Private Methods

    private func loadBuiltInExtensions() {
        // Load extensions from the extensions directory
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: extensionsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for url in contents where url.pathExtension == "bundle" {
            _ = loadExtension(from: url)
        }

        // Add any built-in extensions here
        // For now, we have no built-in extensions
    }
}
