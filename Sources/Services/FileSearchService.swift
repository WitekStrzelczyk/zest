import AppKit
import Foundation

final class FileSearchService {
    static let shared: FileSearchService = .init()

    static var isDisabled = false

    private var latestQuery: String = ""
    private let queryLock = NSLock()

    private let hiddenDirectoryNames: Set<String> = [
        ".ssh", ".cache", ".local", ".config", ".Trash", ".DS_Store",
        ".git", "node_modules", "build", ".build",
    ]

    let searchTimeout: TimeInterval = 3.0
    private let cancellationCheckInterval: TimeInterval = 0.02

    private let queryQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private init() {}

    func isPathInHiddenDirectory(_ path: String) -> Bool {
        let components = path.components(separatedBy: "/")
        for component in components {
            if component.hasPrefix("."), component != ".Trash" { return true }
            if hiddenDirectoryNames.contains(component) { return true }
        }
        return false
    }

    func searchSync(query: String, maxResults: Int = 10, originalQuery: String? = nil) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        let q = originalQuery ?? query
        queryLock.lock()
        latestQuery = q
        queryLock.unlock()

        let predicate = NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@", query)
        return searchSync(predicate: predicate, maxResults: maxResults, originalQuery: q)
    }

    func searchSync(predicate: NSPredicate, maxResults: Int = 10, originalQuery: String? = nil) -> [SearchResult] {
        if let q = originalQuery {
            queryLock.lock()
            latestQuery = q
            queryLock.unlock()
        }

        let urls = performNSMetadataQuery(predicate: predicate, maxResults: maxResults, originalQuery: originalQuery)
        return buildSearchResults(from: urls, maxResults: maxResults)
    }

    func performNSMetadataQuery(predicate: NSPredicate, maxResults: Int, originalQuery: String? = nil) -> [URL] {
        guard !isAbandoned(originalQuery) else { return [] }

        let metadataQuery = NSMetadataQuery()
        let finished = DispatchSemaphore(value: 0)
        let nc = NotificationCenter.default
        var observers: [NSObjectProtocol] = []
        var collectedURLs: [URL] = []

        let collect = {
            metadataQuery.disableUpdates()
            let limit = min(metadataQuery.resultCount, maxResults * 2)
            collectedURLs = (0..<limit).compactMap { index in
                (metadataQuery.result(at: index) as? NSMetadataItem)?
                    .value(forAttribute: NSMetadataItemPathKey) as? String
            }.map { URL(fileURLWithPath: $0) }
            metadataQuery.enableUpdates()
        }

        queryQueue.addOperation { [queryQueue] in
            metadataQuery.operationQueue = queryQueue
            metadataQuery.searchScopes = [NSMetadataQueryIndexedLocalComputerScope, NSMetadataQueryUserHomeScope]
            metadataQuery.predicate = predicate
            metadataQuery.notificationBatchingInterval = 0.1
            metadataQuery.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemContentModificationDateKey, ascending: false)]
            observers = [
                nc.addObserver(forName: .NSMetadataQueryDidUpdate, object: metadataQuery, queue: queryQueue) { _ in
                    collect()
                    if collectedURLs.count >= maxResults { finished.signal() }
                },
                nc.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: queryQueue) { _ in
                    collect()
                    finished.signal()
                },
            ]
            if !metadataQuery.start() { finished.signal() }
        }

        let deadline = Date().addingTimeInterval(searchTimeout)
        var didFinish = false
        while !didFinish, Date() < deadline, !isAbandoned(originalQuery) {
            didFinish = finished.wait(timeout: .now() + cancellationCheckInterval) == .success
        }
        let abandoned = !didFinish && isAbandoned(originalQuery)

        let stop = BlockOperation {
            if !didFinish, !abandoned { collect() }
            metadataQuery.stop()
            observers.forEach { nc.removeObserver($0) }
        }
        queryQueue.addOperations([stop], waitUntilFinished: !abandoned)

        return abandoned ? [] : collectedURLs
    }

    private func isAbandoned(_ originalQuery: String?) -> Bool {
        guard !Task.isCancelled else { return true }
        guard let originalQuery else { return false }
        queryLock.lock()
        defer { queryLock.unlock() }
        return latestQuery != originalQuery
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
                icon: IconCache.shared.renderedIcon(for: path),
                category: .file,
                action: { NSWorkspace.shared.open(url) },
                revealAction: { NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "") },
                filePath: path,
                fileDetails: FileDetails(path: path)
            ))
        }
        return results
    }
}
