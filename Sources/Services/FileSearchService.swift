import AppKit
import Foundation

final class FileSearchService {
    static let shared: FileSearchService = .init()

    /// Flag to disable file search (useful for testing)
    static var isDisabled = false

    /// Tracks the latest query string to ignore outdated search results
    private var latestQuery: String = ""
    private let queryLock = NSLock()

    private let hiddenDirectoryNames: Set<String> = [
        ".ssh", ".cache", ".local", ".config", ".Trash", ".DS_Store",
        ".git", "node_modules", "build", ".build",
    ]

    /// Maximum time to wait for query (increased slightly for reliability)
    let searchTimeout: TimeInterval = 3.0

    private init() {}

    func isPathInHiddenDirectory(_ path: String) -> Bool {
        let components = path.components(separatedBy: "/")
        for component in components {
            if component.hasPrefix("."), component != ".Trash" { return true }
            if hiddenDirectoryNames.contains(component) { return true }
        }
        return false
    }

    /// Synchronous search using a query string
    func searchSync(query: String, maxResults: Int = 10, originalQuery: String? = nil) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        let q = originalQuery ?? query
        queryLock.lock()
        latestQuery = q
        queryLock.unlock()

        let predicate = NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@", query)
        return searchSync(predicate: predicate, maxResults: maxResults, originalQuery: q)
    }

    /// Synchronous search using a predicate
    func searchSync(predicate: NSPredicate, maxResults: Int = 10, originalQuery: String? = nil) -> [SearchResult] {
        if let q = originalQuery {
            queryLock.lock()
            latestQuery = q
            queryLock.unlock()
        }

        let urls = performNSMetadataQuery(predicate: predicate, maxResults: maxResults, originalQuery: originalQuery)
        return buildSearchResults(from: urls, maxResults: maxResults)
    }

    /// Perform search using NSMetadataQuery (native Spotlight API)
    /// Optimized for speed and consistency using both Updates and Gathering notifications.
    func performNSMetadataQuery(predicate: NSPredicate, maxResults: Int, originalQuery: String? = nil) -> [URL] {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. Pre-check: If this is an old query already, don't even start
        if let q = originalQuery {
            queryLock.lock()
            let isOutdated = (latestQuery != q)
            queryLock.unlock()
            if isOutdated { return [] }
        }

        let semaphore = DispatchSemaphore(value: 0)
        var collectedURLs: [URL] = []

        let metadataQuery = NSMetadataQuery()

        print("📁 FileSearchService: Starting native Spotlight query")

        // Notifications setup
        var observers: [NSObjectProtocol] = []
        let nc = NotificationCenter.default

        // Helper to collect results from query state
        let collect = {
            metadataQuery.disableUpdates()
            let count = metadataQuery.resultCount
            var urls: [URL] = []
            // ONLY collect up to maxResults to avoid blocking main thread with thousands of items
            let limit = min(count, maxResults * 2) // Small buffer for hidden directory filtering
            for i in 0..<limit {
                if let item = metadataQuery.result(at: i) as? NSMetadataItem,
                   let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
                {
                    urls.append(URL(fileURLWithPath: path))
                }
            }
            collectedURLs = urls
            metadataQuery.enableUpdates()
        }

        DispatchQueue.main.async {
            metadataQuery.searchScopes = [NSMetadataQueryIndexedLocalComputerScope, NSMetadataQueryUserHomeScope]
            metadataQuery.predicate = predicate
            metadataQuery.notificationBatchingInterval = 0.1 // Fast updates

            // Sort by modification date descending to find relevant (recent) files FIRST
            metadataQuery.sortDescriptors = [NSSortDescriptor(
                key: NSMetadataItemContentModificationDateKey,
                ascending: false
            )]

            // 1. Progress updates (for speed)
            let updateObs = nc
                .addObserver(forName: .NSMetadataQueryDidUpdate, object: metadataQuery, queue: .main) { _ in
                    collect()
                    if collectedURLs.count >= maxResults {
                        semaphore.signal()
                    }
                }

            // 2. Completion (for finality)
            let finishObs = nc.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: metadataQuery,
                queue: .main
            ) { _ in
                collect()
                semaphore.signal()
            }

            observers = [updateObs, finishObs]

            if !metadataQuery.start() {
                print("📁 FileSearchService: Failed to start query")
                semaphore.signal()
            }
        }

        // Wait for gathering to finish or timeout
        let waitResult = semaphore.wait(timeout: .now() + searchTimeout)

        // 2. Mid-check: If query changed while we were waiting, don't bother with polling or logging
        if let q = originalQuery {
            queryLock.lock()
            let isOutdated = (latestQuery != q)
            queryLock.unlock()
            if isOutdated {
                DispatchQueue.main.async {
                    metadataQuery.stop()
                    observers.forEach { nc.removeObserver($0) }
                }
                return []
            }
        }

        // Final safety check
        if waitResult == .timedOut || collectedURLs.isEmpty {
            DispatchQueue.main.sync {
                collect()
            }
        }

        // Cleanup
        DispatchQueue.main.sync {
            metadataQuery.stop()
            observers.forEach { nc.removeObserver($0) }
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let durStr = String(format: "%.3f", duration)
        print("📁 FileSearchService: Native search found \(collectedURLs.count) results in \(durStr)s")

        return collectedURLs
    }

    private func buildSearchResults(from urls: [URL], maxResults: Int) -> [SearchResult] {
        var results: [SearchResult] = []
        for url in urls {
            if results.count >= maxResults { break }
            let path = url.path
            if isPathInHiddenDirectory(path) || path.hasSuffix(".app") { continue }

            results.append(SearchResult(
                title: url.lastPathComponent,
                subtitle: "File",
                icon: NSWorkspace.shared.icon(forFile: path),
                category: .file,
                action: { NSWorkspace.shared.open(url) },
                revealAction: { NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "") },
                filePath: path
            ))
        }
        return results
    }
}
