import AppKit
import Foundation

final class FileSearchService {
    static let shared: FileSearchService = .init()

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
        ".build"
    ]

    /// Maximum time to wait for query (in seconds)
    /// This prevents the app from freezing if Spotlight hangs
    let searchTimeout: TimeInterval = 2.0

    /// Flag to force use of mdfind (useful for testing)
    var forceMdfind: Bool = false

    /// Configured search scopes for NSMetadataQuery
    /// Returns the paths that will be searched
    var configuredSearchScopes: [String] {
        buildSearchScopes().compactMap { scope -> String? in
            if let url = scope as? URL {
                return url.path
            }
            return nil
        }
    }

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

    /// Build search scopes for NSMetadataQuery
    /// Returns URLs for Documents, Downloads, Desktop, and Home directories
    private func buildSearchScopes() -> [Any] {
        var scopes: [Any] = []
        let fileManager = FileManager.default

        // Add Documents directory
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            scopes.append(documentsURL)
        }

        // Add Downloads directory
        if let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            scopes.append(downloadsURL)
        }

        // Add Desktop directory
        if let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first {
            scopes.append(desktopURL)
        }

        // Add user home directory as fallback
        if let homeURL = fileManager.homeDirectoryForCurrentUser as URL? {
            scopes.append(homeURL)
        }

        return scopes
    }

    /// Synchronous search using native Spotlight APIs
    /// Uses NSMetadataQuery in the app, falls back to mdfind for reliability
    /// - Parameter query: The search query string
    /// - Parameter maxResults: Maximum number of results to return
    /// - Returns: Array of SearchResult objects, empty if timeout or error occurs
    func searchSync(query: String, maxResults: Int = 10) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        // First try NSMetadataQuery (native API, no shell process)
        // If it returns results quickly, use them
        if !forceMdfind {
            let urls = performNSMetadataQuery(query: query, maxResults: maxResults)
            if !urls.isEmpty {
                return buildSearchResults(from: urls, maxResults: maxResults)
            }
        }

        // Fall back to mdfind if NSMetadataQuery returns no results
        // This handles test environments where NSMetadataQuery may not work
        let paths = performMdfindQuery(query: query, maxResults: maxResults)
        return buildSearchResults(from: paths, maxResults: maxResults)
    }

    /// Perform search using NSMetadataQuery (native Spotlight API)
    /// Internal access for testing
    func performNSMetadataQuery(query: String, maxResults: Int) -> [URL] {
        let state = NSMetadataQueryState()
        let metadataQuery = configureMetadataQuery(query: query)

        setupQueryObservers(
            metadataQuery: metadataQuery,
            state: state,
            maxResults: maxResults
        )

        runQueryOnDedicatedThread(metadataQuery: metadataQuery, state: state)

        // Use a reasonable timeout for NSMetadataQuery (1 second)
        // NSMetadataQuery typically returns results within 50-200ms
        let queryTimeout: TimeInterval = 1.0
        let waitResult = state.semaphore.wait(timeout: .now() + queryTimeout)

        cleanupQuery(metadataQuery: metadataQuery, observers: state.observers)

        // Return collected results whether we timed out or completed
        // NSMetadataQuery may have collected partial results even on timeout
        if waitResult == .timedOut {
            // Return partial results if available
            return state.collectedURLs
        }
        return state.collectedURLs
    }

    /// Configure an NSMetadataQuery with search parameters
    private func configureMetadataQuery(query: String) -> NSMetadataQuery {
        let metadataQuery = NSMetadataQuery()
        // Use specific directory scopes instead of broad computer-wide search
        metadataQuery.searchScopes = buildSearchScopes()
        metadataQuery.predicate = NSPredicate(
            format: "kMDItemDisplayName CONTAINS[cd] %@", query
        )
        return metadataQuery
    }

    /// Setup notification observers for the metadata query
    private func setupQueryObservers(
        metadataQuery: NSMetadataQuery,
        state: NSMetadataQueryState,
        maxResults: Int
    ) {
        let notificationCenter = NotificationCenter.default

        let finishObserver = notificationCenter.addObserver(
            forName: NSNotification.Name.NSMetadataQueryDidFinishGathering,
            object: metadataQuery,
            queue: nil
        ) { _ in
            guard !state.completed else { return }
            state.completed = true
            self.collectResults(from: metadataQuery, into: state)
            state.semaphore.signal()
        }

        let updateObserver = notificationCenter.addObserver(
            forName: NSNotification.Name.NSMetadataQueryDidUpdate,
            object: metadataQuery,
            queue: nil
        ) { _ in
            guard !state.completed else { return }
            self.collectResults(from: metadataQuery, into: state)

            if state.collectedURLs.count >= maxResults * 3 {
                state.completed = true
                state.semaphore.signal()
            }
        }

        state.observers = [finishObserver, updateObserver]
    }

    /// Collect results from a metadata query into the state
    private func collectResults(from metadataQuery: NSMetadataQuery, into state: NSMetadataQueryState) {
        guard let results = metadataQuery.results as? [NSMetadataItem] else { return }
        for item in results {
            if let url = item.value(forAttribute: NSMetadataItemPathKey) as? URL {
                if !state.collectedURLs.contains(url) {
                    state.collectedURLs.append(url)
                }
            }
        }
    }

    /// Run the query on a dedicated thread with its own run loop
    private func runQueryOnDedicatedThread(metadataQuery: NSMetadataQuery, state: NSMetadataQueryState) {
        let queryThread = Thread {
            metadataQuery.start()
            let timeoutDate = Date(timeIntervalSinceNow: self.searchTimeout)
            while !state.completed, Date() < timeoutDate {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            }
            metadataQuery.stop()
        }
        queryThread.start()
    }

    /// Clean up query observers and stop the query
    private func cleanupQuery(metadataQuery: NSMetadataQuery, observers: [Any]) {
        let notificationCenter = NotificationCenter.default
        observers.forEach { notificationCenter.removeObserver($0) }
        metadataQuery.stop()
    }
}

/// State container for NSMetadataQuery execution
private class NSMetadataQueryState {
    let semaphore = DispatchSemaphore(value: 0)
    var collectedURLs: [URL] = []
    var completed = false
    var observers: [Any] = []
}

extension FileSearchService {

    /// Perform search using mdfind command-line tool (fallback)
    private func performMdfindQuery(query: String, maxResults: Int) -> [String] {
        var paths: [String] = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-name", query]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()

            let semaphore = DispatchSemaphore(value: 0)
            var didTimeout = false

            DispatchQueue.global().async {
                process.waitUntilExit()
                semaphore.signal()
            }

            let waitResult = semaphore.wait(timeout: .now() + searchTimeout)
            if waitResult == .timedOut {
                didTimeout = true
                process.terminate()
            }

            guard !didTimeout else { return [] }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                paths = Array(lines.prefix(maxResults * 2))
            }
        } catch {
            // mdfind failed
        }

        return paths
    }

    /// Build SearchResult array from URLs
    private func buildSearchResults(from urls: [URL], maxResults: Int) -> [SearchResult] {
        var results: [SearchResult] = []

        for url in urls {
            if results.count >= maxResults { break }

            let path = url.path
            if isPathInHiddenDirectory(path) { continue }

            let name = url.lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: path)

            results.append(SearchResult(
                title: name,
                subtitle: "File",
                icon: icon,
                action: { [path] in
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                },
                revealAction: { [path] in
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                },
                filePath: path
            ))
        }

        return results
    }

    /// Build SearchResult array from file paths
    private func buildSearchResults(from paths: [String], maxResults: Int) -> [SearchResult] {
        var results: [SearchResult] = []

        for path in paths {
            if results.count >= maxResults { break }

            if isPathInHiddenDirectory(path) { continue }

            let url = URL(fileURLWithPath: path)
            let name = url.lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: path)

            results.append(SearchResult(
                title: name,
                subtitle: "File",
                icon: icon,
                action: { [path] in
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                },
                revealAction: { [path] in
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                },
                filePath: path
            ))
        }

        return results
    }
}
