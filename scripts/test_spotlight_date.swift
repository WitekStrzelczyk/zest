#!/usr/bin/env swift

import Foundation
import AppKit

print("=== Spotlight Date Query Test ===\n")

// Test different date query formats
let queries: [(String, String)] = [
    ("Today (using $time.today)", "kMDItemContentModificationDate >= $time.today"),
    ("Last 24h (using $time.today(-1d))", "kMDItemContentModificationDate >= $time.today(-1d)"),
    ("Last 24h (using $time.now(-24h))", "kMDItemContentModificationDate >= $time.now(-24h)"),
]

var currentQueryIndex = 0

func runNextQuery() {
    guard currentQueryIndex < queries.count else {
        print("=== Test Complete ===")
        CFRunLoopStop(CFRunLoopGetCurrent())
        return
    }
    
    let (name, queryString) = queries[currentQueryIndex]
    currentQueryIndex += 1
    
    print("Testing: \(name)")
    print("  Query: \(queryString)")
    
    let query = NSMetadataQuery()
    query.searchScopes = [NSMetadataQueryUserHomeScope]
    
    guard let predicate = NSPredicate(fromMetadataQueryString: queryString) else {
        print("  ERROR: Failed to create predicate\n")
        runNextQuery()
        return
    }
    
    print("  Predicate: \(predicate.predicateFormat)")
    
    query.predicate = predicate
    
    var finished = false
    var observer: NSObjectProtocol?
    
    observer = NotificationCenter.default.addObserver(
        forName: NSNotification.Name.NSMetadataQueryDidFinishGathering,
        object: query,
        queue: .main
    ) { _ in
        guard !finished else { return }
        finished = true
        query.disableUpdates()
        
        let count = query.resultCount
        print("  Results: \(count) files")
        
        if count > 0 {
            for i in 0..<min(5, count) {
                if let item = query.result(at: i) as? NSMetadataItem,
                   let url = item.value(forAttribute: NSMetadataItemPathKey) as? URL {
                    print("    - \(url.lastPathComponent)")
                }
            }
            if count > 5 {
                print("    ... and \(count - 5) more")
            }
        }
        
        query.stop()
        if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
        }
        print("")
        
        // Run next query after a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            runNextQuery()
        }
    }
    
    query.start()
    
    // Timeout after 5 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        if !finished {
            finished = true
            print("  TIMEOUT after 5 seconds")
            query.stop()
            if let obs = observer {
                NotificationCenter.default.removeObserver(obs)
            }
            print("")
            runNextQuery()
        }
    }
}

// Start the first query
runNextQuery()

// Keep the run loop alive
CFRunLoopRun()
