#!/usr/bin/env swift

import Foundation
import AppKit

print("=== Spotlight Time Syntax Test ===\n")

// 22 hours in seconds = 22 * 3600 = 79200
let tests: [String] = [
    "kMDItemContentModificationDate >= $time.now(-79200)",  // 22 hours in seconds
    "kMDItemContentModificationDate >= $time.now(-3600)",   // 1 hour in seconds
    "kMDItemContentModificationDate >= $time.now(-60)",     // 1 minute
]

var currentTest = 0

func runNextTest() {
    guard currentTest < tests.count else {
        print("=== Done ===")
        CFRunLoopStop(CFRunLoopGetCurrent())
        return
    }
    
    let queryString = tests[currentTest]
    currentTest += 1
    
    print("Test: \(queryString)")
    
    guard let predicate = NSPredicate(fromMetadataQueryString: queryString) else {
        print("  ERROR: Failed to create predicate\n")
        runNextTest()
        return
    }
    
    print("  Predicate: \(predicate.predicateFormat)")
    
    let query = NSMetadataQuery()
    query.searchScopes = [NSMetadataQueryUserHomeScope]
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
        print("  Results: \(query.resultCount) files")
        if query.resultCount > 0 {
            for i in 0..<min(3, query.resultCount) {
                if let item = query.result(at: i) as? NSMetadataItem,
                   let url = item.value(forAttribute: NSMetadataItemPathKey) as? URL {
                    print("    - \(url.lastPathComponent)")
                }
            }
        }
        print("")
        query.stop()
        if let obs = observer { NotificationCenter.default.removeObserver(obs) }
        runNextTest()
    }
    
    query.start()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        if !finished {
            finished = true
            print("  TIMEOUT\n")
            query.stop()
            if let obs = observer { NotificationCenter.default.removeObserver(obs) }
            runNextTest()
        }
    }
}

runNextTest()
CFRunLoopRun()
