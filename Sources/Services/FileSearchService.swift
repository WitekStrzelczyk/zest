import AppKit
import Foundation

final class FileSearchService {
    static let shared: FileSearchService = {
        let instance = FileSearchService()
        return instance
    }()

    /// List of hidden directories to exclude from search results (for privacy)
    private let hiddenDirectoryNames: Set<String> = [
        ".ssh",
        ".cache",
        ".local",
        ".config",
        ".Trash",
        ".DS_Store",
        // Build artifacts
        ".git",
        "node_modules",
        "build",
        ".build",
    ]

    private let searchScopes: [String] = [
        NSMetadataQueryLocalComputerScope,
        NSMetadataQueryUserHomeScope,
    ]

    /// Maximum time to wait for mdfind process (in seconds)
    /// This prevents the app from freezing if Spotlight hangs
    let searchTimeout: TimeInterval = 2.0

    private init() {}

    /// Check if a path is inside a hidden directory (for privacy filtering)
    func isPathInHiddenDirectory(_ path: String) -> Bool {
        let components = path.components(separatedBy: "/")

        // Check each directory component
        for component in components {
            // Check if component starts with "." (hidden file/directory)
            if component.hasPrefix("."), component != ".Trash" {
                return true
            }

            // Check against known hidden directory names (including build artifacts)
            if hiddenDirectoryNames.contains(component) {
                return true
            }
        }

        return false
    }

    /// Synchronous search using mdfind (Spotlight command-line)
    /// This gives us the same results as Spotlight
    /// - Parameter query: The search query string
    /// - Parameter maxResults: Maximum number of results to return
    /// - Returns: Array of SearchResult objects, empty if timeout or error occurs
    func searchSync(query: String, maxResults: Int = 10) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        var results: [SearchResult] = []

        // Use mdfind with -name flag (same as Spotlight)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-name", query]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()

            // Wait with timeout to prevent hanging the main thread
            let semaphore = DispatchSemaphore(value: 0)
            var didTimeout = false

            // Run wait in background thread
            DispatchQueue.global().async {
                process.waitUntilExit()
                semaphore.signal()
            }

            // Wait with timeout
            let waitResult = semaphore.wait(timeout: .now() + searchTimeout)
            if waitResult == .timedOut {
                didTimeout = true
                process.terminate()
            }

            // Only process results if we didn't timeout
            guard !didTimeout else {
                return []
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

                for path in lines.prefix(maxResults) {
                    // Skip files from hidden directories (privacy)
                    if isPathInHiddenDirectory(path) {
                        continue
                    }

                    let name = (path as NSString).lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: path)

                    results.append(SearchResult(
                        title: name,
                        subtitle: "File",
                        icon: icon,
                        action: {
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        },
                        revealAction: {
                            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                        }
                    ))
                }
            }
        } catch {
            // mdfind failed, return empty
        }

        return results
    }
}
